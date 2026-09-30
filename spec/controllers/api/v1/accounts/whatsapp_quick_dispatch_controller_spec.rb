require 'rails_helper'

RSpec.describe 'WhatsApp quick dispatch API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/whatsapp_quick_dispatch" }

  it 'dispatches through the current account service and returns per-recipient results' do
    service = instance_double(Whatsapp::QuickDispatchService, perform: [{ phone_number: '+15551234567', status: 'sent', message_id: 'wamid.1' }])
    expect(Whatsapp::QuickDispatchService).to receive(:new).with(
      account: account,
      actor: admin,
      phone_numbers: '+15551234567',
      body: 'Hello',
      remote_address: kind_of(String)
    ).and_return(service)

    post url, params: { phone_numbers: '+15551234567', body: 'Hello' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('results' => [{ 'phone_number' => '+15551234567', 'status' => 'sent', 'message_id' => 'wamid.1' }])
  end

  it 'rejects non-administrators' do
    post url, params: { phone_numbers: '+15551234567', body: 'Hello' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'requires recipients and a message before dispatching' do
    expect(Whatsapp::QuickDispatchService).not_to receive(:new)

    post url, params: { phone_numbers: '', body: '' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects text over Meta\'s 4096-character limit before dispatching' do
    expect(Whatsapp::QuickDispatchService).not_to receive(:new)

    post url, params: { phone_numbers: '+15551234567', body: 'a' * 4097 }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'Messages are limited to 4096 characters.')
  end
end
