class Action < ApplicationRecord

  include SearchSettings

  attr_accessor :automatic_modification, :apply_action

  belongs_to :user
  enum action_type: {standard: 0, notifier: 1}
  enum status: {active: 0, suspended: 1, broken: 2}

  validate do |action|
    if computed_feed_ids.empty? && automatic_modification.blank?
      errors[:base] << "Please select at least one feed or tag"
    end
  end

  before_validation :compute_tag_ids
  before_validation :compute_feed_ids

  validate :query_valid, unless: :automatic_modification

  after_destroy :percolate_destroy
  after_commit :percolate_create, on: [:create, :update]
  after_commit :bulk_actions, on: [:create, :update]

  before_save :record_status

  def record_status
    if automatic_modification.blank?
      self.status = Action.statuses[:active]
    end
  end

  def percolate_create
    PercolateCreate.perform_async(id)
  end

  def percolate_destroy
    PercolateDestroy.perform_async(id)
  end

  def bulk_actions
    ActionsBulk.perform_async(id, user.id) if apply_action == "1"
  end

  def search_body
    {
      query: {
        bool: {
          filter: filters
        }
      }
    }
  end

  def filters
    array = []

    array.push({
      terms: {
        feed_id: computed_feed_ids
      }
    })

    array.push({
      query_string: {
        fields: ["title", "content", "author", "url", "twitter_screen_name", "twitter_name"],
        default_operator: "AND",
        query: FeedbinUtils.escape_search(query)
      }
    }) if query.present?

    array
  end

  def compute_feed_ids
    final_feed_ids = []
    new_feed_ids = feed_ids || []
    subscriptions = Subscription.uncached {
      user.subscriptions.pluck(:feed_id)
    }
    if all_feeds
      final_feed_ids.concat(subscriptions)
    end
    final_feed_ids.concat(user.taggings.where(tag: tag_ids).pluck(:feed_id))
    final_feed_ids.concat(new_feed_ids.reject(&:blank?).map(&:to_i))
    final_feed_ids = final_feed_ids.uniq
    final_feed_ids &= subscriptions
    self.computed_feed_ids = final_feed_ids
  end

  def compute_tag_ids
    new_tag_ids = tag_ids || []
    new_tag_ids.each do |tag_id|
      unless user.tags.where(id: tag_id).present?
        new_tag_ids -= [tag_id]
      end
    end
    self.tag_ids = new_tag_ids
  end

  def _percolator
    $search[:main].with do |client|
      client.get(
        index: Action.index_name,
        id: id,
        ignore: 404
      )
    end
  end

  def query_valid
    options = {
      index: Entry.index_name,
      body: {query: search_body[:query]}
    }
    result = $search[:main].with {|client| client.indices.validate_query(options) }
    if result["valid"] == false
      errors[:base] << "Search syntax invalid"
    end
  end

  def results
    Entry.search(search_options).page(1).records(includes: :feed)
  end

  def error_hint
    @error_hint ||= begin
      if valid?
        ""
      else
        "Invalid Action: #{errors.full_messages.to_sentence(words_connector: ".")}"
      end
    end
  end

  private

  def search_options
    {}.tap do |hash|
      hash[:query] = search_body[:query]
      hash[:sort] = [{published: "desc"}]
    end
  end
end
