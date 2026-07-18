class Admin::HomologationRequests::ArchivesController < ApplicationController
  def show
    request_record = HomologationRequest.kept
      .includes(:user, request_documents: { file_attachment: :blob })
      .find(params[:homologation_request_id])
    authorize request_record, :manage_pipeline?

    archive = RequestArchive.new(request_record)
    request_record.request_documents.each { |document| document.record_access!(by: Current.user, via: "archive") }
    send_data archive.zip_body,
              type:        "application/zip",
              filename:    archive.filename,
              disposition: "attachment"
  end
end
