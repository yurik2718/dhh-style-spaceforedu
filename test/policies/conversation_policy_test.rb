require "test_helper"

class ConversationPolicyTest < ActiveSupport::TestCase
  setup do
    @admin   = users(:admin)
    @student = users(:student_es)
    @other   = users(:student_other)
    @conv    = conversations(:in_pipeline_es)
  end

  test "admin can show any conversation" do
    assert ConversationPolicy.new(@admin, @conv).show?
  end

  test "staff can show any conversation" do
    assert ConversationPolicy.new(users(:staff_es), @conv).show?
  end

  test "owner can show their conversation" do
    assert ConversationPolicy.new(@student, @conv).show?
  end

  test "other student cannot show a conversation they don't own" do
    refute ConversationPolicy.new(@other, @conv).show?
  end

  test "guest cannot show any conversation" do
    refute ConversationPolicy.new(nil, @conv).show?
  end
end
