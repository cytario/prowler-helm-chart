# Prowler Helm Chart Guardian - Agent Memory

## Chart Structure
- Chart path: `charts/prowler/`
- Chart version: 1.3.5, appVersion: 5.17.1
- Components: api, ui, worker, worker_beat, neo4j (DozerDB)
- Shared env helpers: `prowler.env` and `prowler.envFrom` in `templates/_helpers.tpl` (refactored from duplicated blocks in 1.3.0)
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
- **All 4 HPAs have broken scaleTargetRef** -- name missing component suffix, silently target non-existent Deployment
- **Worker-beat uses RollingUpdate** (should be Recreate for singleton), and HPA allows scaling to 10 replicas
- No extraEnv/extraEnvFrom support on any component
- No image digest support on any component
- Test pod uses unpinned busybox:latest with no security context

## v1.3.5 Change Request Review
- See [guardian-review.md](../docs/guardian-review.md) for full analysis of 21 change requests
- All 21 items verified as real issues
- Items #2 and #3 downgraded from P0 to P1
- Items #11 (SA automount) and #12 (network policies) are breaking changes
- Item #10 (key generator Job) -- prefer eliminating Job in favor of Helm template-based key generation
- 5 additional issues identified not in the original change requests

## Topology Spread (added 1.3.2)
- API, UI, Worker have `defaultTopologySpread: true` with soft ScheduleAnyway constraint on hostname
- Worker_beat has only `topologySpreadConstraints: []` (single replica, no default spread)
- Custom topologySpreadConstraints override takes precedence over defaultTopologySpread
- Neo4j has no topology spread (single replica)

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
- Now covers: all top-level sections including neo4j, worker.scanRecovery, worker.scanRecoveryCronJob, worker.terminationGracePeriodSeconds, api.rbac, api.networkPolicy, api.startupProbe
- Does NOT use `additionalProperties: false` -- accepts any key (non-strict validation)
- Schema is permissive by design to not break custom values overrides
- Must be updated when adding new values fields (extraEnv, digest, lifecycle, etc.)

## Network Policy Architecture
- All 4 policies gated by single toggle: `api.networkPolicy.enabled`
- UI and worker-beat templates have copy-paste errors referencing `api.networkPolicy.ingress/egress`
- Worker netpol egress uses `namespaceSelector: {}` for cloud APIs -- only matches in-cluster on most CNIs
- No Neo4j or CronJob network policies exist
