class HomologationRequestDocumentsController < ApplicationController
  before_action :set_request
  before_action :require_editable, except: :show

  # Documents hold passport-grade PII, so they are streamed through the app
  # after a Pundit check instead of being linked as signed Active Storage URLs
  # anyone holding the link could fetch.
  def show
    authorize @homologation_request, :show?

    document = @homologation_request.request_documents.find(params[:id])
    document.record_access!(by: Current.user, via: "download")
    send_data document.file.download,
              filename:    document.download_filename,
              type:        document.file.content_type,
              disposition: "attachment"
  end

  def create
    authorize @homologation_request, :update?

    @kind = params[:kind].to_s
    unless RequestDocument::KINDS.include?(@kind)
      redirect_to @homologation_request, alert: t("flash.invalid_document_kind") and return
    end

    @document = @homologation_request.request_documents.find_or_initialize_by(kind: @kind)

    RequestDocument.transaction do
      @document.file.attach(params[:file])
      @document.save!
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @homologation_request, notice: t("flash.document_uploaded") }
    end
  rescue ActiveRecord::RecordInvalid
    # Render only the offending slot — nothing was saved, so progress and the
    # submit button still reflect the prior state and don't need replacing.
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "request_document_slot_#{@kind}",
          partial: "homologation_requests/document_slot",
          locals:  { hr: @homologation_request, kind: @kind, document: @document, can_edit: true }
        ), status: :unprocessable_entity
      end
      format.html { redirect_to @homologation_request, alert: @document.errors.full_messages.to_sentence }
    end
  end

  def destroy
    authorize @homologation_request, :update?

    @document = @homologation_request.request_documents.find(params[:id])
    @kind     = @document.kind
    @document.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @homologation_request, notice: t("flash.document_removed") }
    end
  end

  private
    def set_request
      @homologation_request = HomologationRequest.kept
        .includes(:user)
        .find(params[:homologation_request_id])
    end

    def require_editable
      return if @homologation_request.editable?
      redirect_to @homologation_request, alert: t("flash.request_not_editable")
    end
end
