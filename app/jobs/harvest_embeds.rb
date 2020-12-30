class HarvestEmbeds
  include Sidekiq::Worker
  
  def perform(entry_id)
    entry = Entry.find(entry_id)
    
    want_video_ids = Nokogiri::HTML5(entry.content).css("iframe").each_with_object([]) do |iframe, array|
      if match = IframeEmbed::Youtube.recognize_url?(iframe["src"])
        array.push(match[1])
      end
    end
    
    video_id = entry.data&.dig("youtube_video_id")
    want_video_ids.push(video_id) if video_id
    
    have_video_ids = Embed.youtube_video.where(provider_id: want_video_ids).pluck(:provider_id)
    want_video_ids = want_video_ids - have_video_ids
    videos = youtube_api("videos", want_video_ids)
    
    want_channel_ids = videos.dig("items")&.each_with_object([]) do |video, array| 
      channel_id = video.dig("snippet", "channelId")
      array.push(channel_id) if channel_id
    end

    have_channel_ids = Embed.youtube_channel.where(provider_id: want_channel_ids).pluck(:provider_id)
    want_channel_ids = want_channel_ids - have_channel_ids
    channels = youtube_api("channels", want_channel_ids)
    
    items = channels.dig("items")&.each_with_object([]) do |item, array| 
      item = Embed.new(data: item, provider_id: item.dig("id"), source: :youtube_channel)
      array.push(item)
    end

    items = videos.dig("items")&.each_with_object(items) do |item, array| 
      item = Embed.new(data: item, provider_id: item.dig("id"), parent_id: item.dig("snippet", "channelId"), source: :youtube_video)
      array.push(item)
    end
    
    Embed.import(items, on_duplicate_key_update: {conflict_target: [:source, :provider_id], columns: [:data]}) if items.present?
  end
  
  def youtube_api(type, ids)
    options = {
      params: {
        key: ENV["YOUTUBE_KEY"],
        part: "snippet",
        id: ids.join(",")
      }
    }
    response = UrlCache.new("https://www.googleapis.com/youtube/v3/#{type}", options).body
    JSON.parse(response)
  end
end