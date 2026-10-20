{{/*
Resource name. Release "mlflow" + chart "mlflow" gives just "mlflow"
(not "mlflow-mlflow"), trimmed to the 63 character DNS limit.
*/}}
{{- define "mlflow.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Labels used in the selector. Must never change after the first deploy. */}}
{{- define "mlflow.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Common labels for every resource. */}}
{{- define "mlflow.labels" -}}
{{ include "mlflow.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
demo/environment: {{ .Values.environment | quote }}
{{- end -}}
