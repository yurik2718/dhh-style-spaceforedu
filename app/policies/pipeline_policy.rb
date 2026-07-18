class PipelinePolicy < ApplicationPolicy
  def show? = user&.case_staff?
end
