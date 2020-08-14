class SearchIndexRemove
  include Sidekiq::Worker

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
    Sidekiq::Client.push(
      "args" => [ids],
      "class" => "SearchIndexRemoveAlt",
      "queue" => "worker_slow_search_alt",
      "retry" => false
    )
  end
end
