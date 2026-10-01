class Api::V1::Accounts::WhatsappQuickDispatchController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator

  def show
    render json: { templates: Whatsapp::QuickDispatchService.available_templates(account: Current.account) }
  end

  def create
    return render json: { error: validation_error }, status: :unprocessable_entity if invalid_request?

    results = Whatsapp::QuickDispatchService.new(
      account: Current.account,
      actor: Current.user,
      phone_numbers: params[:phone_numbers],
      template_name: params[:template_name],
      template_language: params[:template_language],
      template_parameters: params[:template_parameters],
      remote_address: request.remote_ip
    ).perform

    render json: { results: results }
  end

  private

  def ensure_administrator
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def invalid_request?
    params[:phone_numbers].blank? || params[:template_name].blank? || params[:template_language].blank?
  end

  def validation_error
    'Informe ao menos um número E.164, o nome e o idioma do modelo aprovado.'
  end
end