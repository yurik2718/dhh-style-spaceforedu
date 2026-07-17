class AdminDigestMailer < ApplicationMailer
  def weekly(admin:, stale:, inbox:)
    @stale = stale
    @inbox = inbox

    I18n.with_locale(admin.locale) do
      mail to: admin.email_address,
           subject: t("admin_digest.subject", stale: stale.size, inbox: inbox.size)
    end
  end
end
