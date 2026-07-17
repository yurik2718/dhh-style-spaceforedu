class HomologationRequestsController < ApplicationController
  def index
    scope = policy_scope(HomologationRequest).kept.order(updated_at: :desc)
    @pagy, @homologation_requests = pagy(scope)
  end

  def new
    plan_key = params[:plan].to_s.presence_in(Plan::KEYS) || "basico"
    @homologation_request = Current.user.homologation_requests.new(plan_key: plan_key)
    authorize @homologation_request
  end

  def create
    @homologation_request = Current.user.homologation_requests.new(request_params)
    authorize @homologation_request

    @homologation_request.status = "draft"

    if @homologation_request.save
      redirect_to @homologation_request, notice: t("flash.request_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @homologation_request = HomologationRequest.kept
      .includes(:user, :conversation, request_documents: { file_attachment: :blob })
      .find(params[:id])
    authorize @homologation_request
    flash.now[:notice] = t("flash.payment_processing") if params[:payment] == "success"
  end

  def edit
    @homologation_request = HomologationRequest.kept.find(params[:id])
    authorize @homologation_request, :update?

    unless @homologation_request.editable?
      redirect_to @homologation_request, alert: t("flash.request_not_editable") and return
    end
  end

  def update
    @homologation_request = HomologationRequest.kept.find(params[:id])
    authorize @homologation_request

    unless @homologation_request.editable?
      redirect_to @homologation_request, alert: t("flash.request_not_editable") and return
    end

    if @homologation_request.update(request_params)
      redirect_to @homologation_request, notice: t("flash.request_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def request_params
      params.expect(homologation_request: %i[
        subject plan_key description education_system university year
        studies_finished language_knowledge language_certificate privacy_accepted
      ])
    end
end
