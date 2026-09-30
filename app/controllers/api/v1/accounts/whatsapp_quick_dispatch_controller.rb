class Api::V1::Accounts::WhatsappQuickDispatchController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator

  def create
    return render json: { error: validation_error }, status: :unprocessable_entity if invalid_request?

    results = Whatsapp::QuickDispatchService.new(
      account: Current.account,
      actor: Current.user,
      phone_numbers: params[:phone_numbers],
      body: params[:body],
      remote_address: request.remote_ip
    ).perform

    render json: { results: results }
  end

  private

  def ensure_administrator
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def invalid_request?
    params[:phone_numbers].blank? || params[:body].blank? || params[:body].to_s.length > 4096
  end

  def validation_error
    return 'Messages are limited to 4096 characters.' if params[:body].to_s.length > 4096

    'Provide at least one E.164 phone number and a message.'
  end
end