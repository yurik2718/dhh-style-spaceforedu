require "test_helper"

class TwoFactorTest < ActionDispatch::IntegrationTest
  setup do
    @admin  = users(:admin)
    @secret = ROTP::Base32.random
  end

  def enable_2fa!(user, secret: @secret)
    user.update!(otp_secret: secret, otp_enabled_at: Time.current)
  end

  def current_code(secret: @secret, at: Time.current)
    ROTP::TOTP.new(secret).at(at)
  end

  # ── Login challenge ────────────────────────────────────────────

  test "admin with 2FA gets a code challenge instead of a session after the password" do
    enable_2fa!(@admin)

    post session_path, params: { email_address: @admin.email_address, password: "password" }

    assert_redirected_to new_two_factor_challenge_path
    assert_equal 0, @admin.sessions.count, "no session before the code is verified"
  end

  test "correct code completes the sign-in" do
    enable_2fa!(@admin)
    post session_path, params: { email_address: @admin.email_address, password: "password" }

    post two_factor_challenge_path, params: { code: current_code }

    assert_redirected_to root_path
    assert_equal 1, @admin.sessions.count
  end

  test "wrong code is rejected and no session appears" do
    enable_2fa!(@admin)
    post session_path, params: { email_address: @admin.email_address, password: "password" }

    post two_factor_challenge_path, params: { code: "000000" }

    assert_response :unprocessable_entity
    assert_equal 0, @admin.sessions.count
  end

  test "a code cannot be replayed" do
    enable_2fa!(@admin)
    code = current_code

    post session_path, params: { email_address: @admin.email_address, password: "password" }
    post two_factor_challenge_path, params: { code: code }
    assert_equal 1, @admin.sessions.count

    delete session_path
    post session_path, params: { email_address: @admin.email_address, password: "password" }
    post two_factor_challenge_path, params: { code: code }

    assert_response :unprocessable_entity
    assert_equal 0, @admin.sessions.reload.count
  end

  test "challenge page without a pending login goes back to sign-in" do
    get new_two_factor_challenge_path
    assert_redirected_to new_session_path

    post two_factor_challenge_path, params: { code: "123456" }
    assert_redirected_to new_session_path
  end

  test "students sign in without any challenge" do
    student = users(:student_es)

    post session_path, params: { email_address: student.email_address, password: "password" }

    assert_redirected_to root_path
    assert_equal 1, student.sessions.count
  end

  # ── Setup from the profile ─────────────────────────────────────

  test "admin enables 2FA by confirming a code from the authenticator" do
    sign_in_as @admin

    get new_two_factor_path
    assert_response :ok
    pending_secret = session_pending_secret

    post two_factor_path, params: { code: current_code(secret: pending_secret) }

    assert_redirected_to profile_path
    @admin.reload
    assert_equal pending_secret, @admin.otp_secret
    assert_not_nil @admin.otp_enabled_at
  end

  test "enabling fails with a wrong confirmation code" do
    sign_in_as @admin

    get new_two_factor_path
    post two_factor_path, params: { code: "000000" }

    assert_response :unprocessable_entity
    assert_nil @admin.reload.otp_enabled_at
  end

  test "admin disables 2FA with a valid code" do
    enable_2fa!(@admin)
    sign_in_as @admin

    delete two_factor_path, params: { code: current_code }

    assert_redirected_to profile_path
    @admin.reload
    assert_nil @admin.otp_secret
    assert_nil @admin.otp_enabled_at
  end

  test "students cannot open 2FA setup" do
    sign_in_as users(:student_es)

    get new_two_factor_path

    assert_redirected_to root_path
  end

  private
    # The pending secret lives in the (signed) session between new and create.
    def session_pending_secret
      request.session[:pending_otp_secret]
    end
end
