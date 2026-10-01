require 'rails_helper'

RSpec.describe Whatsapp::QuickDispatchService do
  let(:account) { create(:account) }
  let(:actor) { create(:user, account: account, role: :administrator) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService) }
  let(:template) do
    {
      'name' => 'order_update',
      'language' => 'pt_BR',
      'status' => 'APPROVED',
      'category' => 'UTILITY',
      'components' => [{ 'type' => 'BODY', 'text' => 'Olá {{1}}, seu pedido {{2}} foi enviado.' }]
    }
  end

  before do
    channel.update!(message_templates: [template])
    allow_any_instance_of(Channel::Whatsapp).to receive(:provider_service).and_return(provider)
    allow(Audited.audit_class).to receive(:create!)
  end

  describe '#perform' do
    it 'sends the selected approved Meta template to every valid E.164 recipient without requiring a 24-hour window' do
      allow(provider).to receive(:send_template)
        .with('15551234567', {
                name: 'order_update',
                lang_code: 'pt_BR',
                parameters: [{ type: 'body', parameters: [{ type: 'text', text: 'Ana' }, { type: 'text', text: '123' }] }]
              }, nil)
        .and_return('wamid.1')

      result = described_class.new(
        account: account,
        actor: actor,
        phone_numbers: '+15551234567',
        template_name: 'order_update',
        template_language: 'pt_BR',
        template_parameters: %w[Ana 123]
      ).perform

      expect(result).to eq([{ phone_number: '+15551234567', status: 'sent', message_id: 'wamid.1' }])
      expect(provider).to have_received(:send_template).once
    end

    it 'rejects a template that is not approved for the selected Meta Cloud inbox' do
      result = described_class.new(
        account: account,
        actor: actor,
        phone_numbers: '+15551234567',
        template_name: 'not_approved',
        template_language: 'pt_BR',
        template_parameters: []
      ).perform

      expect(result.first).to include(status: 'invalid_template')
      expect(provider).not_to have_received(:send_template)
    end

    it 'reports invalid pasted values without calling Meta' do
      result = described_class.new(
        account: account,
        actor: actor,
        phone_numbers: '15551234567',
        template_name: 'order_update',
        template_language: 'pt_BR',
        template_parameters: %w[Ana 123]
      ).perform

      expect(result).to include(status: 'invalid')
      expect(provider).not_to have_received(:send_template)
    end

    it 'rejects templates with unsupported components without calling Meta' do
      channel.update!(message_templates: [template.merge('components' => [
        { 'type' => 'HEADER', 'format' => 'IMAGE' },
        { 'type' => 'BODY', 'text' => 'Olá {{1}}' }
      ])])

      result = described_class.new(
        account: account,
        actor: actor,
        phone_numbers: '+15551234567',
        template_name: 'order_update',
        template_language: 'pt_BR',
        template_parameters: ['Ana']
      ).perform

      expect(result.first).to include(status: 'invalid_template', error: 'O modelo selecionado não é compatível com o disparo rápido.')
      expect(provider).not_to have_received(:send_template)
    end

    it 'requires exactly one value for each BODY variable' do
      result = described_class.new(
        account: account,
        actor: actor,
        phone_numbers: '+15551234567',
        template_name: 'order_update',
        template_language: 'pt_BR',
        template_parameters: ['Ana']
      ).perform

      expect(result.first).to include(status: 'invalid_template', error: 'Informe um valor para cada variável do corpo do modelo.')
      expect(provider).not_to have_received(:send_template)
    end
  end

  describe '.available_templates' do
    it 'lists only approved plain BODY templates from the lowest-id Meta Cloud channel' do
      unsupported = template.merge('name' => 'with_header', 'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Olá {{1}}' }])
      channel.update!(message_templates: [template, unsupported.merge('status' => 'PENDING')])
      second_channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      second_channel.update!(message_templates: [template.merge('name' => 'other_channel_template')])

      expect(described_class.available_templates(account: account)).to eq([
        { name: 'order_update', language: 'pt_BR', category: 'UTILITY', body: 'Olá {{1}}, seu pedido {{2}} foi enviado.', parameter_count: 2 }
      ])
    end
  end
end
