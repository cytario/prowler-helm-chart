# Prowler Helm Chart Guardian - Agent Memory

## Chart Structure
- Chart path: `charts/prowler/`
- Chart version: 2.0.2, appVersion: 5.17.1
- Components: api, ui, worker, worker_beat, neo4j (DozerDB)
- Shared env helpers: `prowler.env` and `prowler.envFrom` in `templates/_helpers.tpl` (refactored from duplicated blocks in 1.3.0)
- DRY helpers (added 2.0.2): `prowler.sharedStorage.volume` (API/Worker volume def), `prowler.topologySpreadConstraints` (multi-component spread)
- ConfigMap `prowler-api` is shared across all components via `envFrom`
- External secrets: `prowler-postgres-secret` (7 keys including admin), `prowler-valkey-secret` (4 keys)
- Django config keys auto-generated via `djangoConfigKeys.create: true` (via pre-install/pre-upgrade Job using unpinned bitnami/kubectl:latest)
- Chart.yaml is MISSING `dependencies:` block (Chart.lock exists) -- pre-existing issue, `helm lint` fails

## Security Posture
- All pods enforce: runAsNonRoot, runAsUser: 1000, seccompProfile: RuntimeDefault, capabilities drop ALL
- `allowPrivilegeEscalation: false` set on all containers including init containers
- `readOnlyRootFilesystem: false` -- required by all components (Django/Next.js/Neo4j write needs)
- Pod labels include `pod-security.kubernetes.io/enforce: restricted`
- ServiceAccount automount is `true` by default on all components (potential improvement area)
- Network policies exist but are gated behind `api.networkPolicy.enabled: false` (disabled by default)
- Init container and CronJob now have resource limits (fixed in 1.3.2 review)
- CronJob has `activeDeadlineSeconds: 300` to prevent stuck jobs
- Neo4j has NO ServiceAccount -- uses namespace default SA

## Known Patterns & Issues
- Secret names are hardcoded (not configurable via values) -- `prowler-postgres-secret`, `prowler-valkey-secret`
- Worker default replicas: 2 (important for race condition analysis in scan recovery)
- Broker visibility timeout: 86400s (24h) via `DJANGO_BROKER_VISIBILITY_TIMEOUT`
- Celery uses Valkey (Redis-compatible) as broker
- `DJANGO_SETTINGS_MODULE: config.django.production` is the standard settings path
- **Duplicate label issue**: All deployments render `app.kubernetes.io/name` twice (from prowler.labels + explicit override). Pre-existing, not a regression.
- POSTGRES_ADMIN credentials are injected to all containers via shared `prowler.env` helper even when not needed (design debt)
- **All 3 HPAs have broken scaleTargetRef** -- name missing component suffix, silently target non-existent Deployment (API, UI, Worker)
- api.terminationGracePeriodSeconds: 30 (added 2.0.2 Phase 6) -- allows gunicorn to finish in-flight requests
- Worker-beat HPA REMOVED in Phase 2 (nonsensical for singleton)
- Worker-beat enforces singleton via fail guard in deployment template (added Phase 2)
- Worker-beat uses Recreate strategy (correct for singleton)
- extraEnv/extraEnvFrom support added to API, Worker, UI in 2.0.0
- image.digest support added to all components in 2.0.0
- Test pod uses unpinned busybox:latest with no security context

## Worker Concurrency Control (added 2.0.0 Phase 2)
- `worker.concurrency` accepts integer (1-32) or null via schema `type: ["integer", "null"]`
- When set to integer: bypasses entrypoint, invokes celery directly with --concurrency N
- When set to null: uses default entrypoint (/home/prowler/docker-entrypoint.sh worker)
- Template logic: `{{- if .Values.worker.concurrency }}` (Helm treats null as falsy)

## Shared Storage Volume (DRY helper added 2.0.2 Phase 6)
- Helper template: `prowler.sharedStorage.volume` eliminates duplicate volume definitions in API and Worker
- Renders either emptyDir or persistentVolumeClaim based on `sharedStorage.type`
- Handles all emptyDir options: medium, sizeLimit
- Handles PVC options: create (generates `prowler-shared-storage` name) or existingClaim
- Usage: `{{- include "prowler.sharedStorage.volume" . | nindent 8 }}`
- Mounted at `DJANGO_TMP_OUTPUT_DIRECTORY` (/tmp/prowler_api_output by default) in API and Worker

## v1.3.5 Change Request Review
- See [guardian-review.md](../docs/guardian-review.md) for full analysis of 21 change requests
- All 21 items verified as real issues
- Items #2 and #3 downgraded from P0 to P1
- Items #11 (SA automount) and #12 (network policies) are breaking changes
- Item #10 (key generator Job) -- prefer eliminating Job in favor of Helm template-based key generation
- 5 additional issues identified not in the original change requests

## Topology Spread (added 1.3.2, refactored 2.0.2)
- API, UI, Worker have `defaultTopologySpread: true` with soft ScheduleAnyway constraint on hostname
- Worker_beat has only `topologySpreadConstraints: []` (single replica, no default spread)
- Custom topologySpreadConstraints override takes precedence over defaultTopologySpread
- Neo4j has no topology spread (single replica)
- Helper template `prowler.topologySpreadConstraints` DRYs the default spread pattern (added 2.0.2)
- Usage: `{{- include "prowler.topologySpreadConstraints" (dict "component" "api" "context" .) | nindent 6 }}`

## Scan Recovery (added 1.3.0, fixed 1.3.1/1.3.2)
- See [scan-recovery-review.md](scan-recovery-review.md) for detailed findings
- Init container mode: checks for active workers via Celery ping before recovering
- CronJob mode: pure time-threshold based (no worker check)
- Both share ConfigMap `prowler-scan-recovery` with Python script
- Volume gating: init container volume only added to worker deployment when `scanRecovery.enabled`
- ConfigMap gating: created when either init or CronJob is enabled
- Checksum annotation: only on worker deployment when init container is enabled
- PYTHONPATH fix was needed for import resolution (1.3.1 and 1.3.2 hotfixes)
- CronJob inherits worker ServiceAccount with cloud IAM privileges (should have dedicated SA)

## values.schema.json
- Added in the topology/affinity PR
- Now covers: all top-level sections including neo4j, worker.scanRecovery, worker.scanRecoveryCronJob, worker.terminationGracePeriodSeconds, api.rbac, api.networkPolicy, api.startupProbe, api.terminationGracePeriodSeconds
- Includes networkPolicy.postgresPort and networkPolicy.valkeyPort for API, Worker, and Worker_beat (added 2.0.2)
- Does NOT use `additionalProperties: false` -- accepts any key (non-strict validation)
- Schema is permissive by design to not break custom values overrides
- Must be updated when adding new values fields

## Network Policy Architecture (Phase 5 improvements in 2.0.2)
- Each component has its own networkPolicy.enabled toggle (api, ui, worker, worker_beat)
- Configurable ports: api.networkPolicy.postgresPort/valkeyPort, worker.networkPolicy.postgresPort/valkeyPort, worker_beat.networkPolicy.postgresPort/valkeyPort (defaults: 5432/6379)
- Neo4j egress rules conditionally rendered: wrapped in `{{- if .Values.neo4j.enabled }}` for API and Worker netpols
- Worker_beat netpol does NOT have Neo4j egress (doesn't execute scans, only schedules)
- Worker netpol egress uses `namespaceSelector: {}` for cloud APIs -- only matches in-cluster on most CNIs
- Neo4j and CronJob network policies exist (added in earlier phases)
