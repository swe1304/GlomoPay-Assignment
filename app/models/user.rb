class User < ApplicationRecord
  has_secure_password :pin, validations: false

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :pin, presence: true, format: { with: /\A\d{4}\z/, message: "must be exactly 4 digits" }, on: :create
  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  before_save :downcase_email

  def generate_auth_token!
    loop do
      self.auth_token = SecureRandom.hex(32)
      break unless User.exists?(auth_token: auth_token)
    end
    save!
    auth_token
  end

  def deposit!(amount)
    raise ArgumentError, "Amount must be positive" unless amount.to_d > 0

    with_lock do
      self.balance = (balance.to_d + amount.to_d).round(2)
      save!
    end
    rounded_balance
  end

  def rounded_balance
    balance.to_d.round(2)
  end

  private

  def downcase_email
    self.email = email.downcase.strip
  end
end
