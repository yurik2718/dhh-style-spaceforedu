require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "super_admin? is true for super_admin role and false for student" do
    assert     users(:admin).super_admin?
    refute     users(:student_es).super_admin?
  end

  test "student? is true for student role and false for super_admin" do
    assert     users(:student_es).student?
    refute     users(:admin).student?
  end

  test "staff? is true for staff role and false for student or super_admin" do
    assert     User.new(role: "staff").staff?
    refute     users(:student_es).staff?
    refute     users(:admin).staff?
  end

  test "case_staff? is true for staff and super_admin, false for student or nil" do
    assert User.new(role: "staff").case_staff?
    assert users(:admin).case_staff?
    refute users(:student_es).case_staff?
  end

  test "otp_required? is true for staff or super_admin with 2FA enabled, false otherwise" do
    staff = User.new(role: "staff", otp_enabled_at: Time.current)
    assert staff.otp_required?

    admin = users(:admin)
    admin.otp_enabled_at = Time.current
    assert admin.otp_required?

    staff_without_otp = User.new(role: "staff")
    refute staff_without_otp.otp_required?

    student = users(:student_es)
    student.otp_enabled_at = Time.current
    refute student.otp_required?
  end

  test "DB check_constraint accepts staff role" do
    user = User.create!(email_address: "newstaff@example.com", password: "secret42", name: "Staff", role: "staff")

    assert_equal "staff", user.reload.role
  end

  test "initials returns the first letter of the first two words, uppercased" do
    user = User.new(name: "ana maria", email_address: "x@example.com")

    assert_equal "AM", user.initials
  end

  test "initials uses one letter when name has a single word" do
    user = User.new(name: "Anna", email_address: "x@example.com")

    assert_equal "A", user.initials
  end

  test "initials falls back to the first email letter when name is blank" do
    user = User.new(name: "", email_address: "zoe@example.com")

    assert_equal "Z", user.initials
  end

  test "initials handles unicode names" do
    user = User.new(name: "Ñoño Élise", email_address: "x@example.com")

    assert_equal "ÑÉ", user.initials
  end

  test ".kept excludes soft-deleted users" do
    assert_includes     User.kept, users(:admin)
    assert_not_includes User.kept, users(:discarded_user)
  end

  test ".case_staff returns kept super_admin and staff users, excluding students" do
    assert_includes     User.case_staff, users(:admin)
    assert_includes     User.case_staff, users(:staff_es)
    assert_not_includes User.case_staff, users(:student_es)
  end

  test ".case_staff excludes soft-deleted staff" do
    users(:staff_es).update_column(:discarded_at, Time.current)

    assert_not_includes User.case_staff, users(:staff_es)
  end

  test "DB check_constraint rejects unknown role when the model is bypassed" do
    assert_raises(ActiveRecord::StatementInvalid) do
      users(:admin).update_column(:role, "teacher")
    end
  end

  test "password must be at least 8 characters" do
    user = User.new(email_address: "short@example.com", name: "Shorty", password: "seven77")

    refute user.valid?
    assert user.errors.added?(:password, :too_short, count: 8)

    user.password = user.password_confirmation = "eight888"
    assert user.valid?
  end

  test "updating a user without touching the password stays valid" do
    user = users(:student_es)
    user.name = "Renamed"

    assert user.valid?
  end

  test "email_address validates uniqueness regardless of case" do
    invalid = User.new(email_address: "ADMIN@example.com", password: "secret42", name: "Dup")

    refute invalid.valid?
    assert invalid.errors.added?(:email_address, :taken, value: "admin@example.com")
  end

  test "phone is stored encrypted at rest" do
    user = User.create!(
      email_address: "enc@example.com",
      password:      "secret42",
      name:          "Enc",
      phone:         "+34000000000"
    )

    assert_equal "+34000000000", user.reload.phone

    raw = User.connection.select_value("SELECT phone FROM users WHERE id = #{user.id}")
    refute_equal "+34000000000", raw
    refute_nil raw
  end

  test "identity_card is stored encrypted at rest" do
    user = User.create!(
      email_address: "id@example.com",
      password:      "secret42",
      name:          "Id",
      identity_card: "12345678A"
    )

    assert_equal "12345678A", user.reload.identity_card

    raw = User.connection.select_value("SELECT identity_card FROM users WHERE id = #{user.id}")
    refute_equal "12345678A", raw
    refute_nil raw
  end

  test "passport is stored encrypted at rest" do
    user = User.create!(
      email_address: "pp@example.com",
      password:      "secret42",
      name:          "Pp",
      passport:      "AB1234567"
    )

    assert_equal "AB1234567", user.reload.passport

    raw = User.connection.select_value("SELECT passport FROM users WHERE id = #{user.id}")
    refute_equal "AB1234567", raw
    refute_nil raw
  end

  test "has_passport? is true when passport is present and false when blank" do
    user = User.new(email_address: "x@example.com", name: "X")

    refute user.has_passport?

    user.passport = "AB1234567"
    assert user.has_passport?

    user.passport = ""
    refute user.has_passport?
  end
end
