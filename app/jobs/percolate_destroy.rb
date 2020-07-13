class PercolateDestroy
  include Sidekiq::Worker
  sidekiq_options queue: :critical

  def perform(action_id)
    options = {
      index: Action.index_name,
      id: action_id,
      ignore: 404
    }
    $search.each do |_, pool|
      pool.with do |client|
        client.delete(options)
      end
    end
  end
end
