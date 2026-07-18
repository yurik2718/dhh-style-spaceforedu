class Conversation < ApplicationRecord
  # touch: true propagates Conversation#last_message_at updates to the parent HR's updated_at,
  # which fires HomologationRequest.broadcasts_refreshes — admin and student show pages then morph
  # in place when a new chat message arrives.
  belongs_to :homologation_request, strict_loading: false, touch: true
  has_many   :messages, dependent: :destroy

  def student
    homologation_request.user
  end

  def unread_for?(user)
    last_read = user.case_staff? ? admin_last_read_at : student_last_read_at
    messages.where("created_at > ?", last_read || Time.at(0)).exists?
  end

  def mark_read_for!(user)
    if user.case_staff?
      update!(admin_last_read_at: Time.current)
    else
      update!(student_last_read_at: Time.current)
    end
  end
end
