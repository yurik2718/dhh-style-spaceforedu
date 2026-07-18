module ApplicationHelper
  def flash_alert_class(type)
    case type.to_sym
    when :notice, :success then "alert-success"
    when :alert, :error    then "alert-error"
    when :warning          then "alert-warning"
    else                        "alert-info"
    end
  end

  def format_eur(amount)
    number_to_currency amount, unit: "€", format: "%n %u", precision: 0
  end

  def status_badge_class(status)
    case status
    when "draft"                        then "badge-neutral"
    when "submitted", "in_review"       then "badge-info"
    when "awaiting_reply",
         "awaiting_payment"             then "badge-warning"
    when "payment_confirmed", "resolved" then "badge-success"
    when "in_progress"                  then "badge-primary"
    when "declined"                     then "badge-error"
    when "closed"                       then "badge-neutral"
    else                                     "badge-neutral"
    end
  end

  def nav_pill_class(*paths)
    active = paths.any? { |path| current_page?(path) }
    active ? "nav-pill nav-pill-active" : "nav-pill"
  end

  def available_locales
    I18n.available_locales
  end

  def locale_label(locale)
    locale.to_s.upcase
  end

  # Native labels let users find their language regardless of current locale.
  NATIVE_LOCALE_LABELS = {
    en: "English",
    es: "Español",
    ru: "Русский"
  }.freeze

  def native_locale_label(locale)
    NATIVE_LOCALE_LABELS.fetch(locale.to_sym, locale.to_s.upcase)
  end

  # Fallbacks keep pages rendering locally before master.key arrives.
  def support_email
    Rails.application.credentials.dig(:brand, :support_email) || "support@example.com"
  end

  def support_whatsapp
    Rails.application.credentials.dig(:brand, :support_whatsapp) || "+00 000 000 000"
  end

  def support_whatsapp_url
    "https://wa.me/#{support_whatsapp.gsub(/\D/, '')}"
  end

  def brand_location
    Rails.application.credentials.dig(:brand, :location) || "City, Country"
  end

  def google_sign_in_enabled?
    Rails.application.credentials.dig(:google, :client_id).present?
  end

  def marketing_url(path = nil)
    base = Rails.application.credentials.dig(:brand, :marketing_url) || "https://spaceforedu.com"
    suffix = path.present? ? "#{path}/" : ""
    "#{base}/#{I18n.locale}/#{suffix}"
  end

  def brand_name
    Rails.application.credentials.dig(:brand, :name) || "Space for Edu"
  end

  def brand_cif
    Rails.application.credentials.dig(:brand, :cif) || "[CIF pendiente]"
  end

  def brand_address
    Rails.application.credentials.dig(:brand, :address) || brand_location
  end

  def privacy_contact_email
    Rails.application.credentials.dig(:brand, :privacy_email) || support_email
  end

  def masked_phone(value)
    return "—" if value.blank?
    digits = value.to_s.gsub(/\D/, "")
    return "•" * value.to_s.length if digits.length < 4
    "#{'•' * (digits.length - 4)}#{digits.last(4)}"
  end
end
