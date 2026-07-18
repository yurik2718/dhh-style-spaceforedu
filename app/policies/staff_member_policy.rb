class StaffMemberPolicy < ApplicationPolicy
  def create? = user&.super_admin?
end
