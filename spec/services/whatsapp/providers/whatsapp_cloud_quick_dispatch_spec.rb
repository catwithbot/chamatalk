require 'rails_helper'

RSpec.describe Whatsapp::Providers::WhatsappCloudService do
  describe '#send_text' do
    let(:channel) do
      create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    end

    it 'posts a direct text payload to the configured Meta Cloud phone number' do
      stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
        .with(
          headers: { 'Authorization' => 'Bearer test_key', 'Content-Type' => 'application/json' },
          body: {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: '15551234567',
            text: { body: 'Hello' },
            type: 'text'
          }.to_json
        )
        .to_return(status: 200, body: { messages: [{ id: 'wamid.1' }] }.to_json, headers: { 'Content-Type' => 'application/json' })

      message_id = described_class.new(whatsapp_channel: channel).send_text('15551234567', 'Hello')

      expect(message_id).to eq('wamid.1')
    end
  end
end
