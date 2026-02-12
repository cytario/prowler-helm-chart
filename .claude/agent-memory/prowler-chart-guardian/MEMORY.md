# Prowler Helm Chart Guardian - Agent Memory

## Chart Structure
- Chart path: `charts/prowler/`
- Chart version: 1.2.0, appVersion: 5.17.1
- Components: api, ui, worker, worker_beat, neo4j (DozerDB)
- All components share the same env block pattern (PostgreSQL + Valkey + optional Neo4j secrets)
- Env blocks are duplicated across api/worker/worker_beat deployments -- no shared helper template exists yet
- ConfigMap `prowler-api` is shared across all components via `envFrom`
- External secrets: `prowler-postgres-secret` (7 keys including admin), `prowler-valkey-secret` (4 keys)
- Django config keys auto-generated via `djangoConfigKeys.create: true`

## Security Posture
- All pods enforce: runAsNonRoot, runAsUser: 1000, seccompProfile: RuntimeDefault, capabilities drop ALL
- `allowPrivilegeEscalation: false` set on all containers
- `readOnlyRootFilesystem: false` -- required by all components (Django/Next.js/Neo4j write needs)
- Pod labels include `pod-security.kubernetes.io/enforce: restricted`
- ServiceAccount automount is `true` by default on all components (potential improvement area)
- Network policies exist but are gated behind `api.networkPolicy.enabled: false` (disabled by default)

## Known Patterns
- Secret names are hardcoded (not configurable via values) -- `prowler-postgres-secret`, `prowler-valkey-secret`
- Worker default replicas: 2 (important for race condition analysis in scan recovery)
- Broker visibility timeout: 86400s (24h) via `DJANGO_BROKER_VISIBILITY_TIMEOUT`
- Celery uses Valkey (Redis-compatible) as broker
- `DJANGO_SETTINGS_MODULE: config.django.production` is the standard settings path

## Scan Recovery Analysis (2026-02 review)
- See [scan-recovery-review.md](scan-recovery-review.md) for detailed findings
- Key issues: multi-replica race condition, Valkey-unreachable false positive, missing security context on init container
- CronJob approach is safer than init container for multi-replica deployments
- Upstream `acks_late` is the correct long-term fix but requires scan task idempotency
