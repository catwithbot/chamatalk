class Whatsapp::QuickDispatchService
  E164_PATTERN = /\A\+[1-9]\d{1,14}\z/.freeze
  INVALID_NUMBER_ERROR = 'Informe um número de telefone válido no formato E.164, por exemplo +5511999999999.'.freeze
  NO_CHANNEL_ERROR = 'Não há uma caixa de entrada do Meta WhatsApp Cloud configurada para esta conta.'.freeze
  INVALID_TEMPLATE_ERROR = 'O modelo selecionado não foi encontrado ou não está aprovado para esta caixa de entrada.'.freeze
  UNSUPPORTED_TEMPLATE_ERROR = 'O modelo selecionado não é compatível com o disparo rápido.'.freeze
  INVALID_PARAMETERS_ERROR = 'Informe um valor para cada variável do corpo do modelo.'.freeze
  META_SEND_ERROR = 'Não foi possível enviar este modelo pelo Meta.'.freeze

  def self.available_templates(account:)
    channel = meta_cloud_channel_for(account)
    return [] if channel.blank?

    Array(channel.message_templates).filter_map { |template| template_metadata(template) }.sort_by { |template| [template[:name], template[:language]] }
  end

  def initialize(account:, actor:, phone_numbers:, template_name:, template_language:, template_parameters: [], remote_address: nil)
    @account = account
    @actor = actor
    @phone_numbers = phone_numbers
    @template_name = template_name.to_s
    @template_language = template_language.to_s
    @template_parameters = Array(template_parameters).map(&:to_s)
    @remote_address = remote_address
  end

  def perform
    @channel = self.class.meta_cloud_channel_for(account)
    return recipients.map { |phone_number| audit(phone_number, unavailable_result(phone_number)) } if channel.blank?

    @template, @template_error = selected_template
    return recipients.map { |phone_number| audit(phone_number, invalid_template_result(phone_number, template_error)) } if template_error.present?

    recipients.map { |phone_number| dispatch(phone_number) }
  end

  class << self
    def meta_cloud_channel_for(account)
      account.inboxes
             .where(channel_type: 'Channel::Whatsapp')
             .joins('INNER JOIN channel_whatsapp ON channel_whatsapp.id = inboxes.channel_id')
             .where(channel_whatsapp: { provider: 'whatsapp_cloud' })
             .order('channel_whatsapp.id ASC')
             .first
             &.channel
    end

    private

    def template_metadata(template)
      return unless approved_template?(template) && compatible_template?(template)

      body = body_component(template)['text']
      {
        name: template['name'],
        language: template['language'],
        category: template['category'],
        body: body,
        parameter_count: body_variable_indexes(body).length
      }
    end

    def approved_template?(template)
      template['status'].to_s.casecmp?('APPROVED')
    end

    def compatible_template?(template)
      components = Array(template['components'])
      body = body_component(template)
      return false if body.blank? || !body['text'].is_a?(String)
      return false unless components.all? { |component| %w[BODY FOOTER].include?(component['type']) }

      body_variables_are_positional?(body['text'])
    end

    def body_component(template)
      Array(template['components']).find { |component| component['type'] == 'BODY' }
    end

    def body_variables_are_positional?(body)
      variables = body.scan(/\{\{([^}]+)\}\}/).flatten
      return true if variables.empty?

      indexes = variables.map { |variable| Integer(variable, exception: false) }
      indexes.none?(&:nil?) && indexes == (1..indexes.length).to_a
    end

    def body_variable_indexes(body)
      body.scan(/\{\{(\d+)\}\}/).flatten.map(&:to_i)
    end
  end

  private

  attr_reader :account, :actor, :phone_numbers, :template_name, :template_language, :template_parameters, :remote_address, :channel, :template, :template_error

  def recipients
    phone_numbers.to_s.split(/[\s,;]+/).reject(&:blank?).uniq
  end

  def selected_template
    candidate = Array(channel.message_templates).find do |item|
      item['name'] == template_name && item['language'] == template_language
    end
    return [nil, INVALID_TEMPLATE_ERROR] unless candidate && self.class.send(:approved_template?, candidate)
    return [nil, UNSUPPORTED_TEMPLATE_ERROR] unless self.class.send(:compatible_template?, candidate)
    return [nil, INVALID_PARAMETERS_ERROR] unless valid_parameter_values?(candidate)

    [candidate, nil]
  end

  def valid_parameter_values?(candidate)
    expected_count = self.class.send(:body_variable_indexes, self.class.send(:body_component, candidate)['text']).length
    template_parameters.length == expected_count && template_parameters.all?(&:present?)
  end

  def dispatch(phone_number)
    return audit(phone_number, invalid_result(phone_number)) unless valid_e164?(phone_number)

    message_id = channel.provider_service.send_template(identifier(phone_number), template_payload, nil)
    result = message_id.present? ? sent_result(phone_number, message_id) : failed_result(phone_number, 'O Meta não retornou o identificador da mensagem.')
    audit(phone_number, result)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP_QUICK_DISPATCH] account_id=#{account.id} channel_id=#{channel&.id} recipient=#{phone_number} error=#{e.class}: #{e.message}")
    audit(phone_number, failed_result(phone_number, META_SEND_ERROR))
  end

  def template_payload
    body_parameters = template_parameters.map { |value| { type: 'text', text: value } }
    {
      name: template['name'],
      lang_code: template['language'],
      parameters: body_parameters.present? ? [{ type: 'body', parameters: body_parameters }] : []
    }
  end

  def identifier(phone_number)
    phone_number.delete_prefix('+')
  end

  def valid_e164?(phone_number)
    phone_number.match?(E164_PATTERN)
  end

  def sent_result(phone_number, message_id)
    { phone_number: phone_number, status: 'sent', message_id: message_id }
  end

  def invalid_result(phone_number)
    { phone_number: phone_number, status: 'invalid', error: INVALID_NUMBER_ERROR }
  end

  def unavailable_result(phone_number)
    { phone_number: phone_number, status: 'unavailable', error: NO_CHANNEL_ERROR }
  end

  def invalid_template_result(phone_number, error)
    { phone_number: phone_number, status: 'invalid_template', error: error }
  end

  def failed_result(phone_number, error)
    { phone_number: phone_number, status: 'failed', error: error }
  end

  def audit(phone_number, result)
    Audited.audit_class.create!(
      auditable: channel || account,
      action: 'quick_dispatch',
      user: actor,
      associated: account,
      remote_address: remote_address,
      audited_changes: {
        'recipient' => phone_number,
        'channel_id' => channel&.id,
        'status' => result[:status],
        'message_id' => result[:message_id],
        'error' => result[:error]
      }.compact
    )
    result
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP_QUICK_DISPATCH_AUDIT] account_id=#{account.id} recipient=#{phone_number} error=#{e.class}: #{e.message}")
    result
  end
end