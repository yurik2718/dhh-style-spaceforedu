require "test_helper"

class HomologationRequestTest < ActiveSupport::TestCase
  include PipelineConfigTestHelper

  setup do
    @admin   = users(:admin)
    @request = homologation_requests(:in_pipeline_es)
  end

  test ".kept excludes soft-deleted requests" do
    kept    = homologation_requests(:in_pipeline_es)
    trashed = homologation_requests(:discarded)

    assert_includes     HomologationRequest.kept, kept
    assert_not_includes HomologationRequest.kept, trashed
  end

  test "transition_to! updates status and stamps the audit columns" do
    freeze_time do
      @request.transition_to!("in_review", changed_by: @admin)
      @request.reload

      assert_equal "in_review",  @request.status
      assert_equal Time.current, @request.status_changed_at
      assert_equal @admin.id,    @request.status_changed_by
    end
  end

  test "transition_to! creates a Notification for the request owner" do
    assert_difference -> { @request.user.notifications.count }, 1 do
      @request.transition_to!("in_review", changed_by: @admin)
    end

    notification = @request.user.notifications.order(:created_at).last
    assert_equal @request, notification.notifiable
  end

  test "transition_to! accepts a symbol and writes it as a string" do
    @request.transition_to!(:in_review, changed_by: @admin)

    assert_equal "in_review", @request.reload.status
  end

  test "transition_to! raises InvalidTransition for an unknown status" do
    assert_raises(HomologationRequest::InvalidTransition) do
      @request.transition_to!("nonsense", changed_by: @admin)
    end
  end

  test "DB check_constraint rejects unknown status when the model is bypassed" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @request.update_column(:status, "garbage")
    end
  end

  test "confirm_payment! seeds the pipeline, transitions status, and stamps both audit trails" do
    request = homologation_requests(:awaiting_payment)

    freeze_time do
      request.confirm_payment!(confirmed_by: @admin)
      request.reload

      assert_equal "pago_recibido",     request.pipeline_stage
      assert_equal "payment_confirmed", request.status
      assert_equal Time.current,        request.payment_confirmed_at
      assert_equal Time.current,        request.pipeline_changed_at
      assert_equal Time.current,        request.status_changed_at
      assert_equal @admin.id,           request.payment_confirmed_by
      assert_equal @admin.id,           request.pipeline_changed_by
      assert_equal @admin.id,           request.status_changed_by
    end
  end

  test "confirm_payment! creates a payment_confirmed notification for the request owner" do
    request = homologation_requests(:awaiting_payment)

    request.confirm_payment!(confirmed_by: @admin)

    titles = request.user.notifications.where(notifiable: request).map(&:title)
    expected = I18n.t("notifications.payment_confirmed.title", subject: request.subject, locale: request.user.locale)
    assert_includes titles, expected
  end

  test "confirm_payment! is atomic: rolls back audit columns if the status transition fails" do
    request = homologation_requests(:awaiting_payment)
    request.singleton_class.define_method(:transition_to!) { |*| raise "boom" }

    assert_raises(RuntimeError) { request.confirm_payment!(confirmed_by: @admin) }

    request.reload
    assert_nil request.payment_confirmed_at
    assert_nil request.payment_confirmed_by
    assert_nil request.pipeline_stage
    assert_nil request.pipeline_changed_at
    assert_nil request.pipeline_changed_by
    assert_equal "awaiting_payment", request.status
  end

  test "advance_pipeline! moves to the next stage and stamps audit columns" do
    freeze_time do
      assert_equal "documentos", @request.pipeline_stage

      @request.advance_pipeline!(changed_by: @admin)
      @request.reload

      assert_equal "traduccion", @request.pipeline_stage
      assert_equal Time.current, @request.pipeline_changed_at
      assert_equal @admin.id,    @request.pipeline_changed_by
    end
  end

  test "pipeline cannot move before payment is confirmed" do
    unpaid = homologation_requests(:awaiting_payment)

    assert_raises(HomologationRequest::InvalidTransition) do
      unpaid.advance_pipeline!(changed_by: @admin)
    end
    assert_raises(HomologationRequest::InvalidTransition) do
      unpaid.retreat_pipeline!(changed_by: @admin, reason: "wrong stage")
    end
  end

  test "pipeline cannot move on a terminal request" do
    @request.update_column(:status, "closed")

    assert_raises(HomologationRequest::InvalidTransition) do
      @request.advance_pipeline!(changed_by: @admin)
    end
    assert_raises(HomologationRequest::InvalidTransition) do
      @request.retreat_pipeline!(changed_by: @admin, reason: "reopening")
    end
  end

  test "advance_pipeline! at completado raises InvalidTransition" do
    finished = homologation_requests(:at_completado)

    assert_raises(HomologationRequest::InvalidTransition) do
      finished.advance_pipeline!(changed_by: @admin)
    end
  end

  test "advance_pipeline! from redsara routes by user.country through PipelineFlow" do
    with_pipeline_fixture("pipeline_with_ministerio.yml") do
      es    = homologation_requests(:at_redsara_es)
      other = homologation_requests(:at_redsara_other)

      es.advance_pipeline!(changed_by: @admin)
      other.advance_pipeline!(changed_by: @admin)

      assert_equal "cotejo_ministerio", es.reload.pipeline_stage
      assert_equal "cotejo_delegacion", other.reload.pipeline_stage
    end
  end

  test "pipeline_changer association resolves to the user who last touched the pipeline" do
    @request.advance_pipeline!(changed_by: @admin)

    assert_equal @admin, @request.reload.pipeline_changer
  end

  test "retreat_pipeline! requires a non-blank reason" do
    assert_raises(ArgumentError) do
      @request.retreat_pipeline!(changed_by: @admin, reason: "")
    end
    assert_raises(ArgumentError) do
      @request.retreat_pipeline!(changed_by: @admin, reason: "   ")
    end
  end

  test "retreat_pipeline! moves to the previous stage and stamps audit columns" do
    freeze_time do
      @request.retreat_pipeline!(changed_by: @admin, reason: "Wrong stage")
      @request.reload

      assert_equal "pago_recibido", @request.pipeline_stage
      assert_equal Time.current,    @request.pipeline_changed_at
      assert_equal @admin.id,       @request.pipeline_changed_by
    end
  end

  test "retreat_pipeline! log entry is formatted as [iso8601] email old_stage → new_stage: reason" do
    freeze_time do
      @request.retreat_pipeline!(changed_by: @admin, reason: "Wrong stage by mistake")

      expected = "[#{Time.current.iso8601}] #{@admin.email_address} documentos → pago_recibido: Wrong stage by mistake"
      assert_equal expected, @request.reload.pipeline_notes
    end
  end

  test "retreat_pipeline! appends each retreat as a new paragraph in pipeline_notes" do
    @request.retreat_pipeline!(changed_by: @admin, reason: "first try")
    @request.advance_pipeline!(changed_by: @admin)
    @request.retreat_pipeline!(changed_by: @admin, reason: "second try")

    notes = @request.reload.pipeline_notes
    assert_match(/first try.*\n\n.*second try/m, notes)
  end

  test "retreat_pipeline! at pago_recibido raises InvalidTransition" do
    request = homologation_requests(:at_pago_recibido)

    assert_raises(HomologationRequest::InvalidTransition) do
      request.retreat_pipeline!(changed_by: @admin, reason: "test")
    end
  end

  test "checklist_done? reads serialized JSON" do
    assert @request.checklist_done?(:sol)
    refute @request.checklist_done?(:vol)
    refute @request.checklist_done?(:missing_key)
  end

  test "document_checklist round-trips as a Hash through the database" do
    @request.update!(document_checklist: { "sol" => true, "vol" => true, "extra" => false })

    reloaded = HomologationRequest.find(@request.id)

    assert_equal({ "sol" => true, "vol" => true, "extra" => false }, reloaded.document_checklist)
  end

  test "request_document is invalid when content_type is unsupported" do
    doc = @request.request_documents.build(kind: "diploma")
    doc.file.attach(io: StringIO.new("plain"), filename: "notes.txt", content_type: "text/plain")

    refute doc.valid?
    assert doc.errors[:file].any?
  end

  test "request_document is invalid when a single file exceeds 15 megabytes" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io:           StringIO.new("x"),
      filename:     "huge.pdf",
      content_type: "application/pdf"
    )
    blob.update_column(:byte_size, 16.megabytes)

    doc = @request.request_documents.build(kind: "diploma")
    doc.file.attach(blob)

    refute doc.valid?
    assert doc.errors[:file].any?
  end

  test "transition_to!(submitted) rejects a draft with no documents" do
     draft = HomologationRequest.create!(
      user:             users(:student_es),
      subject:          "Empty draft",
      plan_key: "basico",
      privacy_accepted: true
    )

    assert_raises(HomologationRequest::InvalidTransition) do
      draft.transition_to!("submitted", changed_by: @admin)
    end
    assert_equal "draft", draft.reload.status
  end

  test "transition_to! refuses to move a documentless draft to in_review (admin dropdown bypass)" do
    draft = HomologationRequest.create!(
      user: users(:student_es), subject: "Empty draft",
      plan_key: "basico", privacy_accepted: true
    )

    assert_raises(HomologationRequest::InvalidTransition) do
      draft.transition_to!("in_review", changed_by: @admin)
    end
    assert_equal "draft", draft.reload.status
  end

  test "transition_to! still allows declining a draft without documents" do
    # Admin should always be able to refuse a half-baked request outright;
    # only the active-flow transitions need the doc-completeness guard.
    draft = HomologationRequest.create!(
      user: users(:student_es), subject: "Empty draft",
      plan_key: "basico", privacy_accepted: true
    )

    draft.transition_to!("declined", changed_by: @admin)

    assert_equal "declined", draft.reload.status
  end

  test "request_more_documents! flips status to awaiting_reply and stamps the audit columns" do
    @request.transition_to!("in_review", changed_by: @admin)

    freeze_time do
      @request.request_more_documents!(by: @admin, reason: "Please re-scan the diploma.")

      @request.reload
      assert_equal "awaiting_reply", @request.status
      assert_equal Time.current,     @request.status_changed_at
      assert_equal @admin.id,        @request.status_changed_by
    end
  end

  test "request_more_documents! posts the reason as a chat message from the admin" do
    @request.transition_to!("in_review", changed_by: @admin)

    assert_difference -> { @request.conversation.messages.count }, 1 do
      @request.request_more_documents!(by: @admin, reason: "Need page 2 of the transcript.")
    end

    message = @request.conversation.messages.order(:created_at).last
    assert_equal @admin,                              message.user
    assert_equal "Need page 2 of the transcript.",    message.body
  end

  test "request_more_documents! requires a non-blank reason" do
    @request.transition_to!("in_review", changed_by: @admin)

    assert_raises(ArgumentError) do
      @request.request_more_documents!(by: @admin, reason: "")
    end
    assert_raises(ArgumentError) do
      @request.request_more_documents!(by: @admin, reason: "   ")
    end
    assert_equal "in_review", @request.reload.status
  end

  test "transition from awaiting_reply to in_review by the student notifies the super admin" do
    # When the student presses "Send reply" from awaiting_reply, the admin's
    # queue should learn about it via a single notification — replacing the
    # per-file ping we used to fire from the documents controller.
    @request.update_columns(status: "awaiting_reply", status_changed_by: @admin.id, status_changed_at: 1.hour.ago)
    student = @request.user

    assert_difference -> {
      @admin.notifications.where(notifiable: @request, title_key: "notifications.documents_added.title").count
    }, 1 do
      @request.transition_to!("in_review", changed_by: student)
    end
  end

  test "transition from awaiting_reply to in_review by the admin does not self-notify the admin" do
    @request.update_columns(status: "awaiting_reply", status_changed_by: @admin.id, status_changed_at: 1.hour.ago)

    assert_no_difference -> {
      @admin.notifications.where(notifiable: @request, title_key: "notifications.documents_added.title").count
    } do
      @request.transition_to!("in_review", changed_by: @admin)
    end
  end

  test "request_more_documents! is atomic: rolls back status if the chat write fails" do
    @request.transition_to!("in_review", changed_by: @admin)
    @request.singleton_class.define_method(:conversation) { raise "boom" }

    assert_raises(RuntimeError) do
      @request.request_more_documents!(by: @admin, reason: "won't land")
    end
    assert_equal "in_review", @request.reload.status
  end

  test "transition_to! refuses to leave a terminal status" do
    request = homologation_requests(:at_completado)
    assert request.terminal?

    assert_raises(HomologationRequest::InvalidTransition) do
      request.transition_to!("in_progress", changed_by: @admin)
    end
    assert_equal "resolved", request.reload.status
  end

  test "confirm_payment! is a no-op when payment_confirmed_at is already set" do
    request = homologation_requests(:awaiting_payment)
    request.confirm_payment!(confirmed_by: @admin)
    request.advance_pipeline!(changed_by: @admin)
    stage_after_advance      = request.reload.pipeline_stage
    confirmed_at_after_first = request.payment_confirmed_at

    travel 1.hour do
      request.confirm_payment!(confirmed_by: @admin)
    end

    request.reload
    assert_equal stage_after_advance,      request.pipeline_stage
    assert_equal confirmed_at_after_first, request.payment_confirmed_at
  end
end
