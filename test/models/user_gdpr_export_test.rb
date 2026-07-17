require "test_helper"

class UserGdprExportTest < ActiveSupport::TestCase
  setup do
    @user = users(:student_es)
  end

  test "export includes identity, guardian and messenger data (Art. 20 covers all provided data)" do
    @user.update!(
      passport:          "AB1234567",
      identity_card:     "12345678Z",
      is_minor:          true,
      guardian_name:     "Pedro Pérez",
      guardian_email:    "pedro@example.com",
      guardian_phone:    "+34 600 111 222",
      guardian_whatsapp: "+34 600 111 222",
      telegram_chat_id:  "42"
    )

    profile = @user.gdpr_export[:profile]

    assert_equal "AB1234567", profile[:passport]
    assert_equal "12345678Z", profile[:identity_card]
    assert profile[:is_minor]
    assert_equal "Pedro Pérez",      profile[:guardian][:name]
    assert_equal "pedro@example.com", profile[:guardian][:email]
    assert_equal "+34 600 111 222",  profile[:guardian][:phone]
    assert_equal "42", profile[:telegram_chat_id]
  end

  test "export lists uploaded documents per request" do
    hr = homologation_requests(:in_pipeline_es)
    attach_request_document(hr, kind: "passport", filename: "scan.pdf")

    exported = @user.gdpr_export[:homologation_requests].find { |r| r[:id] == hr.id }

    document = exported[:documents].sole
    assert_equal "passport", document[:kind]
    assert_equal "scan.pdf", document[:filename]
  end
end
