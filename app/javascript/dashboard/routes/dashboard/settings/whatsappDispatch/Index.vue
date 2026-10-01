<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import WhatsappQuickDispatchApi from 'dashboard/api/whatsappQuickDispatch';

const phoneNumbers = ref('');
const templates = ref([]);
const selectedTemplateKey = ref('');
const templateParameters = ref([]);
const confirmed = ref(false);
const submitting = ref(false);
const loadingTemplates = ref(true);
const results = ref([]);

const recipientCount = computed(
  () => new Set(phoneNumbers.value.split(/[\s,;]+/).filter(Boolean)).size
);
const selectedTemplate = computed(() =>
  templates.value.find(
    template => `${template.name}:${template.language}` === selectedTemplateKey.value
  )
);
const canSubmit = computed(
  () =>
    phoneNumbers.value.trim() &&
    selectedTemplate.value &&
    templateParameters.value.every(parameter => parameter.trim()) &&
    confirmed.value &&
    !submitting.value
);

const resultStatus = status =>
  ({
    sent: 'enviado',
    invalid: 'número inválido',
    invalid_template: 'modelo inválido',
    unavailable: 'indisponível',
    failed: 'falhou',
  })[status] || status;

const loadTemplates = async () => {
  loadingTemplates.value = true;
  try {
    const { data } = await WhatsappQuickDispatchApi.getTemplates();
    templates.value = data.templates || [];
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Não foi possível carregar os modelos aprovados do WhatsApp.');
  } finally {
    loadingTemplates.value = false;
  }
};

watch(selectedTemplate, template => {
  templateParameters.value = Array.from(
    { length: template?.parameter_count || 0 },
    () => ''
  );
});

const dispatch = async () => {
  if (!canSubmit.value) return;

  submitting.value = true;
  results.value = [];
  try {
    const { data } = await WhatsappQuickDispatchApi.create({
      phone_numbers: phoneNumbers.value,
      template_name: selectedTemplate.value.name,
      template_language: selectedTemplate.value.language,
      template_parameters: templateParameters.value,
    });
    results.value = data.results;
    const sent = results.value.filter(result => result.status === 'sent').length;
    useAlert(`Disparo concluído: ${sent} enviado(s) e ${results.value.length - sent} não enviado(s).`);
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Não foi possível concluir o disparo.');
  } finally {
    submitting.value = false;
  }
};

onMounted(loadTemplates);
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-6">
    <BaseSettingsHeader
      title="Disparo rápido pelo WhatsApp"
      description="Envie um modelo aprovado pelo Meta WhatsApp Cloud. A caixa de entrada Meta Cloud com o menor ID desta conta é selecionada automaticamente."
    />

    <div class="p-4 border rounded-xl border-n-strong bg-n-warning-2 text-n-slate-12">
      <p class="font-medium">Somente modelos aprovados</p>
      <p class="mt-1 text-sm">
        Este disparo usa modelos aprovados pelo Meta e não depende da janela de atendimento de 24 horas.
      </p>
    </div>

    <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
      Números de telefone E.164
      <textarea
        v-model="phoneNumbers"
        rows="7"
        class="w-full p-3 font-mono text-sm border rounded-lg resize-y bg-n-solid-1 border-n-strong text-n-slate-12"
        placeholder="+5511999999999&#10;+5521999999999"
      />
      <span class="font-normal text-n-slate-11">Cole um número por linha ou separe os números por vírgulas ou espaços. {{ recipientCount }} destinatário(s) único(s).</span>
    </label>

    <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
      Modelo aprovado
      <select
        v-model="selectedTemplateKey"
        :disabled="loadingTemplates"
        class="w-full p-3 text-sm border rounded-lg bg-n-solid-1 border-n-strong text-n-slate-12"
      >
        <option value="" disabled>{{ loadingTemplates ? 'Carregando modelos...' : 'Selecione um modelo' }}</option>
        <option
          v-for="template in templates"
          :key="`${template.name}:${template.language}`"
          :value="`${template.name}:${template.language}`"
        >
          {{ template.name }} ({{ template.language }} · {{ template.category }})
        </option>
      </select>
      <span v-if="!loadingTemplates && !templates.length" class="font-normal text-n-slate-11">Não há modelos compatíveis e aprovados para a caixa de entrada selecionada.</span>
    </label>

    <div v-if="selectedTemplate" class="flex flex-col gap-3 p-4 border rounded-xl border-n-strong">
      <p class="text-sm text-n-slate-12 whitespace-pre-wrap">{{ selectedTemplate.body }}</p>
      <label
        v-for="(_, index) in templateParameters"
        :key="index"
        class="flex flex-col gap-2 text-sm font-medium text-n-slate-12"
      >
        Variável {{ index + 1 }}
        <input
          v-model="templateParameters[index]"
          type="text"
          :placeholder="`Valor para {{${index + 1}}}`"
          class="w-full p-3 text-sm border rounded-lg bg-n-solid-1 border-n-strong text-n-slate-12"
        />
      </label>
    </div>

    <label class="flex items-start gap-2 text-sm text-n-slate-12">
      <input v-model="confirmed" type="checkbox" class="mt-0.5" />
      <span>Confirmo que os destinatários autorizaram o recebimento deste modelo.</span>
    </label>

    <Button
      label="Enviar modelos do WhatsApp"
      color="blue"
      :is-loading="submitting"
      :disabled="!canSubmit"
      @click="dispatch"
    />

    <section v-if="results.length" class="w-full">
      <h2 class="mb-3 text-heading-3 text-n-slate-12">Resultado por destinatário</h2>
      <div class="overflow-hidden border rounded-xl border-n-strong">
        <div
          v-for="result in results"
          :key="`${result.phone_number}-${result.status}`"
          class="grid grid-cols-[minmax(0,1fr)_auto] gap-3 p-3 border-b last:border-b-0 border-n-strong"
        >
          <div class="min-w-0">
            <p class="font-mono text-sm text-n-slate-12">{{ result.phone_number }}</p>
            <p v-if="result.error" class="mt-1 text-sm text-n-slate-11">{{ result.error }}</p>
            <p v-if="result.message_id" class="mt-1 text-xs text-n-slate-11">ID do Meta: {{ result.message_id }}</p>
          </div>
          <span class="self-start px-2 py-1 text-xs font-medium rounded bg-n-alpha-2 text-n-slate-12">{{ resultStatus(result.status) }}</span>
        </div>
      </div>
    </section>
  </div>
</template>