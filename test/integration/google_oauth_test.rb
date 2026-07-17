require "test_helper"

class GoogleOauthTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def mock_google(uid:, email:, name: "Google User")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid:      uid,
      info:     { email: email, name: name }
    )
  end

  def sign_in_with_google
    post "/auth/google_oauth2"
    follow_redirect!
  end

  test "user already linked to Google signs straight in" do
    user = users(:student_es)
    user.update_column(:google_uid, "g-known")
    mock_google(uid: "g-known", email: user.email_address)

    sign_in_with_google

    assert_redirected_to root_path
    assert user.sessions.any?, "a session must be created"
  end

  test "existing account with the same email is linked and signed in" do
    user = users(:student_es)
    assert_nil user.google_uid
    mock_google(uid: "g-fresh", email: user.email_address)

    sign_in_with_google

    assert_redirected_to root_path
    assert_equal "g-fresh", user.reload.google_uid
    assert user.sessions.any?
  end

  test "unknown Google account is sent to the consent step, no user is created yet" do
    mock_google(uid: "g-new", email: "newcomer@example.com", name: "New Comer")

    assert_no_difference -> { User.count } do
      sign_in_with_google
    end

    assert_redirected_to new_google_registration_path
    follow_redirect!
    assert_response :ok
    assert_match "newcomer@example.com", response.body
  end

  test "consent step creates the account with privacy acceptance recorded" do
    mock_google(uid: "g-new", email: "newcomer@example.com", name: "New Comer")
    sign_in_with_google

    assert_difference -> { User.count }, 1 do
      post google_registration_path, params: { user: { privacy_accepted: "1" } }
    end

    assert_redirected_to root_path
    user = User.find_by(email_address: "newcomer@example.com")
    assert_equal "g-new", user.google_uid
    assert_equal "New Comer", user.name
    assert_not_nil user.privacy_accepted_at
    assert user.sessions.any?
  end

  test "consent step refuses to create the account without privacy acceptance" do
    mock_google(uid: "g-new", email: "newcomer@example.com")
    sign_in_with_google

    assert_no_difference -> { User.count } do
      post google_registration_path, params: { user: { privacy_accepted: "0" } }
    end

    assert_response :unprocessable_entity
  end

  test "consent step without a pending Google sign-in redirects to the sign-in page" do
    get new_google_registration_path
    assert_redirected_to new_session_path

    post google_registration_path, params: { user: { privacy_accepted: "1" } }
    assert_redirected_to new_session_path
  end

  test "oauth failure redirects to sign-in with an alert" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    sign_in_with_google
    follow_redirect!

    assert_redirected_to new_session_path
  end
end
