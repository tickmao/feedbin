class WebSubMaintenance
  include Sidekiq::Worker

  def perform
    Feed.where("push_expiration < ?", Time.now).find_each do |feed|
      if feed.subscriptions_count == 0
        WebSubUnsubscribe.perform_in(sometime_today, feed.id)
      else
        WebSubSubscribe.perform_in(sometime_today, feed.id)
      end
    end
  end

  def sometime_today
    rand(0..1.day.to_i).seconds
  end
end
