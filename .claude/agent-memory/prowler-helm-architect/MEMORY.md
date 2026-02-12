# Prowler Helm Chart - Architect Memory

## Chart Structure
- Chart root: `charts/prowler/` (chart v1.2.0, appVersion 5.17.1)
- Templates organized by component: `api/`, `worker/`, `worker_beat/`, `neo4j/`, `ui/`, `tests/`
- Shared helpers in `templates/_helpers.tpl`, per-component helpers in `<component>/_helpers.tpl`
- JSON schema validation: `values.schema.json` exists and must be kept in sync

## Key Patterns
- All components use same image `prowlercloud/prowler-api` (except UI: `prowler-ui`)
- `envFrom` + `env` blocks are copy-pasted across api, worker, worker_beat (75+ lines each) - DRY opportunity via named templates
- External secrets hardcoded: `prowler-postgres-secret`, `prowler-valkey-secret` (not configurable)
- Neo4j env vars conditionally included: `{{- if .Values.neo4j.enabled }}`
- Pod Security Standards enforced: `pod-security.kubernetes.io/enforce: restricted`
- Config checksum annotation triggers pod restarts on configmap changes

## Known Bugs
- `worker/_helpers.tpl` line 6: `prowler.worker.serviceAccountName` references `.Values.ui.serviceAccount.name` instead of `.Values.worker.serviceAccount.name`
- Same bug in `worker_beat/_helpers.tpl` line 6

## Values Conventions
- Components: `ui`, `api`, `worker`, `worker_beat` (underscore, not camelCase), `neo4j`
- Shared config: `api.djangoConfig` (ConfigMap), `api.djangoConfigKeys` (Secret), `api.secrets` (extra secrets)
- Feature toggles: `<component>.<feature>.enabled: true/false`
- Resources always specified with requests+limits

## Template Conventions
- Labels: `prowler.labels` (common) + `app.kubernetes.io/name: {{ include "prowler.fullname" . }}-<component>`
- Naming: `{{ include "prowler.fullname" . }}-<component>`
- Tests: `templates/tests/` with `helm.sh/hook: test` annotations
- No Helm hooks currently used for deployment lifecycle

## Detailed Notes
- See `scan-recovery-review.md` for scan recovery architecture analysis
