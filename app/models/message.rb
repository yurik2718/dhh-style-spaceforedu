class Message < ApplicationRecord
  belongs_to :conversation, strict_loading: false
  belongs_to :user,         strict_loading: false

  validates :body, presence: true

  after_create_commit -> { broadcast_append_to conversation }
  after_create_commit :touch_conversation
  after_create_commit :notify_counterpart

  private
    def touch_conversation
      conversation.update!(last_message_at: created_at)
    end

    def notify_counterpart
      recipient = counterpart
      return unless recipient

      recipient.notify(
        notifiable: conversation.homologation_request,
        title_key:  "notifications.new_message.title",
        body_key:   "notifications.new_message.body",
        subject:    conversation.homologation_request.subject,
        sender:     user.name
      )
    end

    def counterpart
      owner = conversation.homologation_request.user
      user == owner ? User.super_admin : owner
    end
end
