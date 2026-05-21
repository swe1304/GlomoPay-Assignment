module Api
  module V1
    class BalancesController < ApplicationController
      before_action :authenticate_user!

      def show
        render json: {
          user: {
            id: current_user.id,
            name: current_user.name,
            email: current_user.email
          },
          balance: current_user.rounded_balance.to_f
        }
      end
    end
  end
end
