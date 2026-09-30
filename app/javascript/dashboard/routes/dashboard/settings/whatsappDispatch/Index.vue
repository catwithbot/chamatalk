<script setup>
import { computed, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import WhatsappQuickDispatchApi from 'dashboard/api/whatsappQuickDispatch';

const phoneNumbers = ref('');
const body = ref('');
const confirmed = ref(false);
const submitting = ref(false);
const results = ref([]);

const recipientCount = computed(
  () => new Set(phoneNumbers.value.split(/[\s,;]+/).filter(Boolean)).size
);
const canSubmit = computed(
  () => phoneNumbers.value.trim() && body.value.trim() && confirmed.value && !submitting.value
);

const dispatch = async () => {
  if (!canSubmit.value) return;

  submitting.value = true;
  results.value = [];
  try {
    const { data } = await WhatsappQuickDispatchApi.create({
      phone_numbers: phoneNumbers.value,
      body: body.value,
    });
    results.value = data.results;
    const sent = results.value.filter(result => result.status === 'sent').length;
    useAlert(`Quick dispatch completed: ${sent} sent, ${results.value.length - sent} not sent.`);
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Quick dispatch could not be completed.');
  } finally {
    submitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-6">
    <BaseSettingsHeader
      title="WhatsApp quick dispatch"
      description="Send free-form text through this account’s configured Meta WhatsApp Cloud inbox. The lowest-ID configured Meta Cloud inbox is selected automatically."
    />

    <div class="p-4 border rounded-xl border-n-strong bg-n-warning-2 text-n-slate-12">
      <p class="font-medium">Meta 24-hour policy</p>
      <p class="mt-1 text-sm">
        A recipient must have sent an inbound WhatsApp message to the selected inbox within the last 24 hours. Ineligible recipients are not sent a message; use an approved template instead.
      </p>
    </div>

    <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
      E.164 phone numbers
      <textarea
        v-model="phoneNumbers"
        rows="7"
        class="w-full p-3 font-mono text-sm border rounded-lg resize-y bg-n-solid-1 border-n-strong text-n-slate-12"
        placeholder="+15551234567&#10;+15557654321"
      />
      <span class="font-normal text-n-slate-11">Paste one number per line, or separate numbers with commas or spaces. {{ recipientCount }} unique recipient(s).</span>
    </label>

    <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
      Message
      <textarea
        v-model="body"
        rows="5"
        maxlength="4096"
        class="w-full p-3 text-sm border rounded-lg resize-y bg-n-solid-1 border-n-strong text-n-slate-12"
        placeholder="Type the free-form message to send"
      />
    </label>

    <label class="flex items-start gap-2 text-sm text-n-slate-12">
      <input v-model="confirmed" type="checkbox" class="mt-0.5" />
      <span>I confirm these recipients are eligible for a free-form message within Meta’s 24-hour customer-service window.</span>
    </label>

    <Button
      label="Send WhatsApp messages"
      color="blue"
      :is-loading="submitting"
      :disabled="!canSubmit"
      @click="dispatch"
    />

    <section v-if="results.length" class="w-full">
      <h2 class="mb-3 text-heading-3 text-n-slate-12">Per-recipient results</h2>
      <div class="overflow-hidden border rounded-xl border-n-strong">
        <div
          v-for="result in results"
          :key="`${result.phone_number}-${result.status}`"
          class="grid grid-cols-[minmax(0,1fr)_auto] gap-3 p-3 border-b last:border-b-0 border-n-strong"
        >
          <div class="min-w-0">
            <p class="font-mono text-sm text-n-slate-12">{{ result.phone_number }}</p>
            <p v-if="result.error" class="mt-1 text-sm text-n-slate-11">{{ result.error }}</p>
            <p v-if="result.message_id" class="mt-1 text-xs text-n-slate-11">Meta ID: {{ result.message_id }}</p>
          </div>
          <span class="self-start px-2 py-1 text-xs font-medium rounded bg-n-alpha-2 text-n-slate-12">{{ result.status }}</span>
        </div>
      </div>
    </section>
  </div>
</template>
