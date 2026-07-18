class ConversationsController < ApplicationController
  def show
    hr_includes = Current.user.case_staff? ? { homologation_request: :user } : :homologation_request
    @conversation = Conversation.includes(hr_includes).find(params[:id])
    authorize @conversation

    @conversation.mark_read_for!(Current.user)
    @messages = @conversation.messages.includes(:user).order(:created_at)
    @message  = Message.new
  end
end
