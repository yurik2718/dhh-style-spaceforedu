class HomologationRequestPolicy < ApplicationPolicy
  def show?            = user&.case_staff? || record.user_id == user&.id
  def create?          = user.present?
  def update?          = record.user_id == user&.id
  def submit?          = record.user_id == user&.id
  def checkout?        = record.user_id == user&.id && record.status == "awaiting_payment"
  def manage_case?     = user&.case_staff?
  def manage_pipeline? = user&.super_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.case_staff?
        scope.all
      else
        scope.where(user_id: user&.id)
      end
    end
  end
end
