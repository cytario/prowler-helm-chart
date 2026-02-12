{{/*
Expand the name of the chart.
*/}}
{{- define "prowler.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "prowler.fullname" -}}
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
{{- define "prowler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "prowler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prowler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "prowler.labels" -}}
helm.sh/chart: {{ include "prowler.chart" . }}
{{ include "prowler.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Component labels - adds component label to selector labels
Usage: {{ include "prowler.componentLabels" (dict "component" "api" "context" .) }}
*/}}
{{- define "prowler.componentLabels" -}}
{{ include "prowler.labels" .context }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Shared envFrom block for API, Worker, and Worker Beat containers.
Includes the API configmap, Django config keys secret, and any additional API secrets.
Usage: {{- include "prowler.envFrom" . | nindent 12 }}
*/}}
{{- define "prowler.envFrom" -}}
- configMapRef:
    name: {{ include "prowler.fullname" . }}-api
{{- if .Values.api.djangoConfigKeys.create }}
- secretRef:
    name: {{ include "prowler.fullname" . }}-api-django-config-keys
{{- end }}
{{- with .Values.api.secrets }}
{{- range $index, $secret := . }}
- secretRef:
    name: {{ $secret }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Shared env block for API, Worker, and Worker Beat containers.
Includes PostgreSQL, Valkey, and optional Neo4j connection environment variables.
Usage: {{- include "prowler.env" . | nindent 12 }}
*/}}
{{- define "prowler.env" -}}
# PostgreSQL connection from external secret
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_HOST
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_PORT
- name: POSTGRES_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_ADMIN_USER
- name: POSTGRES_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_ADMIN_PASSWORD
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_PASSWORD
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret
      key: POSTGRES_DB
# Valkey connection from external secret
- name: VALKEY_HOST
  valueFrom:
    secretKeyRef:
      name: prowler-valkey-secret
      key: VALKEY_HOST
- name: VALKEY_PORT
  valueFrom:
    secretKeyRef:
      name: prowler-valkey-secret
      key: VALKEY_PORT
- name: VALKEY_DB
  valueFrom:
    secretKeyRef:
      name: prowler-valkey-secret
      key: VALKEY_DB
- name: VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: prowler-valkey-secret
      key: VALKEY_PASSWORD
      optional: true
{{- if .Values.neo4j.enabled }}
# Neo4j connection for Attack Paths feature
- name: NEO4J_HOST
  value: {{ include "prowler.neo4j.fullname" . | quote }}
- name: NEO4J_PORT
  value: {{ .Values.neo4j.service.port | quote }}
- name: NEO4J_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "prowler.neo4j.fullname" . }}
      key: username
- name: NEO4J_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "prowler.neo4j.fullname" . }}
      key: password
{{- end }}
{{- end }}
