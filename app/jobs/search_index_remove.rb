class SearchIndexRemove
  include Sidekiq::Worker

  def perform(ids)
    data = ids.map { |id|
      {delete: {_id: id}}
    }
    $search.each do |_, client|
      client.bulk(
        index: Entry.index_name,
        body: data
      )
    end
  end
end
