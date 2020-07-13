defaults = {
  log: Rails.env.development?
}
$search = {}.tap do |hash|
  hash[:main] = ConnectionPool::Wrapper.new(size: ENV.fetch("SEARCH_POOL", 1).to_i, timeout: 5) {
    Elasticsearch::Client.new(defaults)
  }
  if ENV["ELASTICSEARCH_ALT_URL"]
    hash[:alt] = ConnectionPool::Wrapper.new(size: ENV.fetch("SEARCH_POOL", 1).to_i, timeout: 5) {
      Elasticsearch::Client.new(defaults.merge(url: ENV["ELASTICSEARCH_ALT_URL"]))
    }
  end
end

Elasticsearch::Model.client = $search[:main]

if Rails.env.development? || Rails.env.test?
  $search[:main].transport.tracer = ActiveSupport::Logger.new("log/elasticsearch.log")
  begin
    Entry.__elasticsearch__.create_index!
    Action.__elasticsearch__.create_index!
  rescue
    nil
  end
end
