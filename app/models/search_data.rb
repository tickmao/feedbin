class SearchData
  def initialize(entry)
    @entry = entry
  end

  def to_h
    base = {
      id: @entry.id,
      feed_id: @entry.feed_id,
      title: ContentFormatter.summary(@entry.title),
      url: @entry.fully_qualified_url,
      author: @entry.author,
      content: text,
      published: @entry.published.iso8601,
      updated: @entry.updated_at.iso8601,
      link: links
    }

    if @entry.tweet?
      tweets = [@entry.main_tweet]
      tweets.push(@entry.main_tweet.quoted_status) if @entry.main_tweet.quoted_status?
      base[:twitter_screen_name] = "#{@entry.main_tweet.user.screen_name} @#{@entry.main_tweet.user.screen_name}"
      base[:twitter_name] = @entry.main_tweet.user.name
      base[:twitter_retweet] = @entry.tweet.retweeted_status?
      base[:twitter_quoted] = @entry.tweet.quoted_status?
      base[:twitter_media] = @entry.twitter_media?
      base[:twitter_image] = !!(tweets.find { |tweet| tweet.media? rescue nil })
      base[:twitter_link] = !!(tweets.find { |tweet| tweet.urls? })
    end

    base
  end

  def document
    @document ||= Loofah.fragment(@entry.content).scrub!(:prune)
  end

  def text
    document
      .to_text(encode_special_chars: false)
      .gsub!(/\s+/, " ")
      .squish
  end

  def links
    links = [@entry.fully_qualified_url]
    document.css("a").each do |link|
      links.push(link["href"])
    end
    links.map do |link|
      Addressable::URI.parse(link)&.host rescue nil
    end.compact.uniq
  end
end
