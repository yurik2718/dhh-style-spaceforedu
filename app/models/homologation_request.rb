class HomologationRequest < ApplicationRecord
  belongs_to :user
  # Audit-trail accessors — accessed at most once per page and often nil; let them lazy-load.
  belongs_to :status_changer,    class_name: "User", optional: true, foreign_key: :status_changed_by,    strict_loading: false
  belongs_to :payment_confirmer, class_name: "User", optional: true, foreign_key: :payment_confirmed_by, strict_loading: false
  belongs_to :pipeline_changer,  class_name: "User", optional: true, foreign_key: :pipeline_changed_by,  strict_loading: false
  has_one    :conversation, dependent: :destroy

  has_many :request_documents, dependent: :destroy, inverse_of: :homologation_request

  broadcasts_refreshes

  serialize :document_checklist, coder: JSON

  scope :kept, -> { where(discarded_at: nil) }

  STATUSES = %w[
    draft submitted in_review awaiting_reply
    awaiting_payment payment_confirmed in_progress
    resolved closed declined
  ].freeze

  EDITABLE_STATUSES = %w[draft awaiting_reply].freeze
  TERMINAL_STATUSES = %w[resolved closed declined].freeze

  validates :plan_key, inclusion: { in: Plan::KEYS }
  validates :privacy_accepted, acceptance: true, on: :create

  after_create_commit :create_conversation
  after_commit :notify_admin_of_submission,       on: :update, if: -> { saved_change_to_status?(to: "submitted") }
  after_commit :notify_admin_of_documents_reply,  on: :update,
               if: -> { saved_change_to_status?(from: "awaiting_reply", to: "in_review") && status_changed_by == user_id }

  def editable? = status.in?(EDITABLE_STATUSES)
  def declined? = status == "declined"
  def plan      = Plan.find(plan_key)
  def amount    = plan.amount

  def terminal? = status.in?(TERMINAL_STATUSES)

  def transition_to!(new_status, changed_by:)
    unless STATUSES.include?(new_status.to_s)
      raise InvalidTransition, "Unknown status: #{new_status}"
    end

    if terminal? && new_status.to_s != status
      raise InvalidTransition, "cannot transition from terminal status #{status}"
    end

    # All required documents must be on file before a request becomes "submitted"
    # OR moves out of "draft" into any active status. The only exempt destinations
    # are staying in "draft" and being "declined" (admin can refuse a half-baked
    # request outright).
    needs_full_documents = new_status.to_s == "submitted" ||
                           (status == "draft" && !new_status.to_s.in?(%w[draft declined]))

    if needs_full_documents && !ready_to_submit?
      raise InvalidTransition, "Request needs all required documents"
    end

    transaction do
      update!(
        status:            new_status.to_s,
        status_changed_at: Time.current,
        status_changed_by: changed_by.id
      )
      notify_owner_of_status_change
    end
  end

  def confirm_payment!(confirmed_by:)
    return if payment_confirmed_at.present?

    transaction do
      update!(
        payment_confirmed_at: Time.current,
        payment_confirmed_by: confirmed_by.id,
        pipeline_stage:       PipelineFlow::STARTING_STAGE,
        pipeline_changed_at:  Time.current,
        pipeline_changed_by:  confirmed_by.id
      )
      transition_to!("payment_confirmed", changed_by: confirmed_by)
      notify_owner_of_payment_confirmed
    end
  end

  def decline!(by:, reason:)
    raise ArgumentError, "reason can't be blank" if reason.to_s.strip.empty?

    transaction do
      transition_to!("declined", changed_by: by)
      conv = conversation || Conversation.create!(homologation_request: self)
      conv.messages.create!(user: by, body: reason.strip)
      conv.update!(last_message_at: Time.current)
    end
  end

  def request_more_documents!(by:, reason:)
    raise ArgumentError, "reason can't be blank" if reason.to_s.strip.empty?

    transaction do
      transition_to!("awaiting_reply", changed_by: by)
      conv = conversation || Conversation.create!(homologation_request: self)
      conv.messages.create!(user: by, body: reason.strip)
      conv.update!(last_message_at: Time.current)
    end
  end

  def advance_pipeline!(changed_by:)
    ensure_pipeline_movable!
    next_stage = PipelineFlow.next_stage(pipeline_stage, country: user.country)
    raise InvalidTransition, "no next pipeline stage from #{pipeline_stage.inspect}" if next_stage.nil?

    update!(
      pipeline_stage:      next_stage,
      pipeline_changed_at: Time.current,
      pipeline_changed_by: changed_by.id
    )
  end

  def retreat_pipeline!(changed_by:, reason:)
    ensure_pipeline_movable!
    raise ArgumentError, "reason can't be blank" if reason.to_s.strip.empty?

    prev_stage = PipelineFlow.previous_stage(pipeline_stage, country: user.country)
    raise InvalidTransition, "no previous pipeline stage from #{pipeline_stage.inspect}" if prev_stage.nil?

    log_entry = "[#{Time.current.iso8601}] #{changed_by.email_address} #{pipeline_stage} → #{prev_stage}: #{reason.strip}"

    update!(
      pipeline_stage:      prev_stage,
      pipeline_changed_at: Time.current,
      pipeline_changed_by: changed_by.id,
      pipeline_notes:      [ pipeline_notes.presence, log_entry ].compact.join("\n\n")
    )
  end

  def ready_to_submit?
    (RequestDocument::REQUIRED_KINDS - request_documents.pluck(:kind)).empty?
  end

  def checklist_done?(key)
    document_checklist.is_a?(Hash) && document_checklist[key.to_s]
  end

  class InvalidTransition < StandardError; end

  private
    # The kanban exists only between "money received" and a terminal outcome —
    # the two axes must not drift apart.
    def ensure_pipeline_movable!
      raise InvalidTransition, "pipeline requires a confirmed payment" if payment_confirmed_at.blank?
      raise InvalidTransition, "cannot move pipeline of a #{status} request" if terminal?
    end

    def notify_admin_of_submission
      User.case_staff.each do |admin|
        admin.notify(
          notifiable: self,
          title_key:  "notifications.request_submitted.title",
          body_key:   "notifications.request_submitted.body",
          subject:    subject,
          student:    user.name
        )
      end
    end

    def notify_owner_of_status_change
      return if status_changed_by == user_id
      user.notify(
        notifiable:  self,
        title_key:   "notifications.status_changed.title",
        body_key:    "notifications.status_changed.body",
        subject:     subject,
        status_code: status
      )
    end

    def notify_owner_of_payment_confirmed
      user.notify(
        notifiable: self,
        title_key:  "notifications.payment_confirmed.title",
        body_key:   "notifications.payment_confirmed.body",
        subject:    subject
      )
    end

    def notify_admin_of_documents_reply
      User.case_staff.each do |admin|
        admin.notify(
          notifiable: self,
          title_key:  "notifications.documents_added.title",
          body_key:   "notifications.documents_added.body",
          subject:    subject,
          student:    user.name
        )
      end
    end

    def create_conversation
      Conversation.create!(homologation_request: self)
    end
end
