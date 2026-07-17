class ErrorMailer < ApplicationMailer
  def report(recipient:, error_class:, message:, backtrace:, severity:, source:, context:)
    @error_class = error_class
    @message     = message
    @backtrace   = backtrace
    @severity    = severity
    @source      = source
    @context     = context

    mail to: recipient, subject: "[spaceforedu] #{error_class}: #{message.truncate(80)}"
  end
end
