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
Create the name of the scan recovery CronJob service account to use.
Falls back to the worker service account for backward compatibility.
*/}}
{{- define "prowler.scanRecovery.serviceAccountName" -}}
{{- if .Values.worker.scanRecoveryCronJob.serviceAccount.create }}
{{- default (printf "%s-%s" (include "prowler.fullname" .) "scan-recovery") .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- else if .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- else }}
{{- include "prowler.worker.serviceAccountName" . }}
{{- end }}
{{- end }}

{{/*
Shared storage volume definition for scan outputs.
Renders the volume spec for either emptyDir or persistentVolumeClaim.
Used by both API and Worker deployments.
Usage: {{- include "prowler.sharedStorage.volume" . | nindent 8 }}
*/}}
{{- define "prowler.sharedStorage.volume" -}}
- name: shared-storage
  {{- if eq .Values.sharedStorage.type "emptyDir" }}
  emptyDir:
    {{- if .Values.sharedStorage.emptyDir.medium }}
    medium: {{ .Values.sharedStorage.emptyDir.medium }}
    {{- end }}
    {{- if .Values.sharedStorage.emptyDir.sizeLimit }}
    sizeLimit: {{ .Values.sharedStorage.emptyDir.sizeLimit }}
    {{- end }}
  {{- else if eq .Values.sharedStorage.type "persistentVolumeClaim" }}
  persistentVolumeClaim:
    claimName: {{ if .Values.sharedStorage.persistentVolumeClaim.create }}{{ include "prowler.fullname" . }}-shared-storage{{ else }}{{ .Values.sharedStorage.persistentVolumeClaim.existingClaim }}{{ end }}
  {{- end }}
{{- end }}

{{/*
Default topology spread constraints for multi-replica deployments.
Spreads pods across nodes to improve availability.
Usage: {{- include "prowler.topologySpreadConstraints" (dict "component" "api" "context" .) | nindent 6 }}
*/}}
{{- define "prowler.topologySpreadConstraints" -}}
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: {{ include "prowler.fullname" .context }}-{{ .component }}
{{- end }}

{{/*
Render a container image reference, preferring digest over tag.
Usage: {{ include "prowler.image" (dict "imageConfig" .Values.api.image "defaultTag" .Chart.AppVersion) }}
*/}}
{{- define "prowler.image" -}}
{{- if .imageConfig.digest -}}
{{ .imageConfig.repository }}@{{ .imageConfig.digest }}
{{- else -}}
{{ .imageConfig.repository }}:{{ .imageConfig.tag | default .defaultTag }}
{{- end -}}
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
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_HOST
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_PORT
- name: POSTGRES_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_ADMIN_USER
- name: POSTGRES_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_ADMIN_PASSWORD
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_PASSWORD
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_DB
# Valkey connection from external secret
- name: VALKEY_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.valkey.secretName }}
      key: VALKEY_HOST
- name: VALKEY_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.valkey.secretName }}
      key: VALKEY_PORT
- name: VALKEY_DB
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.valkey.secretName }}
      key: VALKEY_DB
- name: VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.valkey.secretName }}
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
