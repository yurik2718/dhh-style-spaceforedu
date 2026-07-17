class TwoFactorChallengesController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized
  layout "auth"
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("errors.rate_limited") }
  before_action :require_pending_user

  def new
  end

  def create
    if @pending_user.verify_otp!(params[:code])
      session.delete(:pending_otp_user_id)
      session.delete(:pending_otp_deadline)
      start_new_session_for @pending_user
      redirect_to after_authentication_url
    else
      flash.now[:alert] = t("two_factor.invalid_code")
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_pending_user
      deadline = Time.iso8601(session[:pending_otp_deadline].to_s) rescue nil
      @pending_user = User.kept.find_by(id: session[:pending_otp_user_id]) if deadline&.future?

      redirect_to new_session_path if @pending_user.nil?
    end
end
