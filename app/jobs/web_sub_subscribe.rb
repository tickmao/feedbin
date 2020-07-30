class WebSubSubscribe
  include Sidekiq::Worker

  def perform(feed_id)
    feed = Feed.find(feed_id)
    WebSub.subscribe(feed)
  end
end
