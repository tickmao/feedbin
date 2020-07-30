class WebSubUnsubscribe
  include Sidekiq::Worker

  def perform(feed_id)
    feed = Feed.find(feed_id)
    WebSub.unsubscribe(feed)
  end
end
