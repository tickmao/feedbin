class WebSub
  def initialize(feed)
    @feed = feed
  end

  def self.subscribe(feed)
    new(feed).subscribe
  end

  def self.unsubscribe(feed)
    new(feed).unsubscribe
  end

  def subscribe
    if @feed.hubs && @feed.self_url
      perform("subscribe")
    end
  end

  def unsubscribe
    if @feed.hubs && @feed.self_url
      perform("unsubscribe")
    end
  end

  private

  def perform(mode)
    @hubs.each do |hub|
      request(hub, mode)
    end
  end

  def request(url, mode)
    HTTP.post(url, form: {
      "hub.mode"     => mode,
      "hub.verify"   => "async",
      "hub.topic"    => @feed.self_url,
      "hub.secret"   => @feed.web_sub_secret,
      "hub.callback" => @feed.web_sub_callback
    })
  end

end