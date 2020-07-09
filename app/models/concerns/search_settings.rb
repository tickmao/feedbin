module SearchSettings

  extend ActiveSupport::Concern

  included do

    include Elasticsearch::Model

    search_settings = {
      index: {
        number_of_shards: "16",
      },
      analysis: {
        analyzer: {
          lower_exact: {
            type: "custom",
            tokenizer: "whitespace",
            filter: ["lowercase"]
          },
          stemmed: {
            type: "custom",
            tokenizer: "standard",
            filter: ["lowercase", "asciifolding", "english_stemmer"]
          }
        },
        filter: {
          english_stemmer: {
            type: "stemmer",
            name: "english"
          }
        }
      }
    }

    exact_field = {
      exact: {
        type: "text",
        analyzer: "lower_exact"
      }
    }

    settings search_settings do
      mappings do
        indexes :query, type: "percolator"

        indexes :id, type: "long"
        indexes :title, analyzer: "stemmed", fields: exact_field
        indexes :content, analyzer: "stemmed", fields: exact_field
        indexes :author, analyzer: "lower_exact", fields: exact_field
        indexes :url, analyzer: "keyword", fields: exact_field
        indexes :feed_id, type: "long"
        indexes :published, type: "date"
        indexes :updated, type: "date"
        indexes :link, analyzer: "lower_exact"

        indexes :twitter_screen_name, analyzer: "standard", fields: exact_field
        indexes :twitter_name, analyzer: "standard"
        indexes :twitter_retweet, type: "boolean"
        indexes :twitter_media, type: "boolean"
        indexes :twitter_image, type: "boolean"
        indexes :twitter_link, type: "boolean"
      end
    end
  end
end
