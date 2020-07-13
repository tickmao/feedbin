class SearchIndexStore
  include Sidekiq::Worker, ScrolledSearch
  sidekiq_options queue: :critical

  def perform(id, update = false)
    entry = Entry.find(id)
    document = entry.search_data
    index(entry, document)
    percolate(entry, document) unless update
  rescue ActiveRecord::RecordNotFound
  end

  def index(entry, document)
    data = {
      index: Entry.index_name,
      id: entry.id,
      body: document
    }
    $search.each do |_, pool|
      pool.with do |client|
        client.index(data)
      end
    end
  end

  def percolate(entry, document, update = false)
    request = {
      index: Action.index_name,
      scroll: "1m",
      ignore: 404,
      body: {
        size: 1000,
        _source: {
          excludes: ["query"]
        },
        query: {
          constant_score: {
            filter: {
              percolate: {
                field: "query",
                document: document
              }
            }
          }
        }
      }
    }

    response = $search[:main].with do |client|
      client.search(request)
    end

    scrolled_search(response) do |hits|
      ids = hits.map { |hit| hit["_id"].to_i }
      ActionsPerform.perform_async(entry.id, ids, update)
    end
  end
end
