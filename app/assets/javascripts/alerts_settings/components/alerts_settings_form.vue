<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlFormTextarea,
  GlLink,
  GlModal,
  GlModalDirective,
  GlSprintf,
  GlFormSelect,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { s__ } from '~/locale';
import { doesHashExistInUrl } from '~/lib/utils/url_utility';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import ToggleButton from '~/vue_shared/components/toggle_button.vue';
import IntegrationsList from './alerts_integrations_list.vue';
import csrf from '~/lib/utils/csrf';
import service from '../services';
import {
  i18n,
  serviceOptions,
  JSON_VALIDATE_DELAY,
  targetPrometheusUrlPlaceholder,
  targetOpsgenieUrlPlaceholder,
  sectionHash,
} from '../constants';
import createFlash, { FLASH_TYPES } from '~/flash';

export default {
  i18n,
  csrf,
  targetOpsgenieUrlPlaceholder,
  targetPrometheusUrlPlaceholder,
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormInputGroup,
    GlFormSelect,
    GlFormTextarea,
    GlLink,
    GlModal,
    GlSprintf,
    ClipboardButton,
    ToggleButton,
    IntegrationsList,
  },
  directives: {
    'gl-modal': GlModalDirective,
  },
  inject: ['prometheus', 'generic', 'opsgenie'],
  data() {
    return {
      loading: false,
      selectedEndpoint: serviceOptions[0].value,
      options: serviceOptions,
      active: false,
      authKey: '',
      targetUrl: '',
      feedback: {
        variant: 'danger',
        feedbackMessage: '',
        isFeedbackDismissed: false,
      },
      testAlert: {
        json: null,
        error: null,
      },
      canSaveForm: false,
      serverError: null,
    };
  },
  computed: {
    sections() {
      return [
        {
          text: this.$options.i18n.usageSection,
          url: this.generic.alertsUsageUrl,
        },
        {
          text: this.$options.i18n.setupSection,
          url: this.generic.alertsSetupUrl,
        },
      ];
    },
    isPrometheus() {
      return this.selectedEndpoint === 'prometheus';
    },
    isOpsgenie() {
      return this.selectedEndpoint === 'opsgenie';
    },
    selectedService() {
      switch (this.selectedEndpoint) {
        case 'generic': {
          return {
            url: this.generic.url,
            authKey: this.generic.authorizationKey,
            activated: this.generic.activated,
            resetKey: this.resetKey.bind(this),
          };
        }
        case 'prometheus': {
          return {
            url: this.prometheus.prometheusUrl,
            authKey: this.prometheus.authorizationKey,
            activated: this.prometheus.activated,
            resetKey: this.resetKey.bind(this, 'prometheus'),
            targetUrl: this.prometheus.prometheusApiUrl,
          };
        }
        case 'opsgenie': {
          return {
            targetUrl: this.opsgenie.opsgenieMvcTargetUrl,
            activated: this.opsgenie.activated,
          };
        }
        default: {
          return {};
        }
      }
    },
    showFeedbackMsg() {
      return this.feedback.feedbackMessage && !this.isFeedbackDismissed;
    },
    showAlertSave() {
      return (
        this.feedback.feedbackMessage === this.$options.i18n.testAlertFailed &&
        !this.isFeedbackDismissed
      );
    },
    prometheusInfo() {
      return this.isPrometheus ? this.$options.i18n.prometheusInfo : '';
    },
    jsonIsValid() {
      return this.testAlert.error === null;
    },
    canTestAlert() {
      return this.active && this.testAlert.json !== null;
    },
    canSaveConfig() {
      return !this.loading && this.canSaveForm;
    },
    baseUrlPlaceholder() {
      return this.isOpsgenie
        ? this.$options.targetOpsgenieUrlPlaceholder
        : this.$options.targetPrometheusUrlPlaceholder;
    },
    integrations() {
      return [
        {
          name: s__('AlertSettings|HTTP endpoint'),
          type: s__('AlertsIntegrations|HTTP endpoint'),
          activated: this.generic.activated,
        },
        {
          name: s__('AlertSettings|External Prometheus'),
          type: s__('AlertsIntegrations|Prometheus'),
          activated: this.prometheus.activated,
        },
      ];
    },
  },
  watch: {
    'testAlert.json': debounce(function debouncedJsonValidate() {
      this.validateJson();
    }, JSON_VALIDATE_DELAY),
    targetUrl(oldVal, newVal) {
      if (newVal && oldVal !== this.selectedService.targetUrl) {
        this.canSaveForm = true;
      }
    },
  },
  mounted() {
    if (
      this.prometheus.activated ||
      this.generic.activated ||
      !this.opsgenie.opsgenieMvcIsAvailable
    ) {
      this.removeOpsGenieOption();
    } else if (this.opsgenie.activated) {
      this.setOpsgenieAsDefault();
    }
    this.active = this.selectedService.activated;
    this.authKey = this.selectedService.authKey ?? '';
  },
  methods: {
    createUserErrorMessage(errors = { error: [''] }) {
      // eslint-disable-next-line prefer-destructuring
      this.serverError = errors.error[0];
    },
    setOpsgenieAsDefault() {
      this.options = this.options.map(el => {
        if (el.value !== 'opsgenie') {
          return { ...el, disabled: true };
        }
        return { ...el, disabled: false };
      });
      this.selectedEndpoint = this.options.find(({ value }) => value === 'opsgenie').value;
      if (this.targetUrl === null) {
        this.targetUrl = this.selectedService.targetUrl;
      }
    },
    removeOpsGenieOption() {
      this.options = this.options.map(el => {
        if (el.value !== 'opsgenie') {
          return { ...el, disabled: false };
        }
        return { ...el, disabled: true };
      });
    },
    resetFormValues() {
      this.testAlert.json = null;
      this.targetUrl = this.selectedService.targetUrl;
      this.active = this.selectedService.activated;
    },
    dismissFeedback() {
      this.serverError = null;
      this.feedback = { ...this.feedback, feedbackMessage: null };
      this.isFeedbackDismissed = false;
    },
    resetKey(key) {
      const fn = key === 'prometheus' ? this.resetPrometheusKey() : this.resetGenericKey();

      return fn
        .then(({ data: { token } }) => {
          this.authKey = token;
          this.setFeedback({ feedbackMessage: this.$options.i18n.authKeyRest, variant: 'success' });
        })
        .catch(() => {
          this.setFeedback({ feedbackMessage: this.$options.i18n.errorKeyMsg, variant: 'danger' });
        });
    },
    resetGenericKey() {
      this.dismissFeedback();
      return service.updateGenericKey({
        endpoint: this.generic.formPath,
        params: { service: { token: '' } },
      });
    },
    resetPrometheusKey() {
      return service.updatePrometheusKey({ endpoint: this.prometheus.prometheusResetKeyPath });
    },
    toggleService(value) {
      this.canSaveForm = true;
      this.active = value;
    },
    toggle(value) {
      return this.isPrometheus ? this.togglePrometheusActive(value) : this.toggleActivated(value);
    },
    toggleActivated(value) {
      this.loading = true;
      return service
        .updateGenericActive({
          endpoint: this[this.selectedEndpoint].formPath,
          params: this.isOpsgenie
            ? { service: { opsgenie_mvc_target_url: this.targetUrl, opsgenie_mvc_enabled: value } }
            : { service: { active: value } },
        })
        .then(() => this.notifySuccessAndReload())
        .catch(({ response: { data: { errors } = {} } = {} }) => {
          this.createUserErrorMessage(errors);
          this.setFeedback({
            feedbackMessage: `${this.$options.i18n.errorMsg}.`,
            variant: 'danger',
          });
        })
        .finally(() => {
          this.loading = false;
          this.canSaveForm = false;
        });
    },
    reload() {
      if (!doesHashExistInUrl(sectionHash)) {
        window.location.hash = sectionHash;
      }
      window.location.reload();
    },
    togglePrometheusActive(value) {
      this.loading = true;
      return service
        .updatePrometheusActive({
          endpoint: this.prometheus.prometheusFormPath,
          params: {
            token: this.$options.csrf.token,
            config: value,
            url: this.targetUrl,
            redirect: window.location,
          },
        })
        .then(() => this.notifySuccessAndReload())
        .catch(({ response: { data: { errors } = {} } = {} }) => {
          this.createUserErrorMessage(errors);
          this.setFeedback({
            feedbackMessage: `${this.$options.i18n.errorMsg}.`,
            variant: 'danger',
          });
        })
        .finally(() => {
          this.loading = false;
          this.canSaveForm = false;
        });
    },
    notifySuccessAndReload() {
      createFlash({ message: this.$options.i18n.changesSaved, type: FLASH_TYPES.NOTICE });
      setTimeout(() => this.reload(), 1000);
    },
    setFeedback({ feedbackMessage, variant }) {
      this.feedback = { feedbackMessage, variant };
    },
    validateJson() {
      this.testAlert.error = null;
      try {
        JSON.parse(this.testAlert.json);
      } catch (e) {
        this.testAlert.error = JSON.stringify(e.message);
      }
    },
    validateTestAlert() {
      this.loading = true;
      this.dismissFeedback();
      this.validateJson();
      return service
        .updateTestAlert({
          endpoint: this.selectedService.url,
          data: this.testAlert.json,
          authKey: this.selectedService.authKey,
        })
        .then(() => {
          this.setFeedback({
            feedbackMessage: this.$options.i18n.testAlertSuccess,
            variant: 'success',
          });
        })
        .catch(() => {
          this.setFeedback({
            feedbackMessage: this.$options.i18n.testAlertFailed,
            variant: 'danger',
          });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    onSubmit() {
      this.dismissFeedback();
      this.toggle(this.active);
    },
    onReset() {
      this.testAlert.json = null;
      this.dismissFeedback();
      this.targetUrl = this.selectedService.targetUrl;

      if (this.canSaveForm) {
        this.canSaveForm = false;
        this.active = this.selectedService.activated;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="showFeedbackMsg" :variant="feedback.variant" @dismiss="dismissFeedback">
      {{ feedback.feedbackMessage }}
      <br />
      <i v-if="serverError">{{ __('Error message:') }} {{ serverError }}</i>
      <gl-button
        v-if="showAlertSave"
        variant="danger"
        category="primary"
        class="gl-display-block gl-mt-3"
        @click="toggle(active)"
      >
        {{ __('Save anyway') }}
      </gl-button>
    </gl-alert>

    <integrations-list :integrations="integrations" />

    <gl-form @submit.prevent="onSubmit" @reset.prevent="onReset">
      <h5 class="gl-font-lg">{{ $options.i18n.integrationsLabel }}</h5>

      <gl-form-group label-for="integrations" label-class="gl-font-weight-bold">
        <div data-testid="alert-settings-description" class="gl-mt-5">
          <p v-for="section in sections" :key="section.text">
            <gl-sprintf :message="section.text">
              <template #link="{ content }">
                <gl-link :href="section.url" target="_blank">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </p>
        </div>
        <gl-form-select
          v-model="selectedEndpoint"
          :options="options"
          data-testid="alert-settings-select"
          @change="resetFormValues"
        />
        <span class="gl-text-gray-200">
          <gl-sprintf :message="$options.i18n.integrationsInfo">
            <template #link="{ content }">
              <gl-link
                class="gl-display-inline-block"
                href="https://gitlab.com/groups/gitlab-org/-/epics/3362"
                target="_blank"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </span>
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.activeLabel"
        label-for="activated"
        label-class="gl-font-weight-bold"
      >
        <toggle-button
          id="activated"
          :disabled-input="loading"
          :is-loading="loading"
          :value="active"
          @change="toggleService"
        />
      </gl-form-group>
      <gl-form-group
        v-if="isOpsgenie || isPrometheus"
        :label="$options.i18n.apiBaseUrlLabel"
        label-for="api-url"
        label-class="gl-font-weight-bold"
      >
        <gl-form-input
          id="api-url"
          v-model="targetUrl"
          type="url"
          :placeholder="baseUrlPlaceholder"
          :disabled="!active"
        />
        <span class="gl-text-gray-200">
          {{ $options.i18n.apiBaseUrlHelpText }}
        </span>
      </gl-form-group>
      <template v-if="!isOpsgenie">
        <gl-form-group
          :label="$options.i18n.urlLabel"
          label-for="url"
          label-class="gl-font-weight-bold"
        >
          <gl-form-input-group id="url" readonly :value="selectedService.url">
            <template #append>
              <clipboard-button
                :text="selectedService.url"
                :title="$options.i18n.copyToClipboard"
                class="gl-m-0!"
              />
            </template>
          </gl-form-input-group>
          <span class="gl-text-gray-200">
            {{ prometheusInfo }}
          </span>
        </gl-form-group>
        <gl-form-group
          :label="$options.i18n.authKeyLabel"
          label-for="authorization-key"
          label-class="gl-font-weight-bold"
        >
          <gl-form-input-group id="authorization-key" class="gl-mb-2" readonly :value="authKey">
            <template #append>
              <clipboard-button
                :text="authKey"
                :title="$options.i18n.copyToClipboard"
                class="gl-m-0!"
              />
            </template>
          </gl-form-input-group>
          <gl-button v-gl-modal.authKeyModal :disabled="!active" class="gl-mt-3">{{
            $options.i18n.resetKey
          }}</gl-button>
          <gl-modal
            modal-id="authKeyModal"
            :title="$options.i18n.resetKey"
            :ok-title="$options.i18n.resetKey"
            ok-variant="danger"
            @ok="selectedService.resetKey"
          >
            {{ $options.i18n.restKeyInfo }}
          </gl-modal>
        </gl-form-group>
        <gl-form-group
          :label="$options.i18n.alertJson"
          label-for="alert-json"
          label-class="gl-font-weight-bold"
          :invalid-feedback="testAlert.error"
        >
          <gl-form-textarea
            id="alert-json"
            v-model.trim="testAlert.json"
            :disabled="!active"
            :state="jsonIsValid"
            :placeholder="$options.i18n.alertJsonPlaceholder"
            rows="6"
            max-rows="10"
          />
        </gl-form-group>
        <gl-button :disabled="!canTestAlert" @click="validateTestAlert">{{
          $options.i18n.testAlertInfo
        }}</gl-button>
      </template>
      <div class="footer-block row-content-block gl-display-flex gl-justify-content-space-between">
        <gl-button
          variant="success"
          category="primary"
          :disabled="!canSaveConfig"
          @click="onSubmit"
        >
          {{ __('Save changes') }}
        </gl-button>
        <gl-button category="primary" :disabled="!canSaveConfig" @click="onReset">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </gl-form>
  </div>
</template>
