class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_unexpected_error
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ArgumentError, with: :bad_request
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :invalid_json
  rescue_from JSON::ParserError, with: :invalid_json

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    @current_user = User.find_by(auth_token: token) if token

    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  attr_reader :current_user

  def not_found(exception)
    render json: { error: exception.message || "Not found" }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end

  def invalid_json(_exception)
    render json: {
      error: "Invalid JSON in request body",
      hint: "Text values must be in double quotes. Use {\"amount\": 100} or {\"amount\": \"100\"}. For invalid text use {\"amount\": \"abc\"} — not {\"amount\": abc}."
    }, status: :bad_request
  end

  def handle_unexpected_error(exception)
    Rails.logger.error("Unexpected error: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
    render json: { error: "An unexpected error occurred" }, status: :internal_server_error
  end
end
