require "test_helper"

class StaffMemberPolicyTest < ActiveSupport::TestCase
  test "create? is true only for super_admin" do
    assert StaffMemberPolicy.new(users(:admin),    User.new).create?
    refute StaffMemberPolicy.new(users(:staff_es), User.new).create?
    refute StaffMemberPolicy.new(users(:student_es), User.new).create?
    refute StaffMemberPolicy.new(nil,              User.new).create?
  end
end
