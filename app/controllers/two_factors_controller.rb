# Setup/teardown of TOTP for a case-handling account (super_admin or staff).
# Students don't get 2FA — they hold no one's data but their own; case
# handlers hold everyone's.
class TwoFactorsController < ApplicationController
  skip_after_action :verify_authorized
  before_action :require_case_staff

  def new
    prepare_setup
  end

  def create
    secret   = session[:pending_otp_secret]
    timestep = secret.present? &&
               ROTP::TOTP.new(secret).verify(params[:code].to_s.gsub(/\D/, ""), drift_behind: 15)

    if timestep
      Current.user.update!(otp_secret: secret, otp_enabled_at: Time.current,
                           otp_last_verified_timestep: timestep)
      session.delete(:pending_otp_secret)
      redirect_to profile_path, notice: t("two_factor.enabled_notice")
    else
      prepare_setup
      flash.now[:alert] = t("two_factor.invalid_code")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if Current.user.verify_otp!(params[:code])
      Current.user.update!(otp_secret: nil, otp_enabled_at: nil, otp_last_verified_timestep: nil)
      redirect_to profile_path, notice: t("two_factor.disabled_notice")
    else
      redirect_to profile_path, alert: t("two_factor.invalid_code")
    end
  end

  private
    def require_case_staff
      redirect_to root_path, alert: t("errors.not_authorized") unless Current.user.case_staff?
    end

    def prepare_setup
      session[:pending_otp_secret] ||= ROTP::Base32.random
      @secret           = session[:pending_otp_secret]
      @provisioning_uri = ROTP::TOTP.new(@secret, issuer: "SpaceForEdu")
                            .provisioning_uri(Current.user.email_address)
      @qr_svg           = RQRCode::QRCode.new(@provisioning_uri)
                            .as_svg(module_size: 3, viewbox: true, use_path: true)
    end
end
