class GoogleRegistrationsController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized
  layout "auth"
  before_action :require_pending_auth

  def new
    @user = User.new(email_address: pending_auth["email"], name: pending_auth["name"])
  end

  def create
    @user = User.new(
      email_address:    pending_auth["email"],
      name:             pending_auth["name"].presence || pending_auth["email"],
      google_uid:       pending_auth["uid"],
      password:         SecureRandom.base58(24),
      privacy_accepted: params.dig(:user, :privacy_accepted) || "0"
    )

    if @user.save
      session.delete(:pending_google_auth)
      start_new_session_for @user
      redirect_to root_path, notice: t("flash.registered")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def pending_auth
      session[:pending_google_auth]
    end

    def require_pending_auth
      redirect_to new_session_path if pending_auth.blank?
    end
end
