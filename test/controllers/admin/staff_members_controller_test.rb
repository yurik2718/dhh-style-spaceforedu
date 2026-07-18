require "test_helper"

class Admin::StaffMembersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @admin = users(:admin)
  end

  test "GET new renders for super_admin" do
    sign_in_as @admin
    get new_admin_staff_member_path
    assert_response :success
  end

  test "GET new redirects staff to root" do
    sign_in_as users(:staff_es)
    get new_admin_staff_member_path
    assert_redirected_to root_path
  end

  test "GET new redirects students to root" do
    sign_in_as users(:student_es)
    get new_admin_staff_member_path
    assert_redirected_to root_path
  end

  test "GET new redirects unauthenticated visitors to sign in" do
    get new_admin_staff_member_path
    assert_redirected_to new_session_path
  end

  test "POST create makes a staff account and emails a password-set link" do
    sign_in_as @admin

    assert_difference -> { User.where(role: "staff").count }, 1 do
      post admin_staff_members_path, params: { user: { name: "New Staffer", email_address: "newstaffer@example.com" } }
    end

    staff_member = User.find_by(email_address: "newstaffer@example.com")
    assert_equal "staff", staff_member.role
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ staff_member ]
    assert_redirected_to admin_pipeline_path
    assert_equal I18n.t("flash.staff_member_invited"), flash[:notice]
  end

  test "POST create with a blank name re-renders the form with errors" do
    sign_in_as @admin

    assert_no_difference -> { User.count } do
      post admin_staff_members_path, params: { user: { name: "", email_address: "blank@example.com" } }
    end

    assert_response :unprocessable_entity
  end

  test "POST create with a duplicate email re-renders the form with errors" do
    sign_in_as @admin

    assert_no_difference -> { User.count } do
      post admin_staff_members_path, params: { user: { name: "Dup", email_address: @admin.email_address } }
    end

    assert_response :unprocessable_entity
  end

  test "POST create by staff is rejected" do
    sign_in_as users(:staff_es)

    assert_no_difference -> { User.count } do
      post admin_staff_members_path, params: { user: { name: "X", email_address: "x@example.com" } }
    end

    assert_redirected_to root_path
  end

  test "POST create by students is rejected" do
    sign_in_as users(:student_es)

    assert_no_difference -> { User.count } do
      post admin_staff_members_path, params: { user: { name: "X", email_address: "x@example.com" } }
    end

    assert_redirected_to root_path
  end

  test "POST create unauthenticated redirects to sign in" do
    post admin_staff_members_path, params: { user: { name: "X", email_address: "x@example.com" } }
    assert_redirected_to new_session_path
  end
end
