class User < ApplicationRecord
  has_secure_password
  has_many :sessions,               dependent: :destroy
  has_many :homologation_requests,  dependent: :destroy
  has_many :messages,               dependent: :destroy
  has_many :notifications,          dependent: :destroy
  has_many :push_subscriptions,     dependent: :destroy

  has_one_attached :avatar

  AVATAR_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  AVATAR_MAX_BYTES     = 5.megabytes

  validate :acceptable_avatar

  attr_accessor :remove_avatar
  before_save { avatar.purge if remove_avatar == "1" }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  attribute :privacy_accepted, :boolean

  validates :email_address,   presence: true, uniqueness: true
  validates :name,            presence: true
  validates :password,        length: { minimum: 8 }, allow_nil: true
  validates :privacy_accepted, acceptance: true, on: :create

  before_create { self.privacy_accepted_at = Time.current if privacy_accepted? }

  encrypts :phone, :whatsapp, :guardian_phone, :guardian_whatsapp, :guardian_name, :guardian_email,
           :identity_card, :passport,
           :telegram_chat_id, :telegram_link_token, :otp_secret

  scope :kept, -> { where(discarded_at: nil) }

  def self.super_admin = kept.where(role: "super_admin").order(:id).first

  def super_admin? = role == "super_admin"
  def student?     = role == "student"
  def has_passport? = passport.present?

  def initials
    name.split.first(2).map { _1[0].upcase }.join.presence || email_address[0].upcase
  end

  def otp_required? = super_admin? && otp_enabled_at.present?

  # Verifies a TOTP code exactly once: the consumed timestep is remembered so a
  # sniffed code cannot be replayed within its 30-second window.
  def verify_otp!(code)
    return false if otp_secret.blank?

    timestep = ROTP::TOTP.new(otp_secret).verify(
      code.to_s.gsub(/\D/, ""),
      drift_behind: 15,
      after: otp_last_verified_timestep
    )
    return false unless timestep

    update_column(:otp_last_verified_timestep, timestep)
    true
  end

  def request_deletion!
    update_column(:deletion_requested_at, Time.current)
    UserAnonymizationJob.perform_later(id)
  end

  def anonymize!
    homologation_requests.each do |request|
      request.request_documents.each { |document| document.file.purge_later }
    end

    avatar.purge_later
    sessions.destroy_all
    notifications.destroy_all
    push_subscriptions.destroy_all
    # Chat bodies are free text and routinely contain PII the student typed in;
    # the structured request rows stay (5-year expediente retention), the words go.
    messages.in_batches.update_all(body: "[eliminado]")

    delete_stripe_customer

    update_columns(
      email_address:       "deleted_#{id}@anonymized.local",
      name:                "Cuenta eliminada",
      password_digest:     BCrypt::Password.create(SecureRandom.hex(32)),
      phone:               nil,
      whatsapp:            nil,
      identity_card:       nil,
      passport:            nil,
      birthday:            nil,
      country:             nil,
      guardian_name:       nil,
      guardian_email:      nil,
      guardian_phone:      nil,
      guardian_whatsapp:   nil,
      telegram_chat_id:    nil,
      telegram_link_token: nil,
      stripe_customer_id:  nil,
      discarded_at:        Time.current
    )
  end

  def gdpr_export
    {
      exported_at: Time.current.iso8601,
      gdpr_note:   "Export generated under Art. 20 GDPR (Right to data portability).",
      profile: {
        name:                name,
        email:               email_address,
        country:             country,
        locale:              locale,
        phone:               phone,
        whatsapp:            whatsapp,
        birthday:            birthday&.iso8601,
        identity_card:       identity_card,
        passport:            passport,
        is_minor:            is_minor,
        guardian: {
          name:     guardian_name,
          email:    guardian_email,
          phone:    guardian_phone,
          whatsapp: guardian_whatsapp
        },
        telegram_chat_id:    telegram_chat_id,
        privacy_accepted_at: privacy_accepted_at&.iso8601,
        created_at:          created_at.iso8601
      },
      homologation_requests: exportable_requests.map { |r|
        { id: r.id, subject: r.subject, description: r.description,
          university: r.university, education_system: r.education_system,
          year: r.year, status: r.status,
          created_at: r.created_at.iso8601, updated_at: r.updated_at.iso8601,
          documents: r.request_documents.map { |d|
            { kind: d.kind, filename: d.file.filename.to_s,
              byte_size: d.file.byte_size, uploaded_at: d.created_at.iso8601 }
          } }
      },
      messages: messages.order(:created_at).map { |m|
        { id: m.id, body: m.body, created_at: m.created_at.iso8601 }
      }
    }
  end

  def notify(notifiable:, title_key:, body_key:, **vars)
    notifications.create!(
      notifiable: notifiable,
      title_key:  title_key,
      body_key:   body_key,
      i18n_vars:  vars
    )
  end

  private
    # Fresh query (not the association) so the export also works from
    # strict_loading contexts, with the attachments preloaded.
    def exportable_requests
      HomologationRequest.where(user_id: id)
        .includes(request_documents: { file_attachment: :blob })
    end

    # Erasure must reach the processor too (Art. 17): drop the Stripe customer
    # object, not just our local reference. Payment/charge records stay on
    # Stripe's side for their own legal retention.
    def delete_stripe_customer
      return if stripe_customer_id.blank? || Stripe.api_key.blank?

      Stripe::Customer.delete(stripe_customer_id)
    rescue Stripe::StripeError => e
      Rails.logger.warn("[gdpr] Stripe customer deletion failed for user ##{id}: #{e.message}")
    end

    def acceptable_avatar
      return unless avatar.attached?

      unless AVATAR_CONTENT_TYPES.include?(avatar.content_type)
        errors.add(:avatar, I18n.t("errors.avatar_invalid_type"))
      end

      if avatar.byte_size > AVATAR_MAX_BYTES
        errors.add(:avatar, I18n.t("errors.avatar_too_large",
                                   max: AVATAR_MAX_BYTES / 1.megabyte))
      end
    end
end
