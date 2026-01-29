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
