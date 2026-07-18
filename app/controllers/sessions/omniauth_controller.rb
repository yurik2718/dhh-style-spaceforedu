class Sessions::OmniauthController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized

  def create
    auth  = request.env["omniauth.auth"]
    email = auth.info.email.to_s.strip.downcase

    if (user = User.kept.find_by(google_uid: auth.uid))
      sign_in user
    elsif (user = User.kept.find_by(email_address: email))
      # Google verified this address, so it is safe to link the accounts.
      user.update_column(:google_uid, auth.uid)
      sign_in user
    else
      # New person: GDPR consent must be explicit, so finish signup on a
      # dedicated step instead of silently creating an account.
      session[:pending_google_auth] = { "uid" => auth.uid, "email" => email, "name" => auth.info.name }
      redirect_to new_google_registration_path
    end
  end

  def failure
    redirect_to new_session_path, alert: t("errors.google_auth_failed")
  end

  private
    def sign_in(user)
      complete_authentication_for user
    end
end
