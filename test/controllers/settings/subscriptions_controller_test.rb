require "test_helper"

class Settings::SubscriptionsControllerTest < ActionController::TestCase
  setup do
    @user = users(:ben)
  end

  test "should get index" do
    user = users(:new)
    feeds = create_feeds(user)
    entries = user.entries
    login_as user

    get :index
    assert_response :success
    assert assigns(:subscriptions).present?
  end

  test "should show_updates multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: "show_updates", subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(show_updates: true).pluck(:id).sort
    assert_redirected_to settings_subscriptions_url
  end

  test "should hide_updates multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: "hide_updates", subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(show_updates: false).pluck(:id).sort
    assert_redirected_to settings_subscriptions_url
  end

  test "should mute multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: "mute", subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(muted: true).pluck(:id).sort
    assert_redirected_to settings_subscriptions_url
  end

  test "should unmute multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: "unmute", subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(muted: false).pluck(:id).sort
    assert_redirected_to settings_subscriptions_url
  end

  test "should destroy multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    assert_difference "Subscription.count", -ids.length do
      post :update_multiple, params: {operation: "unsubscribe", subscription_ids: ids}
      assert_redirected_to settings_subscriptions_url
    end
  end

  test "should destroy subscription settings" do
    login_as @user
    subscription = @user.subscriptions.first
    assert_difference "Subscription.count", -1 do
      delete :destroy, params: {id: subscription}, xhr: true
      assert_redirected_to settings_subscriptions_url
    end
  end

  test "should get edit" do
    login_as @user
    get :edit, params: {id: @user.subscriptions.first}
    assert_response :success
  end

  test "should refresh favicon" do
    login_as @user
    subscription = @user.subscriptions.first

    assert_difference "FaviconFetcher.jobs.size", +1 do
      post :refresh_favicon, params: {id: subscription}, xhr: true
      assert_response :success
    end
  end

  test "should unsubscribe from newsletter" do
    user = users(:new)
    login_as user

    3.times { create_newsletter(user) }

    feed_ids = user.newsletter_senders.pluck(:feed_id)

    assert_equal(feed_ids.count, user.subscriptions.count)

    unsubscribe = feed_ids.shift

    post :newsletter_senders, params: {feeds: feed_ids}, xhr: true

    assert_equal(feed_ids, user.subscriptions.pluck(:feed_id))

    post :newsletter_senders, params: {feeds: [unsubscribe]}, xhr: true

    assert user.subscriptions.where(feed_id: unsubscribe).exists?
  end

  def create_newsletter(user)
    signature = Newsletter.new(newsletter_params("asdf", "asdf")).send(:signature)
    token = user.newsletter_authentication_token.token

    newsletter = Newsletter.new(newsletter_params(token, signature, SecureRandom.hex, SecureRandom.hex))
    NewsletterEntry.create(newsletter, user)
  end
end
