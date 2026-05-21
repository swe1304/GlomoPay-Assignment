module Api
  module V1
    class SessionsController < ApplicationController
      def create
        user = User.find_by(email: params[:email]&.downcase&.strip)

        if user&.authenticate_pin(params[:pin].to_s)
          token = user.generate_auth_token!
          render json: {
            message: "Login successful",
            user: {
              id: user.id,
              name: user.name,
              email: user.email
            },
            token: token
          }, status: :ok
        else
          render json: { error: "Invalid email or PIN" }, status: :unauthorized
        end
      end
    end
  end
end
