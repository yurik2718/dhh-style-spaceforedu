# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # PII fields — GDPR
  :phone, :whatsapp, :guardian_phone, :guardian_whatsapp, :guardian_email,
  :telegram_chat_id, :guardian_name,
  :identity_card, :passport, :birthday, :name,
  # Free-text fields — chat and request content routinely carry PII
  :body, :description, :subject, :university, :pipeline_notes, :country
]
