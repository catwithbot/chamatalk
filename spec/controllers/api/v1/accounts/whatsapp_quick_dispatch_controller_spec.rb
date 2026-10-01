require 'rails_helper'

RSpec.describe 'API de disparo rápido do WhatsApp', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/whatsapp_quick_dispatch" }

  it 'returns approved compatible templates from the current account service' do
    templates = [{ name: 'order_update', language: 'pt_BR', category: 'UTILITY', body: 'Olá {{1}}', parameter_count: 1 }]
    allow(Whatsapp::QuickDispatchService).to receive(:available_templates).with(account: account).and_return(templates)

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('templates' => [{ 'name' => 'order_update', 'language' => 'pt_BR', 'category' => 'UTILITY', 'body' => 'Olá {{1}}', 'parameter_count' => 1 }])
  end

  it 'dispatches the selected template through the current account service and returns per-recipient results' do
    service = instance_double(Whatsapp::QuickDispatchService, perform: [{ phone_number: '+15551234567', status: 'sent', message_id: 'wamid.1' }])
    expect(Whatsapp::QuickDispatchService).to receive(:new).with(
      account: account,
      actor: admin,
      phone_numbers: '+15551234567',
      template_name: 'order_update',
      template_language: 'pt_BR',
      template_parameters: ['Ana'],
      remote_address: kind_of(String)
    ).and_return(service)

    post url, params: { phone_numbers: '+15551234567', template_name: 'order_update', template_language: 'pt_BR', template_parameters: ['Ana'] },
              headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('results' => [{ 'phone_number' => '+15551234567', 'status' => 'sent', 'message_id' => 'wamid.1' }])
  end

  it 'rejects non-administrators' do
    post url, params: { phone_numbers: '+15551234567', template_name: 'order_update', template_language: 'pt_BR' },
              headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'requires recipients, a template name and a template language before dispatching' do
    expect(Whatsapp::QuickDispatchService).not_to receive(:new)

    post url, params: { phone_numbers: '', template_name: '', template_language: '' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'Informe ao menos um número E.164, o nome e o idioma do modelo aprovado.')
  end
end