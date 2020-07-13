class SearchIndexRemoveAlt
  include Sidekiq::Worker
  sidekiq_options queue: :worker_slow_search

  def perform(ids)
    data = ids.map { |id|
      {delete: {_id: id}}
    }
    $search.each do |_, pool|
      pool.with do |client|
        client.bulk(
          index: Entry.index_name,
          body: data
        )
      end
    end
  end
end
