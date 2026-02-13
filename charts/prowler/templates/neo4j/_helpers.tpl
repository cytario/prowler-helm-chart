{{/*
Neo4j fullname
*/}}
{{- define "prowler.neo4j.fullname" -}}
{{ include "prowler.fullname" . }}-neo4j
{{- end }}

{{/*
Neo4j labels
*/}}
{{- define "prowler.neo4j.labels" -}}
{{ include "prowler.labels" . }}
app.kubernetes.io/component: neo4j
{{- end }}

{{/*
Neo4j selector labels
*/}}
{{- define "prowler.neo4j.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prowler.neo4j.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the Neo4j service account to use
*/}}
{{- define "prowler.neo4j.serviceAccountName" -}}
{{- if .Values.neo4j.serviceAccount.create }}
{{- default (include "prowler.neo4j.fullname" .) .Values.neo4j.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.neo4j.serviceAccount.name }}
{{- end }}
{{- end }}
