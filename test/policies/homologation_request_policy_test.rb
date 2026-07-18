require "test_helper"

class HomologationRequestPolicyTest < ActiveSupport::TestCase
  setup do
    @admin   = users(:admin)
    @staff   = users(:staff_es)
    @student = users(:student_es)
    @other   = users(:student_other)
    @owned   = homologation_requests(:in_pipeline_es)
  end

  test "show? is true for super_admin viewing any request" do
    assert HomologationRequestPolicy.new(@admin, @owned).show?
  end

  test "show? is true for staff viewing any request" do
    assert HomologationRequestPolicy.new(@staff, @owned).show?
  end

  test "show? is true for the student who owns the request" do
    assert HomologationRequestPolicy.new(@student, @owned).show?
  end

  test "show? is false for a different student" do
    refute HomologationRequestPolicy.new(@other, @owned).show?
  end

  test "show? is false when user is nil" do
    refute HomologationRequestPolicy.new(nil, @owned).show?
  end

  test "manage_pipeline? is true only for super_admin" do
    assert HomologationRequestPolicy.new(@admin,   @owned).manage_pipeline?
    refute HomologationRequestPolicy.new(@staff,   @owned).manage_pipeline?
    refute HomologationRequestPolicy.new(@student, @owned).manage_pipeline?
    refute HomologationRequestPolicy.new(nil,      @owned).manage_pipeline?
  end

  test "manage_case? is true for super_admin and staff, false for students" do
    assert HomologationRequestPolicy.new(@admin,   @owned).manage_case?
    assert HomologationRequestPolicy.new(@staff,   @owned).manage_case?
    refute HomologationRequestPolicy.new(@student, @owned).manage_case?
    refute HomologationRequestPolicy.new(nil,      @owned).manage_case?
  end

  test "create? is true for any signed-in student" do
    assert HomologationRequestPolicy.new(@student, HomologationRequest.new).create?
    refute HomologationRequestPolicy.new(nil,      HomologationRequest.new).create?
  end

  test "update? is true for the owner only" do
    assert HomologationRequestPolicy.new(@student, @owned).update?
    refute HomologationRequestPolicy.new(@other,   @owned).update?
    refute HomologationRequestPolicy.new(nil,      @owned).update?
  end

  test "submit? is true for the owner only" do
    assert HomologationRequestPolicy.new(@student, @owned).submit?
    refute HomologationRequestPolicy.new(@other,   @owned).submit?
    refute HomologationRequestPolicy.new(nil,      @owned).submit?
  end

  test "Scope#resolve returns all requests for super_admin" do
    resolved = HomologationRequestPolicy::Scope.new(@admin, HomologationRequest.all).resolve

    assert_equal HomologationRequest.count, resolved.count
  end

  test "Scope#resolve returns all requests for staff" do
    resolved = HomologationRequestPolicy::Scope.new(@staff, HomologationRequest.all).resolve

    assert_equal HomologationRequest.count, resolved.count
  end

  test "Scope#resolve returns only own requests for a student" do
    resolved = HomologationRequestPolicy::Scope.new(@student, HomologationRequest.all).resolve

    assert_equal @student.homologation_requests.pluck(:id).sort, resolved.pluck(:id).sort
    refute_includes resolved, homologation_requests(:at_redsara_other)
  end

  test "Scope#resolve returns nothing for a nil user" do
    resolved = HomologationRequestPolicy::Scope.new(nil, HomologationRequest.all).resolve

    assert_empty resolved
  end
end
