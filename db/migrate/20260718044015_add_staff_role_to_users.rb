class AddStaffRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :users, name: "valid_role"
    add_check_constraint :users, "role IN ('super_admin', 'staff', 'student')", name: "valid_role"
  end

  def down
    remove_check_constraint :users, name: "valid_role"
    add_check_constraint :users, "role IN ('super_admin', 'student')", name: "valid_role"
  end
end
