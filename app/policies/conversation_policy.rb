class ConversationPolicy < ApplicationPolicy
  def show?
    user&.case_staff? || record.homologation_request.user_id == user&.id
  end
end
