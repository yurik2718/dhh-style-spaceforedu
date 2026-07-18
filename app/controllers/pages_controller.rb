class PagesController < ApplicationController
  allow_unauthenticated_access only: :privacy
  skip_after_action :verify_authorized

  def home
    return redirect_to admin_pipeline_path        if Current.user&.case_staff?
    redirect_to homologation_requests_path if Current.user&.student?
  end

  def privacy
  end
end
