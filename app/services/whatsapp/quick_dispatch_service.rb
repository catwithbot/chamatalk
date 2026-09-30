class Whatsapp::QuickDispatchService
  E164_PATTERN = /\A\+[1-9]\d{1,14}\z/.freeze
  WINDOW_ERROR = 'Free-form WhatsApp messages require an inbound message from this recipient within the last 24 hours. Use a template instead.'.freeze
  INVALID_NUMBER_ERROR = 'Enter a valid E.164 phone number, for example +15551234567.'.freeze
  NO_CHANNEL_ERROR = 'No Meta WhatsApp Cloud inbox is configured for this account.'.freeze

  def initialize(account:, actor:, phone_numbers:, body:, remote_address: nil)
    @account = account
    @actor = actor
    @phone_numbers = phone_numbers
    @body = body.to_s
    @remote_address = remote_address
  end

  def perform
    @channel = meta_cloud_channel
    recipients.map { |phone_number| dispatch(phone_number) }
  end

  private

  attr_reader :account, :actor, :phone_numbers, :body, :remote_address, :channel

  def recipients
    phone_numbers.to_s.split(/[\s,;]+/).reject(&:blank?).uniq
  end

  def dispatch(phone_number)
    return audit(phone_number, invalid_result(phone_number)) unless valid_e164?(phone_number)
    return audit(phone_number, unavailable_result(phone_number)) if channel.blank?
    return audit(phone_number, ineligible_result(phone_number)) unless within_customer_service_window?(phone_number)

    message_id = channel.provider_service.send_text(identifier(phone_number), body)
    result = message_id.present? ? sent_result(phone_number, message_id) : failed_result(phone_number, 'Meta did not return a message id.')
    audit(phone_number, result)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP_QUICK_DISPATCH] account_id=#{account.id} channel_id=#{channel&.id} recipient=#{phone_number} error=#{e.class}: #{e.message}")
    audit(phone_number, failed_result(phone_number, 'Meta could not send this message.'))
  end

  def meta_cloud_channel
    account.inboxes
           .where(channel_type: 'Channel::Whatsapp')
           .joins('INNER JOIN channel_whatsapp ON channel_whatsapp.id = inboxes.channel_id')
           .where(channel_whatsapp: { provider: 'whatsapp_cloud' })
           .order('channel_whatsapp.id ASC')
           .first
           &.channel
  end

  def within_customer_service_window?(phone_number)
    contact_inbox = channel.inbox.contact_inboxes.find_by(source_id: identifier(phone_number))
    return false if contact_inbox.blank?

    Message.incoming.where(conversation_id: contact_inbox.conversations.select(:id)).where(created_at: 24.hours.ago..).exists?
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

  def ineligible_result(phone_number)
    { phone_number: phone_number, status: 'ineligible', error: WINDOW_ERROR }
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