{{/*
Expand the name of the chart.
*/}}
{{- define "cms-upload.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cms-upload.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cms-upload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cms-upload.labels" -}}
helm.sh/chart: {{ include "cms-upload.chart" . }}
{{ include "cms-upload.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
rhoai-example: maas
rhoai-example-component: 3scale-cms-upload
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cms-upload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cms-upload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cms-upload.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cms-upload.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
ArgoCD Syncwave Hook Pre3
*/}}
{{- define "cms-upload-hook-pre.argocd-syncwave" -}}
{{- if .Values.hook.pre.argocd }}
{{- if and (.Values.hook.pre.argocd.syncwave) (.Values.hook.pre.argocd.enabled) -}}
argocd.argoproj.io/sync-wave: "{{ .Values.hook.pre.argocd.syncwave }}"
argocd.argoproj.io/hook: PreSync
{{- else }}
{{- "{}" }}
{{- end }}
{{- else }}
{{- "{}" }}
{{- end }}
{{- end }}

{{/*
ArgoCD Syncwave Hook Post
*/}}
{{- define "cms-upload-hook-post.argocd-syncwave" -}}
{{- if .Values.hook.post.argocd }}
{{- if and (.Values.hook.post.argocd.syncwave) (.Values.hook.post.argocd.enabled) -}}
argocd.argoproj.io/sync-wave: "{{ .Values.hook.post.argocd.syncwave }}"
{{- else }}
{{- "{}" }}
{{- end }}
{{- else }}
{{- "{}" }}
{{- end }}
{{- end }}

{{/*
ArgoCD Syncwave
*/}}
{{- define "cms-upload.argocd-syncwave" -}}
{{- if .Values.argocd }}
{{- if and (.Values.argocd.syncwave) (.Values.argocd.enabled) -}}
argocd.argoproj.io/sync-wave: "{{ .Values.argocd.syncwave }}"
{{- else }}
{{- "{}" }}
{{- end }}
{{- else }}
{{- "{}" }}
{{- end }}
{{- end }}