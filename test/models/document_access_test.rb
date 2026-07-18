require "test_helper"

class DocumentAccessTest < ActiveSupport::TestCase
  test "record_access! writes who, what and how" do
    document = attach_request_document(homologation_requests(:in_pipeline_es), kind: "passport")
    admin    = users(:admin)

    access = document.record_access!(by: admin, via: "download")

    assert_equal admin,      access.user
    assert_equal document,   access.request_document
    assert_equal "download", access.via
  end

  test "access rows disappear with the document" do
    document = attach_request_document(homologation_requests(:in_pipeline_es), kind: "diploma")
    document.record_access!(by: users(:admin), via: "archive")

    document.destroy!

    assert_equal 0, DocumentAccess.count
  end

  test "via only accepts the known channels" do
    document = attach_request_document(homologation_requests(:in_pipeline_es), kind: "diploma")

    assert_raises(ActiveRecord::RecordInvalid) do
      document.record_access!(by: users(:admin), via: "carrier_pigeon")
    end
  end
end
