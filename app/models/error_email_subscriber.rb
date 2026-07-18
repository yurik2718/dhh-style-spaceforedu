# Emails production errors to the owner — a solo operator has no dashboard to
# watch, so unhandled web/job exceptions must come to the inbox. Subscribed to
# Rails.error in production (config/initializers/error_reporting.rb).
class ErrorEmailSubscriber
  DEDUP_WINDOW = 1.hour

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  def report(error, handled:, severity:, context: {}, source: nil)
    return unless recipient
    # One email per unique error per hour; also breaks any error→email→error loop.
    return unless @cache.write(fingerprint(error), true, unless_exist: true, expires_in: DEDUP_WINDOW)

    ErrorMailer.report(
      recipient:   recipient,
      error_class: error.class.name,
      message:     error.message.to_s.truncate(500),
      backtrace:   Array(error.backtrace).first(20),
      severity:    severity.to_s,
      source:      source.to_s,
      context:     context.inspect.truncate(1000)
    ).deliver_later
  rescue => e
    Rails.logger.error("[error_email_subscriber] #{e.class}: #{e.message}")
  end

  private
    def fingerprint(error)
      origin = Array(error.backtrace).first.to_s
      "error_report/#{Digest::MD5.hexdigest([ error.class.name, error.message, origin ].join("|"))}"
    end

    def recipient
      Rails.application.credentials.dig(:brand, :support_email) || User.super_admin&.email_address
    end
end
