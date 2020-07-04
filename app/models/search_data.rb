class SearchData
  def initialize(entry)
    @entry = entry
  end

  def to_h
    base = {
      id: @entry.id,
      title: ContentFormatter.summary(@entry.title),
      content: text,
      author: @entry.author,
      url: @entry.fully_qualified_url,
      feed_id: @entry.feed_id,
      published: @entry.published,
      updated: @entry.updated_at,
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
      base[:twitter_image] = !!(tweets.find { |tweet| tweet.media? })
      base[:twitter_link] = !!(tweets.find { |tweet| tweet.urls? })
    end

    base
  end

  def document
    @document ||= begin
      html = @entry.content.to_s.dup
      unless html.encoding.name == Encoding::UTF_8.to_s
        html.encode!(Encoding::UTF_8, invalid: :replace, undef: :replace)
      end
      html.gsub!(Sanitize::REGEX_UNSUITABLE_CHARS, "")
      html = Nokogiri::HTML5.fragment(html, max_tree_depth: 5000)
      Sanitize.node!(html, ContentFormatter::SANITIZE_BASIC)
    rescue ArgumentError
      # Can be raise by Nokogiri::HTML5 Document tree depth limit exceeded
      OpenStruct.new(text: html)
    end
  end

  def text
    document.text&.squish
  end

  def links
    links = [@entry.fully_qualified_url]
    document.css("a").each do |link|
      links.push(link["href"])
    end
    links.map do |link|
      Addressable::URI.parse(link)&.host rescue nil
    end.flatten.uniq
  end
end
