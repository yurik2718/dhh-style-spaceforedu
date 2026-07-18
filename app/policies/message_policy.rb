class MessagePolicy < ApplicationPolicy
  def create?
    user&.case_staff? || record.conversation.homologation_request.user_id == user&.id
  end
end
