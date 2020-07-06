class SearchIndexStoreAlt
  include Sidekiq::Worker
  sidekiq_options queue: :worker_slow_search

  def perform(id, update = false)
    entry = Entry.find(id)
    document = entry.search_data
    index(entry, document)
  rescue ActiveRecord::RecordNotFound
  end

  def index(entry, document)
    data = {
      index: Entry.index_name,
      id: entry.id,
      body: document
    }
    $search.each do |_, client|
      client.index(data)
    end
  end
end
