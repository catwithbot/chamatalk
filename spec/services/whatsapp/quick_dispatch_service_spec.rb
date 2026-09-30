require 'rails_helper'

RSpec.describe Whatsapp::QuickDispatchService do
  let(:account) { create(:account) }
  let(:actor) { create(:user, account: account, role: :administrator) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

  before do
    allow_any_instance_of(Channel::Whatsapp).to receive(:provider_service).and_return(provider)
    allow(Audited.audit_class).to receive(:create!)
  end

  describe '#perform' do
    it 'uses the lowest-id Cloud channel and sends only to a recipient with an inbound message in the last 24 hours' do
      second_channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      contact_inbox = create(:contact_inbox, inbox: inbox, source_id: '15551234567')
      conversation = create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox)
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, created_at: 23.hours.ago)
      allow(provider).to receive(:send_text).with('15551234567', 'Hello').and_return('wamid.1')


      result = described_class.new(account: account, actor: actor, phone_numbers: "+15551234567\n+15557654321", body: 'Hello').perform

      expect(result).to eq([
                             { phone_number: '+15551234567', status: 'sent', message_id: 'wamid.1' },
                             { phone_number: '+15557654321', status: 'ineligible', error: 'Free-form WhatsApp messages require an inbound message from this recipient within the last 24 hours. Use a template instead.' }
                           ])
      expect(provider).to have_received(:send_text).once
    end

    it 'does not use a channel or conversation from another account to establish eligibility' do
      other_account = create(:account)
      other_channel = create(:channel_whatsapp, account: other_account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      other_contact_inbox = create(:contact_inbox, inbox: other_channel.inbox, source_id: '15551234567')
      other_conversation = create(:conversation, account: other_account, inbox: other_channel.inbox, contact_inbox: other_contact_inbox)
      create(:message, account: other_account, inbox: other_channel.inbox, conversation: other_conversation, message_type: :incoming, created_at: 1.hour.ago)

      result = described_class.new(account: account, actor: actor, phone_numbers: '+15551234567', body: 'Hello').perform

      expect(result.first).to include(status: 'ineligible')
      expect(provider).not_to have_received(:send_text)
    end

    it 'reports invalid pasted values without calling Meta' do
      result = described_class.new(account: account, actor: actor, phone_numbers: '15551234567', body: 'Hello').perform

      expect(result).to eq([{ phone_number: '15551234567', status: 'invalid', error: 'Enter a valid E.164 phone number, for example +15551234567.' }])
      expect(provider).not_to have_received(:send_text)
    end
  end
end
