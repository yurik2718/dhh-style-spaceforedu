require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home redirects super_admin to the admin pipeline" do
    sign_in_as users(:admin)
    get root_path
    assert_redirected_to admin_pipeline_path
  end

  test "home redirects staff to the admin pipeline" do
    sign_in_as users(:staff_es)
    get root_path
    assert_redirected_to admin_pipeline_path
  end

  test "home redirects student to their requests" do
    sign_in_as users(:student_es)
    get root_path
    assert_redirected_to homologation_requests_path
  end
end
