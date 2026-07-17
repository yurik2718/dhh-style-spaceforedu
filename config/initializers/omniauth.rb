Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret),
           scope: "email,profile"
end

# POST-only request phase (omniauth-rails_csrf_protection verifies the token).
OmniAuth.config.allowed_request_methods = %i[post]

# Redirect to /auth/failure in every environment instead of raising.
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
