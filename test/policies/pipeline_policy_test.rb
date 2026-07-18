require "test_helper"

class PipelinePolicyTest < ActiveSupport::TestCase
  test "show? is true for super_admin" do
    assert PipelinePolicy.new(users(:admin), :pipeline).show?
  end

  test "show? is true for staff" do
    assert PipelinePolicy.new(users(:staff_es), :pipeline).show?
  end

  test "show? is false for student" do
    refute PipelinePolicy.new(users(:student_es), :pipeline).show?
  end

  test "show? is false when user is nil" do
    refute PipelinePolicy.new(nil, :pipeline).show?
  end
end
