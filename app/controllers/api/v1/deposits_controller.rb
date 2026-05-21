module Api
  module V1
    class DepositsController < ApplicationController
      before_action :authenticate_user!

      POSITIVE_AMOUNT_PATTERN = /\A\d+(\.\d{1,2})?\z/
      TOO_MANY_DECIMALS_PATTERN = /\A\d+\.\d{3,}\z/

      def create
        error, amount_decimal = parse_amount(params[:amount])
        return render json: { error: error }, status: :bad_request if error

        new_balance = current_user.deposit!(amount_decimal)

        render json: {
          message: "Deposit successful",
          deposited: amount_decimal.round(2).to_f,
          new_balance: new_balance.to_f
        }, status: :ok
      end

      private

      def parse_amount(amount)
        return [ "Amount is required", nil ] if amount.nil?

        unless amount.is_a?(Numeric) || amount.is_a?(String)
          return [ "Amount must be a positive number", nil ]
        end

        amount_str = amount.to_s.strip
        return [ "Amount is required", nil ] if amount_str.empty?

        if amount_str.match?(TOO_MANY_DECIMALS_PATTERN)
          return [ "Amount can have at most 2 decimal places", nil ]
        end

        unless amount_str.match?(POSITIVE_AMOUNT_PATTERN)
          return [ "Amount must be a positive number", nil ]
        end

        amount_decimal = BigDecimal(amount_str)
        return [ "Amount must be a positive number", nil ] if amount_decimal <= 0
        return [ "Amount can have at most 2 decimal places", nil ] unless (amount_decimal * 100).frac.zero?

        [ nil, amount_decimal ]
      end
    end
  end
end
