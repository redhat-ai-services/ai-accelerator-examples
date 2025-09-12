{{/*
Common labels
*/}}
{{- define "3scale.labels" -}}
rhoai-example: maas
rhoai-example-component: 3scale
{{- end }}

{{/*
3scale System Name
*/}}
{{- define "3scale.systemName" -}}
{{- default . | replace "+" "" | replace "_" "" | replace "." "" | replace "-" "" | trunc 63 | lower | trimSuffix "-" }}
{{- end }}
