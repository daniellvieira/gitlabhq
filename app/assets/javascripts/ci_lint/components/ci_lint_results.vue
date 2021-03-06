<script>
import { GlAlert, GlTable } from '@gitlab/ui';
import CiLintWarnings from './ci_lint_warnings.vue';
import CiLintResultsValue from './ci_lint_results_value.vue';
import CiLintResultsParam from './ci_lint_results_param.vue';
import { __ } from '~/locale';

const thBorderColor = 'gl-border-gray-100!';

export default {
  correct: { variant: 'success', text: __('syntax is correct') },
  incorrect: { variant: 'danger', text: __('syntax is incorrect') },
  warningTitle: __('The form contains the following warning:'),
  fields: [
    {
      key: 'parameter',
      label: __('Parameter'),
      thClass: thBorderColor,
    },
    {
      key: 'value',
      label: __('Value'),
      thClass: thBorderColor,
    },
  ],
  components: {
    GlAlert,
    GlTable,
    CiLintWarnings,
    CiLintResultsValue,
    CiLintResultsParam,
  },
  props: {
    valid: {
      type: Boolean,
      required: true,
    },
    jobs: {
      type: Array,
      required: true,
    },
    errors: {
      type: Array,
      required: true,
    },
    warnings: {
      type: Array,
      required: true,
    },
    dryRun: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isWarningDismissed: false,
    };
  },
  computed: {
    status() {
      return this.valid ? this.$options.correct : this.$options.incorrect;
    },
    shouldShowTable() {
      return this.errors.length === 0;
    },
    shouldShowError() {
      return this.errors.length > 0;
    },
    shouldShowWarning() {
      return this.warnings.length > 0 && !this.isWarningDismissed;
    },
  },
};
</script>

<template>
  <div class="col-sm-12 gl-mt-5">
    <gl-alert
      class="gl-mb-5"
      :variant="status.variant"
      :title="__('Status:')"
      :dismissible="false"
      data-testid="ci-lint-status"
      >{{ status.text }}</gl-alert
    >

    <pre
      v-if="shouldShowError"
      class="gl-mb-5"
      data-testid="ci-lint-errors"
    ><div v-for="error in errors" :key="error">{{ error }}</div></pre>

    <ci-lint-warnings
      v-if="shouldShowWarning"
      :warnings="warnings"
      data-testid="ci-lint-warnings"
      @dismiss="isWarningDismissed = true"
    />

    <gl-table
      v-if="shouldShowTable"
      :items="jobs"
      :fields="$options.fields"
      bordered
      data-testid="ci-lint-table"
    >
      <template #cell(parameter)="{ item }">
        <ci-lint-results-param :stage="item.stage" :job-name="item.name" />
      </template>
      <template #cell(value)="{ item }">
        <ci-lint-results-value :item="item" :dry-run="dryRun" />
      </template>
    </gl-table>
  </div>
</template>
