class EntryPresenter < BasePresenter

  YOUTUBE_URLS = [
    %r(https?://youtu\.be/(.+)),
    %r(https?://www\.youtube\.com/watch\?v=(.*?)(&|#|$)),
    %r(https?://m\.youtube\.com/watch\?v=(.*?)(&|#|$)),
    %r(https?://www\.youtube\.com/embed/(.*?)(\?|$)),
    %r(https?://www\.youtube\.com/v/(.*?)(#|\?|$)),
    %r(https?://www\.youtube\.com/user/.*?#\w/\w/\w/\w/(.+)\b)
  ]

  presents :entry

  def entry_link(&block)
    options = {
      remote: true, class: 'wrap', data: {
        behavior: 'selectable open_item show_entry_content entry_info',
        mark_as_read_path: @template.mark_as_read_entry_path(entry),
        recently_read_path: @template.recently_read_entry_path(entry),
        entry_id: entry.id,
        entry_info: {id: entry.id, feed_id: entry.feed_id, published: entry.published.to_i}
      }
    }
    @template.link_to @template.entry_path(entry), options do
      yield
    end
  end

  def published_date
    if entry.published
      entry.published.to_s(:full_human)
    else
      ''
    end
  end

  def datetime
    if entry.published
      entry.published.to_s(:datetime)
    else
      ''
    end
  end

  def parsed_date(date, format)
    begin
      date = Time.parse(date)
      date.to_s(format)
    rescue Exception
      nil
    end
  end

  def content(image_proxy_enabled)
    ContentFormatter.format!(formatted_content, entry, image_proxy_enabled)
  rescue => e
    Rails.logger.info { e.inspect }
    @template.content_tag(:p, '&ndash;&ndash;'.html_safe)
  end

  def api_content
    ContentFormatter.api_format(formatted_content, entry)
  rescue => e
    Rails.logger.info { e.inspect }
    @template.content_tag(:p, '&ndash;&ndash;'.html_safe)
  end

  def app_content
    ContentFormatter.app_format(formatted_content, entry)
  rescue => e
    Rails.logger.info { e.inspect }
    @template.content_tag(:p, '&ndash;&ndash;'.html_safe)
  end

  def formatted_content
    @formatted_content ||= begin
      formatted_content = entry.content
      if text?
        formatted_content = ContentFormatter.text_email(formatted_content)
      elsif youtube?
        formatted_content = ContentFormatter.text_email(formatted_content)
        formatted_content = @template.content_tag(:iframe, '', width: entry.data["media_width"], height: entry.data["media_height"], src: "https://www.youtube-nocookie.com/embed/#{entry.data["youtube_video_id"]}?rel=0&amp;showinfo=0", frameborder: 0, allowfullscreen: true) + formatted_content
      end
      formatted_content
    end
  end

  def text?
    entry.content_format == "text"
  end

  def has_content?
    entry.summary.respond_to?(:length) && entry.summary.length > 0
  end

  def show_body?
    if entry.tweet?
      true
    else
      has_content? && sanitized_title.present?
    end
  end

  def title
    text = sanitized_title
    if text.blank?
      text = entry.summary.html_safe
    end
    if text.blank?
      text = '&ndash;&ndash;'.html_safe
    end
    @template.truncate(text, length: 98, omission: '…', escape: false)
  end

  def entry_view_title
    @entry_view_title ||= begin
      text = sanitized_title
      if text.blank?
        text = @template.content_tag(:span, entry.feed.title, title: "No title").html_safe
      end
      text
    end
  end

  def sanitized_title
    @sanitized_title ||= @template.raw(@template.strip_tags(entry.title))
  end

  def author
    if entry.author
      clean_author = @template.strip_tags(entry.author)
      clean_author = "by " + @template.content_tag(:span, clean_author, class: "author")
    else
      clean_author = ''
    end
    clean_author.html_safe
  end

  def media_size
    begin
      size = Integer(entry.data['enclosure_length'])
      size = @template.number_to_human_size(size)
      size = "(#{size})"
    rescue Exception
      size = ''
    end
  end

  def download_title
    "Download #{media_size}"
  end

  def media
    output = ''
    if entry.data && entry.data['enclosure_url'].present? && media_type.present?
      if media_type == :video
        output += @template.video_tag entry.data['enclosure_url'], preload: 'none'
      elsif media_type == :audio
        output += @template.audio_tag entry.data['enclosure_url'], preload: 'none'
      end
      output += @template.link_to "Download #{media_size}", entry.data['enclosure_url'], class: 'download-link'
    end
    output
  end

  def saved_page(url)
    if entry.data && entry.data['saved_pages'] && page = entry.data['saved_pages'][url]
      MercuryParser.new(nil, page)
    end
  end

  def media_class
    classes = []
    if media_type == :audio
      classes.push("media")
    end

    if entry.tweet?
      classes.push("tweet")
    end

    classes.join(" ")
  end

  def media_type
    if entry.data && entry.data['enclosure_type'] == 'video/mp4'
      :video
    elsif entry.data && ['audio/mp3', 'audio/mpeg'].include?(entry.data['enclosure_type'])
      :audio
    else
      nil
    end
  end

  def media_duration
    if entry.data['itunes_duration']
      entry.data['itunes_duration']
    else
      ''
    end
  end

  def media_image
    if entry.data && entry.data['itunes_image_processed']
      url = URI(entry.data['itunes_image_processed'])
      url.host = ENV['ENTRY_IMAGE_HOST'] if ENV['ENTRY_IMAGE_HOST']
      url.scheme = 'https'
      url.to_s
    end
  end

  def media_subtitle
    if entry.data && entry.data['itunes_subtitle']
      subtitle = @template.strip_tags(entry.data['itunes_subtitle'])
      body = @template.strip_tags(entry.content)
      decoder = HTMLEntities.new
      body = decoder.decode(body)
      if !body.include?(subtitle)
        @template.content_tag :figcaption do
          @template.raw(subtitle)
        end
      end
    end
  end

  def feed_domain_matches?(comparison)
    begin
      uri = URI.parse(entry.feed.site_url)
      uri.host == comparison || uri.host == comparison.sub('www.', '')
    rescue Exception
      false
    end
  end

  def has_enclosure?
    entry.data.respond_to?(:[]) && entry.data["enclosure_url"].present?
  end

  def has_media?
    !media_type.nil? || content.include?('<iframe')
  end

  def youtube?
    entry.data && entry.data["youtube_video_id"].present?
  end

  def image
    if image?
      url = URI(entry.image["processed_url"])
      url.host = ENV['ENTRY_IMAGE_HOST'] if ENV['ENTRY_IMAGE_HOST']
      url.scheme = 'https'
      padding = (entry.image["height"].to_f / entry.image["width"].to_f).round(4) * 100
      @template.content_tag :span, class: "entry-image" do
        @template.content_tag :span, "", data: {src: url.to_s }, style: "padding-top: #{padding}%;"
      end
    end
  end

  def image?
    entry.image.present? && entry.image["original_url"] && entry.image["processed_url"] && entry.image["width"] && entry.image["height"]
  end

  def entry_type
    if entry.data && entry.data["type"].present?
      entry.data["type"]
    else
      "default"
    end
  end

  def entry_type_class
    "entry-type-#{entry_type} entry-format-#{entry_type}-#{entry.content_format}"
  end

  def content_diff
    before = ContentFormatter.api_format(entry.original['content'], entry)
    HTMLDiff::Diff.new(before, entry.content).inline_html
  rescue
    nil
  end

  def decoder
    @decoder ||= HTMLEntities.new
  end

  def content_text
    @content_text ||= begin
      text = Sanitize.fragment(entry.content,
        remove_contents: true,
        elements: %w{html body div span
                     h1 h2 h3 h4 h5 h6 p blockquote pre
                     a abbr acronym address big cite code
                     del dfn em ins kbd q s samp
                     small strike strong sub sup tt var
                     b u i center
                     dl dt dd ol ul li
                     fieldset form label legend
                     table caption tbody tfoot thead tr th td
                     article aside canvas details embed
                     figure figcaption footer header hgroup
                     menu nav output ruby section summary}
      )
      text = ReverseMarkdown.convert(text)
      text = ActionController::Base.helpers.strip_tags(text)
      decoder.decode(text)
    end
  end

  def app_summary
    decoder.decode(@template.strip_tags(entry.summary))
  end

  def summary
    if entry.tweet
      tweet_hash[:full_text]
    else
      entry.summary.html_safe
    end
  end

  def trimmed_summary(text)
    output = ""
    parts = text.split('. ')
    a = parts.each_with_index do |part, index|
      new_part = part + ". "
      output << new_part
      if index == 0
        if output.length > 216
          output = output[0..216]
          output = output[0..-2]
          return output << "…"
        end
      else
        if output.length > 216
          return output.sub(new_part, "")
        end
      end
    end
    output
  end

  def app_title
    (entry.title.present?) ? decoder.decode(@template.strip_tags(entry.title.strip)) : nil
  end

  def app_author
    (entry.author.present?) ? decoder.decode(@template.strip_tags(entry.author.strip)) : nil
  end

  def has_diff?
    entry.content.present? && entry.original.present? && entry.original['content'].present? && entry.original['content'].length != entry.content.length
  end

  def audio_duration
    if media_duration && parts = media_duration.split(":").map(&:to_i)
      if parts.length == 3
        hours, minutes, seconds = parts
        result = hours * 60 + minutes
        "#{result} minutes"
      end
    end
  rescue
    nil
  end

  def profile_image(feed)
    if entry.tweet?
      @template.content_tag :span, '', class: "favicon-wrap twitter-profile-image" do
        @template.image_tag(tweet_profile_image_uri)
      end
    else
      favicon(feed)
    end
  end

  def feed_title
    if entry.tweet?
      @template.content_tag(:span, '', class: "title-inner twitter-feed-title") do
        @template.content_tag(:strong, tweet_name) + " #{tweet_screen_name}"
      end
    else
      @template.content_tag(:span, '', class: "title-inner", data: {behavior: "user_title", feed_id: entry.feed.id}) do
        entry.feed.title
      end
    end
  end

  def tweet_text
    if tweet_hash[:entities]
      Twitter::Autolink.auto_link_with_json(tweet_hash[:full_text], tweet_hash[:entities]).html_safe
    else
      tweet_hash[:full_text]
    end
  end

  def tweet_name
    main_tweet.user.name
  end

  def tweet_screen_name
    "@" + main_tweet.user.screen_name
  end

  def tweet_user_url
    "https://twitter.com/#{main_tweet.user.screen_name}"
  end

  def tweet_media
    main_tweet.media
  end

  def tweet_urls
    main_tweet.urls
  end

  def tweet_retweeted_message
    "Retweeted by " + (entry.tweet.user.name || "@" + entry.tweet.user.screen_name)
  end

  def tweet_retweeted_image
    if entry.tweet.user.profile_image_uri?
      entry.tweet.user.profile_image_uri("normal")
    else
      # default twitter avatar
    end
  end

  # Sizes: normal, bigger
  def tweet_profile_image_uri(size = "bigger")
    if main_tweet.user.profile_image_uri?
      main_tweet.user.profile_image_uri("bigger")
    else
      # default twitter avatar
    end
  end

  def tweet_find_video_url(variants)
    video = variants.max_by do |element|
      if element.content_type == "video/mp4" && element.bitrate
        element.bitrate
      else
        0
      end
    end

    video.url.to_s
  end

  def tweet_youtube_embed(url)
    url = url.expanded_url.to_s
    if YOUTUBE_URLS.find { |format| url =~ format } && $1
      youtube_id = $1
      @template.content_tag(:iframe, "", src: "https://www.youtube.com/embed/#{youtube_id}", height: 9, width: 16, frameborder: 0, allowfullscreen: true).html_safe
    else
      false
    end
  end

  def tweet_created_at
    main_tweet.created_at.strftime("%l:%M %p - %e %b %Y")
  end

  def tweet_created_at_display
    main_tweet.created_at.to_s(:full_human)
  end

  def tweet_location
    (main_tweet.place?) ? main_tweet.place.full_name : nil
  end

  private

  def main_tweet
    (entry.tweet.retweeted_status?) ? entry.tweet.retweeted_status : entry.tweet
  end

  def tweet_hash
    @tweet_hash ||= main_tweet.to_h
  end

end