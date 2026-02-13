# Prowler Helm Chart - Architect Memory

## Chart Structure
- Chart root: `charts/prowler/` (chart v1.3.5, appVersion 5.17.1)
- Templates organized by component: `api/`, `worker/`, `worker_beat/`, `neo4j/`, `ui/`, `tests/`
- Shared helpers in `templates/_helpers.tpl`, per-component helpers in `<component>/_helpers.tpl`
- JSON schema validation: `values.schema.json` exists and must be kept in sync with every values.yaml change
- Chart.yaml is missing `dependencies` section (postgresql, valkey) -- pre-existing issue, Chart.lock not committed

## Key Patterns
- All components use same image `prowlercloud/prowler-api` (except UI: `prowler-ui`, Neo4j: `graphstack/dozerdb`)
- Shared `prowler.envFrom` and `prowler.env` named templates in `_helpers.tpl` (extracted in 1.3.0)
- External secrets configurable via `externalSecrets.postgres.secretName` / `externalSecrets.valkey.secretName` (defaults: `prowler-postgres-secret`, `prowler-valkey-secret`)
- All 4 components support `extraEnv: []` and `extraEnvFrom: []` for per-component env injection
- Neo4j env vars conditionally included: `{{- if .Values.neo4j.enabled }}`
- Pod Security Standards enforced: `pod-security.kubernetes.io/enforce: restricted`
- Config checksum annotation triggers pod restarts on configmap changes
- Duplicate `app.kubernetes.io/name` labels in pod templates (first from `prowler.labels`, second overrides per-component)
- `prowler.image` helper in `_helpers.tpl` renders image ref: digest takes precedence over tag
- All 5 component image blocks have `digest: ""` field for immutable image references
- NetworkPolicies are per-component toggles: `<component>.networkPolicy.enabled`
- Neo4j NetworkPolicy allows ingress from API+Worker on Bolt(7687)+HTTP(7474) only
- Worker netpol egress: 443/6443 rules have no `to:` selector (allows external cloud APIs)
- SA automount: `api`/`worker` true; `ui`/`worker_beat`/`neo4j` false

## Known Bugs (as of 1.3.5)
- All 4 HPA templates have wrong `scaleTargetRef.name` (missing component suffix)
- Worker-beat uses RollingUpdate (should be Recreate for singleton)
- Worker/worker-beat/UI templates missing startupProbe rendering
- ~~Network policies: all gated by `api.networkPolicy.enabled`, copy-paste errors in UI/worker-beat templates~~ FIXED Phase 6
- ~~Neo4j has no ServiceAccount (falls back to namespace `default`)~~ FIXED Phase 3
- ~~Key generator job uses unpinned `bitnami/kubectl:latest` with runtime `apt-get install`~~ FIXED Phase 3
- ~~Test pods use unpinned `busybox:latest` / `curlimages/curl:latest` with no securityContext~~ FIXED Phase 7

## Scan Recovery Architecture
- Two modes: init container (`scanRecovery.enabled`) and CronJob (`scanRecoveryCronJob.enabled`)
- Both share one ConfigMap (`configmap-scan-recovery.yaml`) with Python script
- Init container runs before worker starts; CronJob runs on schedule (disabled by default)
- ~~CronJob inherits worker SA with cloud IAM -- needs dedicated SA~~ FIXED Phase 3: dedicated `prowler-scan-recovery` SA
- ~~Missing optimistic concurrency on update (race condition if scan completes between query and update)~~ FIXED Phase 7

## Topology Spread
- `api`, `worker`, `ui`: use `defaultTopologySpread: true` with `if/else if` pattern
- `worker_beat`: uses `with` pattern, no defaultTopologySpread (singleton, intentional)

## Values Conventions
- Components: `ui`, `api`, `worker`, `worker_beat` (underscore, not camelCase), `neo4j`
- Feature toggles: `<component>.<feature>.enabled: true/false`
- Resources always specified with requests+limits

## Implementation Plan
- See `docs/implementation-plan.md` for v1.4.0 phased implementation (21 items across 8 phases)
- Phase 1-2: Bug fixes (HPA names, Recreate, startupProbe) -- no breaking changes
- Phase 3: Security HIGH (CronJob SA, key-gen pinning, Neo4j SA) -- DONE
- Phase 4: Extensibility (extraEnv/extraEnvFrom, configurable secret names) -- DONE
- Phase 5: Worker lifecycle (preStop, concurrency docs, beat terminationGracePeriod) -- DONE
- Phase 6: Security MEDIUM (automount, digests, netpol fixes) -- DONE
- Phase 7: Hardening/Polish (Neo4j PDB+tGPS, structured logging, test hardening, recovery concurrency guard) -- DONE
- Phase 8: Scan Recovery Hardening (remaining items)

## Detailed Notes
- See `scan-recovery-review.md` for scan recovery architecture analysis
