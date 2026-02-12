# Prowler Helm Chart - Architect Memory

## Chart Structure
- Chart root: `charts/prowler/` (chart v1.3.2, appVersion 5.17.1)
- Templates organized by component: `api/`, `worker/`, `worker_beat/`, `neo4j/`, `ui/`, `tests/`
- Shared helpers in `templates/_helpers.tpl`, per-component helpers in `<component>/_helpers.tpl`
- JSON schema validation: `values.schema.json` exists and must be kept in sync
- Chart.yaml is missing `dependencies` section (postgresql, valkey) -- pre-existing issue, Chart.lock not committed

## Key Patterns
- All components use same image `prowlercloud/prowler-api` (except UI: `prowler-ui`)
- Shared `prowler.envFrom` and `prowler.env` named templates in `_helpers.tpl` (extracted in 1.3.0)
- External secrets hardcoded: `prowler-postgres-secret`, `prowler-valkey-secret` (not configurable via values)
- Neo4j env vars conditionally included: `{{- if .Values.neo4j.enabled }}`
- Pod Security Standards enforced: `pod-security.kubernetes.io/enforce: restricted`
- Config checksum annotation triggers pod restarts on configmap changes
- Duplicate `app.kubernetes.io/name` labels in pod templates (pre-existing; first from `prowler.labels`, second overrides per-component)

## Scan Recovery Architecture
- Two modes: init container (`scanRecovery.enabled`) and CronJob (`scanRecoveryCronJob.enabled`)
- Both share one ConfigMap (`configmap-scan-recovery.yaml`) with Python script
- Init container runs before worker starts; CronJob runs on schedule (disabled by default)
- ConfigMap guard: `{{- if or .Values.worker.scanRecovery.enabled .Values.worker.scanRecoveryCronJob.enabled }}`
- Worker deployment volume/checksum: only added when `scanRecovery.enabled` (init container case)

## Topology Spread
- `api`, `worker`, `ui`: use `defaultTopologySpread: true` with `if/else if` pattern
- `worker_beat`: uses `with` pattern, no defaultTopologySpread (singleton, intentional)

## Values Conventions
- Components: `ui`, `api`, `worker`, `worker_beat` (underscore, not camelCase), `neo4j`
- Feature toggles: `<component>.<feature>.enabled: true/false`
- Resources always specified with requests+limits

## Known Fixed Bugs (1.3.x)
- All three `_helpers.tpl` serviceAccount functions were referencing `.Values.ui.serviceAccount.name` -- fixed
- Worker deployment had dangling volume when only CronJob enabled -- fixed

## Detailed Notes
- See `scan-recovery-review.md` for scan recovery architecture analysis
