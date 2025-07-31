{{/*
Expand the name of the chart.
*/}}
{{- define "argocd-appgenerator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "argocd-appgenerator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "argocd-appgenerator.labels" -}}
helm.sh/chart: {{ include "argocd-appgenerator.chart" . }}
{{ include "argocd-appgenerator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "argocd-appgenerator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "argocd-appgenerator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
