require "test_helper"

class WebSubMaintenanceTest < ActiveSupport::TestCase
  test "should schedule subscribe job" do
    Sidekiq::Worker.clear_all

    feeds = Feed.all
    feeds.update_all(push_expiration: Time.now - 1.second, subscriptions_count: 1)

    assert_difference "WebSubSubscribe.jobs.size", +feeds.count do
      WebSubMaintenance.new.perform
    end
  end

  test "should schedule unsubscribe job" do
    Sidekiq::Worker.clear_all

    feeds = Feed.all
    feeds.update_all(push_expiration: Time.now - 1.second, subscriptions_count: 0)

    assert_difference "WebSubUnsubscribe.jobs.size", +feeds.count do
      WebSubMaintenance.new.perform
    end
  end

end
