class Admin::StaffMembersController < ApplicationController
  def new
    @staff_member = User.new
    authorize @staff_member, policy_class: StaffMemberPolicy
  end

  def create
    authorize User.new, policy_class: StaffMemberPolicy

    @staff_member = User.new(staff_member_params.merge(
      role:             "staff",
      password:         SecureRandom.hex(32),
      privacy_accepted: true
    ))

    if @staff_member.save
      PasswordsMailer.reset(@staff_member).deliver_later
      redirect_to admin_pipeline_path, notice: t("flash.staff_member_invited")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def staff_member_params
      params.expect(user: %i[name email_address])
    end
end
