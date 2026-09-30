import ApiClient from './ApiClient';

class WhatsappQuickDispatch extends ApiClient {
  constructor() {
    super('whatsapp_quick_dispatch', { accountScoped: true });
  }
}

export default new WhatsappQuickDispatch();
