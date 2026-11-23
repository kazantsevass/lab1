class Api::V1::BaseController < ApplicationController
  wrap_parameters false

  class Forbidden < StandardError; end

  rescue_from Forbidden do
    error_response("Insufficient permissions", "forbidden", 403)
  end

  rescue_from ActiveRecord::RecordNotFound do
    error_response("No such record in Database; check params", "not_found", 404)
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    respond({ errors: exception.record.errors.to_hash }, 422)
  end

  rescue_from ActionController::BadRequest do |exception|
    error_response(exception.message, "bad_request", 400)
  end

  def catch_404
    error_response("No route matches; check routes", "no_route", 404)
  end

  private

  def error_response(message, status, code)
    respond({ error: message, status: status }, code)
  end

  def respond(body, code = 200)
    if code != 200 && request.query_parameters["suppress_response_code"] == "true"
      render json: body.merge(code: code), status: 200
    else
      render json: body, status: code
    end
  end

  def require_admin
    raise Forbidden unless admin?
  end

  def bearer_token
    request.authorization.to_s[/\ABearer (.+)\z/i, 1]
  end

  def admin?
    expected = ENV["APP1_ADMIN_TOKEN"]
    expected.present? && bearer_token && ActiveSupport::SecurityUtils.secure_compare(expected, bearer_token)
  end

  def employer
    @employer ||= Company.visible.find_signed(bearer_token, purpose: :api_access) if bearer_token
  end

  def applicant
    @applicant ||= Geek.find_signed(bearer_token, purpose: :api_access) if bearer_token
  end

  def require_owner(owner, id)
    raise Forbidden unless admin? || (owner && owner.id.to_s == id.to_s)
  end
end
