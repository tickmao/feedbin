require "net/http/persistent"

defaults = {
  log: Rails.env.development?
}
$search = {}.tap do |hash|
  hash[:main] = Elasticsearch::Client.new(defaults)
  hash[:alt] = Elasticsearch::Client.new(defaults.merge(url: ENV["ELASTICSEARCH_ALT_URL"])) if ENV["ELASTICSEARCH_ALT_URL"]
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
