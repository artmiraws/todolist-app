{{/*
Expand the name of the chart.
*/}}
{{- define "todolist.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "todolist.fullname" -}}
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
Chart label.
*/}}
{{- define "todolist.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "todolist.labels" -}}
helm.sh/chart: {{ include "todolist.chart" . }}
{{ include "todolist.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "todolist.selectorLabels" -}}
app.kubernetes.io/name: {{ include "todolist.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for the application pods.
*/}}
{{- define "todolist.appSelectorLabels" -}}
{{ include "todolist.selectorLabels" . }}
app.kubernetes.io/component: app
{{- end }}

{{/*
Service account name.
*/}}
{{- define "todolist.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "todolist.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Kubernetes Secret that holds the application credentials.
*/}}
{{- define "todolist.secretName" -}}
{{- default (include "todolist.fullname" .) .Values.externalSecret.targetSecretName }}
{{- end }}

{{/*
Image reference, preferring an immutable digest.
*/}}
{{- define "todolist.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
Name of the in-cluster PostgreSQL service (local development only).
*/}}
{{- define "todolist.postgresServiceName" -}}
{{- printf "%s-postgres" (include "todolist.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the in-cluster PostgreSQL PVC (local development only).
*/}}
{{- define "todolist.postgresClaimName" -}}
{{- printf "%s-postgres-data" (include "todolist.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels for the in-cluster PostgreSQL.
*/}}
{{- define "todolist.postgresSelectorLabels" -}}
{{ include "todolist.selectorLabels" . }}
app.kubernetes.io/component: postgres
{{- end }}
