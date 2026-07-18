require "test_helper"

class HomologationRequestDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student = users(:student_es)
    @draft   = @student.homologation_requests.create!(
      subject: "Draft for upload", plan_key: "basico",
      status: "draft", privacy_accepted: true
    )
  end

  test "POST create attaches a file to the slot and redirects with a notice" do
    sign_in_as @student

    assert_difference -> { @draft.request_documents.count }, 1 do
      post homologation_request_documents_path(@draft),
           params: { kind: "diploma", file: upload_fixture(filename: "diploma.pdf") }
    end

    assert_redirected_to homologation_request_path(@draft)
    doc = @draft.request_documents.find_by(kind: "diploma")
    assert doc.file.attached?
  end

  test "POST create on an existing slot replaces the file" do
    sign_in_as @student
    attach_request_document(@draft, kind: "diploma", filename: "first.pdf")

    assert_no_difference -> { @draft.request_documents.count } do
      post homologation_request_documents_path(@draft),
           params: { kind: "diploma", file: upload_fixture(filename: "second.pdf") }
    end

    assert_redirected_to homologation_request_path(@draft)
    assert_equal "second.pdf", @draft.request_documents.find_by(kind: "diploma").file.filename.to_s
  end

  test "POST create rejects an unsupported content_type and keeps the slot empty" do
    sign_in_as @student

    post homologation_request_documents_path(@draft),
         params:  { kind: "diploma", file: upload_fixture(filename: "notes.txt", content: "plain note", content_type: "text/plain") },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_equal 0, @draft.request_documents.count
    assert_match %r{<turbo-stream\s+action="replace"\s+target="request_document_slot_diploma"}, response.body
  end

  test "POST create rejects an oversized file" do
    sign_in_as @student
    big = Rack::Test::UploadedFile.new(StringIO.new("x" * (16.megabytes)), "application/pdf", original_filename: "huge.pdf")

    post homologation_request_documents_path(@draft),
         params: { kind: "diploma", file: big }

    assert_equal 0, @draft.request_documents.count
  end

  test "POST create rejects an unknown kind" do
    sign_in_as @student

    post homologation_request_documents_path(@draft),
         params: { kind: "secret_dossier", file: upload_fixture }

    assert_redirected_to homologation_request_path(@draft)
    assert_equal I18n.t("flash.invalid_document_kind"), flash[:alert]
  end

  test "uploading documents while awaiting_reply does not ping the super admin per file" do
    # The admin learns about the response once, when the student presses
    # "Send reply" — not every time they drop a file. Each individual upload
    # must be silent on the admin side.
    awaiting_reply = @student.homologation_requests.create!(
      subject: "Reply needed", plan_key: "basico",
      status: "awaiting_reply", privacy_accepted: true
    )
    admin = users(:admin)
    sign_in_as @student

    assert_no_difference -> {
      admin.notifications.where(notifiable: awaiting_reply, title_key: "notifications.documents_added.title").count
    } do
      post homologation_request_documents_path(awaiting_reply),
           params: { kind: "diploma", file: upload_fixture }
    end
  end

  test "uploading documents while in draft does not ping the super admin" do
    sign_in_as @student
    admin = users(:admin)

    assert_no_difference -> { admin.notifications.where(notifiable: @draft).count } do
      post homologation_request_documents_path(@draft),
           params: { kind: "diploma", file: upload_fixture }
    end
  end

  test "DELETE destroy removes the slot record" do
    sign_in_as @student
    doc = attach_request_document(@draft, kind: "diploma")

    assert_difference -> { @draft.request_documents.count }, -1 do
      delete homologation_request_document_path(@draft, doc.id)
    end

    assert_redirected_to homologation_request_path(@draft)
  end

  test "GET show streams the file to the request owner, even in a locked status" do
    sign_in_as @student
    doc = attach_request_document(@draft, kind: "passport", content: "%PDF-1.4 passport")
    @draft.update_column(:status, "submitted")

    get homologation_request_document_path(@draft, doc.id)

    assert_response :ok
    assert_equal "%PDF-1.4 passport", response.body
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/passport_/, response.headers["Content-Disposition"])
  end

  test "GET show streams the file to the admin" do
    sign_in_as users(:admin)
    doc = attach_request_document(@draft, kind: "diploma")

    get homologation_request_document_path(@draft, doc.id)

    assert_response :ok
  end

  test "GET show leaves an audit trail of who downloaded the document" do
    sign_in_as users(:admin)
    doc = attach_request_document(@draft, kind: "passport")

    assert_difference -> { DocumentAccess.count }, 1 do
      get homologation_request_document_path(@draft, doc.id)
    end

    access = DocumentAccess.last
    assert_equal users(:admin), access.user
    assert_equal "download",    access.via
  end

  test "GET show refuses another student's document" do
    sign_in_as users(:student_other)
    doc = attach_request_document(@draft, kind: "passport")

    get homologation_request_document_path(@draft, doc.id)

    assert_redirected_to root_path
  end

  test "GET show requires authentication" do
    doc = attach_request_document(@draft, kind: "passport")

    get homologation_request_document_path(@draft, doc.id)

    assert_redirected_to new_session_path
  end

  test "non-editable status blocks uploads" do
    sign_in_as @student
    submitted = @student.homologation_requests.create!(
      subject: "x", plan_key: "basico", status: "submitted", privacy_accepted: true
    )

    post homologation_request_documents_path(submitted),
         params: { kind: "diploma", file: upload_fixture }

    assert_redirected_to homologation_request_path(submitted)
    assert_equal I18n.t("flash.request_not_editable"), flash[:alert]
    assert_equal 0, submitted.request_documents.count
  end
end
