class AuthenticationToken < ApplicationRecord
  belongs_to :user

  enum purpose: {starred_feed: 0, subscription_email: 1, newsletter: 2, page: 2}
end
