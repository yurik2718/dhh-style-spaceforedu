require "test_helper"

class MessagePolicyTest < ActiveSupport::TestCase
  setup do
    @admin   = users(:admin)
    @student = users(:student_es)
    @other   = users(:student_other)
    @message = messages(:old_admin_hello)
  end

  test "admin can create a message in any conversation" do
    assert MessagePolicy.new(@admin, @message).create?
  end

  test "staff can create a message in any conversation" do
    assert MessagePolicy.new(users(:staff_es), @message).create?
  end

  test "owner can create a message in their conversation" do
    assert MessagePolicy.new(@student, @message).create?
  end

  test "other student cannot create a message in a conversation they don't own" do
    refute MessagePolicy.new(@other, @message).create?
  end

  test "guest cannot create a message" do
    refute MessagePolicy.new(nil, @message).create?
  end
end
