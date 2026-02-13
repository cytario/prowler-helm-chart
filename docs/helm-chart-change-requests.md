# Prowler Helm Chart v1.3.5 — Requested Changes

Compiled from independent reviews by infrastructure, SRE, and security engineering.
All file paths are relative to `charts/prowler/` in the helm chart repository.

---

## Bugs

### 1. All Four HPA Templates Have Incorrect `scaleTargetRef.name`

**Priority: P0 (bug) | Flagged by: Infra, SRE**

Every HPA template references `{{ include "prowler.fullname" . }}` (e.g., `prowler`)
instead of the component-specific deployment name (e.g., `prowler-api`, `prowler-worker`).
If any operator enables autoscaling, the HPA silently targets a nonexistent Deployment
and has no effect.

| Component   | Deployment Name         | HPA scaleTargetRef (current) |
|-------------|-------------------------|------------------------------|
| api         | `<fullname>-api`        | `<fullname>` (wrong)         |
| worker      | `<fullname>-worker`     | `<fullname>` (wrong)         |
| worker_beat | `<fullname>-worker-beat`| `<fullname>` (wrong)         |
| ui          | `<fullname>-ui`         | `<fullname>` (wrong)         |

**Fix:** Append the component suffix to `scaleTargetRef.name` in each HPA template.

**Files:**
- `templates/api/hpa.yaml` line 12
- `templates/worker/hpa.yaml` line 12
- `templates/worker_beat/hpa.yaml` line 12
- `templates/ui/hpa.yaml` line 12

---

## P0 — Blocking Reliability Gaps

### 2. Worker, Worker-Beat, and UI Deployments Missing `startupProbe` Rendering

**Priority: P0 | Flagged by: Infra, SRE, Security**

The API deployment template (`templates/api/deployment.yaml` lines 66–68) and Neo4j
template both render `startupProbe` from values, but the worker, worker-beat, and UI
templates do not — neither in templates nor in `values.yaml`.

Without `startupProbe`, operators must choose between:
- No probes at all (current default — silent failures go undetected), or
- Inflated `initialDelaySeconds` on liveness probes (slow failure detection)

There is no way to separate "still starting" from "hung." Celery workers can take
30–120s to initialize (broker connection, task registration, Django init). On new
Karpenter nodes, add image pull + EFS mount time.

**Fix:** Add `startupProbe` rendering to all three templates using the same
`{{- with .Values.<component>.startupProbe }}` pattern as the API. Add
`startupProbe: {}` to `values.yaml` for each component.

**Files:**
- `templates/worker/deployment.yaml` (after readinessProbe block, ~line 106)
- `templates/worker_beat/deployment.yaml` (after readinessProbe block, ~line 69)
- `templates/ui/deployment.yaml` (after readinessProbe block, ~line 67)
- `values.yaml` — worker, worker_beat, and ui sections

### 3. Worker-Beat Has No Viable Health Check Mechanism

**Priority: P0 | Flagged by: SRE, Security, Infra**

The default probes for worker-beat are `livenessProbe: {}` and `readinessProbe: {}`.
The commonly suggested `celery inspect ping` **does not verify the beat scheduler** —
it pings Celery workers via the broker. If all workers respond but beat is dead, the
probe passes. This is the exact failure mode observed in a 17-hour outage where beat
ran as a zombie.

A reliable beat probe must check something beat-specific: the beat process PID, the
`celerybeat-schedule` file age, or the beat process existence via `pgrep`.

**Fix:** Document the recommended beat probe approach in `values.yaml` comments.
Provide a working example using `pgrep -f "celery.*beat"` or a PID-file check.
If Prowler's beat writes a pidfile or schedule file, document the path.

Example:
```yaml
worker_beat:
  livenessProbe:
    exec:
      command: ["/bin/sh", "-c", "pgrep -f 'celery.*beat' > /dev/null"]
    initialDelaySeconds: 120
    periodSeconds: 60
    failureThreshold: 3
```

**Files:**
- `values.yaml` — worker_beat section (~lines 635–636)

---

## P1 — Important Improvements

### 4. No `extraEnv` / `extraEnvFrom` Support on Any Component

**Priority: P1 | Flagged by: Infra**

None of the four deployment templates support injecting arbitrary environment variables.
The only extension points are `api.djangoConfig` (shared ConfigMap across all backend
pods) and `api.secrets` (list of secretRef names for `envFrom`).

There is no mechanism to:
- Set **per-component** env vars (e.g., `CELERY_WORKER_CONCURRENCY` only on workers)
- Inject env vars from pod metadata (`fieldRef`), specific secret keys (`secretKeyRef`),
  or computed values
- Add `envFrom` sources per-component

This is a standard Helm pattern (used by Bitnami, ingress-nginx, cert-manager).

**Fix:** Add `extraEnv: []` and `extraEnvFrom: []` to `values.yaml` for each
component. Render them after the existing `env`/`envFrom` blocks in each template.

**Files:**
- `templates/worker/deployment.yaml` (~lines 95–98)
- `templates/worker_beat/deployment.yaml` (~lines 58–61)
- `templates/api/deployment.yaml` (~lines 62–65)
- `templates/ui/deployment.yaml` (~lines 55–59)
- `values.yaml` — all four component sections

### 5. Worker Celery Concurrency Not Configurable

**Priority: P1 | Flagged by: Infra**

The entrypoint starts Celery with no `--concurrency` flag, so it defaults to
`multiprocessing.cpu_count()`. On Kubernetes, this reads the **node** CPU count,
not the pod's CPU limit. A pod with 2 CPU cores requested on a 16-core node
spawns 16 workers, leading to OOMKills and throttling.

**Fix (requires coordinated image + chart change):** Update `docker-entrypoint.sh`
to read an environment variable:

```bash
celery ... --concurrency "${CELERY_WORKER_CONCURRENCY:-$(nproc)}"
```

Expose it via `api.djangoConfig` in `values.yaml` or (better) via `extraEnv`
from item 4, so it can be set per-component.

**Files:**
- `docker-entrypoint.sh` in the container image (upstream Prowler repo)
- `values.yaml` — `djangoConfig` section or new `worker.celery.concurrency` value

### 6. Worker-Beat Allows Multiple Replicas / Missing `Recreate` Strategy

**Priority: P1 | Flagged by: SRE**

The worker-beat deployment uses the default `RollingUpdate` strategy. With 1 replica,
a Helm upgrade momentarily runs **two** beat pods simultaneously (old + new overlap
during rollout). Duplicate beats cause duplicate scan dispatches.

Additionally, nothing prevents setting `replicaCount: 2` or enabling the beat HPA
(`templates/worker_beat/hpa.yaml`), which would create duplicate schedulers.

The Neo4j deployment already solves this with `strategy: type: Recreate`.

**Fix:**
- Add `strategy: type: Recreate` to `templates/worker_beat/deployment.yaml`
- Add a comment in `values.yaml` that beat must be a singleton
- Consider removing `templates/worker_beat/hpa.yaml` or adding a guard that
  `maxReplicas` must be 1

**Files:**
- `templates/worker_beat/deployment.yaml` (~line 9, before `selector:`)
- `templates/worker_beat/hpa.yaml`
- `values.yaml` — worker_beat section

### 7. No `preStop` Hook or Graceful Shutdown Guidance for Workers

**Priority: P1 | Flagged by: SRE**

The worker deployment sets `terminationGracePeriodSeconds: 300` but has no
`lifecycle.preStop` hook and no documentation about what happens to in-flight scans.

Key unknowns:
- Does Prowler use `acks_late=True`? If not, tasks are lost on SIGTERM (broker
  thinks delivered, but no worker retries).
- What is the expected behavior for running scans during worker shutdown?
- How should `terminationGracePeriodSeconds` be tuned vs. expected scan duration?

**Fix:**
- Add `lifecycle` rendering to the worker deployment template, gated by
  `worker.lifecycle` values
- Document `acks_late` behavior, scan-during-shutdown handling, and tuning guidance
  in `values.yaml` comments

**Files:**
- `templates/worker/deployment.yaml`
- `values.yaml` — worker section

### 8. Scan Recovery CronJob Race Condition with Active Workers

**Priority: P1 | Flagged by: SRE**

The CronJob recovery mode (`configmap-scan-recovery.yaml` lines 98–107) marks scans
as failed purely based on a time threshold. Unlike init-container mode, it does **not**
check whether workers are actively processing those scans.

Race condition: a worker is processing a legitimately long scan, the CronJob fires and
marks it `failed` via `queryset.update(state="failed")`, and the worker continues
executing — resulting in conflicting state.

The `update()` call on line 71 has no optimistic concurrency guard (no re-filter on
`state`, no `SELECT ... FOR UPDATE`).

**Fix:**
- CronJob mode: Before marking scans failed, check `app.control.inspect().active()`
  to see if any live worker claims the scan's task. Skip scans with active tasks.
- Both modes: Add optimistic concurrency to the update:
  `queryset.filter(state="executing").update(...)` to avoid overwriting a scan whose
  state changed between query and update.
- Log affected scan IDs for operator visibility.

**Files:**
- `templates/worker/configmap-scan-recovery.yaml` (~lines 71, 78–107)

---

## Security — HIGH

### 9. CronJob Inherits Worker ServiceAccount with Cloud Scanning IAM Privileges

**Severity: HIGH | Flagged by: Security, Infra**

`templates/worker/cronjob-scan-recovery.yaml` line 28 uses:
```yaml
serviceAccountName: {{ include "prowler.worker.serviceAccountName" . }}
```

The worker ServiceAccount carries Pod Identity / IRSA annotations granting
`sts:AssumeRole` to cross-account scanning roles. The CronJob only runs a
Django ORM query against PostgreSQL — it needs zero AWS API access.

A compromised CronJob pod (running every 15 minutes) would inherit full cloud
scanning credentials. Mitigated somewhat by `activeDeadlineSeconds: 300` and
`concurrencyPolicy: Forbid`, but the privilege is unnecessary.

**Fix:** Add a dedicated CronJob ServiceAccount with `automountServiceAccountToken: false`:

```yaml
worker:
  scanRecoveryCronJob:
    serviceAccount:
      create: true
      automount: false
      annotations: {}
      name: ""
```

Create `templates/worker/serviceaccount-scan-recovery.yaml`. Fall back to worker SA
when `create: false` and `name: ""` for backward compatibility.

**Files:**
- `templates/worker/cronjob-scan-recovery.yaml` (line 28)
- `templates/_helpers.tpl` (new helper)
- `values.yaml` — `worker.scanRecoveryCronJob` section

### 10. Key Generator Job Uses Unpinned `bitnami/kubectl:latest` + Runtime `apt-get install`

**Severity: HIGH | Flagged by: Security**

`templates/api/job-generate-keys.yaml` line 33 uses `image: bitnami/kubectl:latest`.
Line 58 runs `apt-get update && apt-get install -y openssl` at runtime.

This is a supply chain risk: the job runs during every `helm install`/`upgrade` with
permissions to create secrets, pulls an unpinned image, and fetches packages from
the internet. A compromised image or MITM on the package mirror could exfiltrate
generated private keys.

**Fix:**
- Pin the image version and add a `values.yaml` field for override
- Eliminate runtime `apt-get install` (use an image that includes `openssl`, or
  generate keys without it)
- Set `readOnlyRootFilesystem: true` once `apt-get` is removed

**Files:**
- `templates/api/job-generate-keys.yaml` (lines 33, 36, 58)
- `values.yaml` — new `api.djangoConfigKeys.image` section

---

## Security — MEDIUM

### 11. ServiceAccount `automount` Defaults to `true` on All Components

**Severity: MEDIUM | Flagged by: Security**

All four ServiceAccounts default to `automountServiceAccountToken: true`:
- `ui.serviceAccount.automount: true` (line 77)
- `api.serviceAccount.automount: true` (line 290)
- `worker.serviceAccount.automount: true` (line 459)
- `worker_beat.serviceAccount.automount: true` (line 596)

The UI (Next.js frontend) and worker-beat (Celery scheduler) have no need for
Kubernetes API tokens. Mounting them unnecessarily expands the attack surface.

**Fix:** Default to `false` for UI, worker-beat, and (optionally) worker. Keep
`true` for API (required for K8s scanning RBAC). Document that operators using
Pod Identity must set `automount: true` on the worker SA.

**Files:**
- `values.yaml` — all four `serviceAccount.automount` defaults
- `templates/*/serviceaccount.yaml` (no template changes needed, just value defaults)

### 12. Network Policies: Single Toggle, Copy-Paste Errors, Missing for Neo4j/CronJob

**Severity: MEDIUM | Flagged by: Security**

All four network policy templates are gated by `api.networkPolicy.enabled` — even
the worker, worker-beat, and UI policies. The UI and worker-beat templates also
reference `api.networkPolicy.ingress`/`api.networkPolicy.egress` for additional
rules, which is a copy-paste error injecting API-intended rules into unrelated
components.

Neo4j and the scan recovery CronJob have no network policies at all.

**Fix:**
- Add per-component `networkPolicy` toggles under each component's values section
- Fix copy-paste errors in UI and worker-beat network policy templates
- Add network policy templates for Neo4j (restrict ingress to Bolt/HTTP from
  API/worker only) and CronJob (egress to PostgreSQL + Valkey only)

**Files:**
- `templates/ui/networkpolicy.yaml` (lines 20–22 — wrong value references)
- `templates/worker_beat/networkpolicy.yaml` (lines 36–38 — wrong value references)
- New: `templates/neo4j/networkpolicy.yaml`
- `values.yaml` — add `networkPolicy` sections for ui, worker, worker_beat, neo4j

### 13. No Support for Image Digests

**Severity: MEDIUM | Flagged by: Security**

All image references use `repository:tag`. Tags are mutable — a registry compromise
could push a different image under the same tag. Digests are immutable.

**Fix:** Add a `digest` field to each image config block. When set, prefer digest
over tag:

```yaml
{{- if .Values.api.image.digest }}
image: "{{ .Values.api.image.repository }}@{{ .Values.api.image.digest }}"
{{- else }}
image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag | default .Chart.AppVersion }}"
{{- end }}
```

**Files:**
- All deployment templates (image reference lines)
- `values.yaml` — add `digest: ""` to all image sections

### 14. Neo4j Has No ServiceAccount — Falls Back to `default` SA

**Severity: MEDIUM | Flagged by: Security**

The Neo4j deployment does not specify `serviceAccountName`. It uses the namespace
`default` SA, which may have unexpected permissions and mounts a K8s API token
unnecessarily.

**Fix:** Add a ServiceAccount template for Neo4j with `automountServiceAccountToken: false`.

**Files:**
- New: `templates/neo4j/serviceaccount.yaml`
- `templates/neo4j/deployment.yaml` — add `serviceAccountName`
- `values.yaml` — add `neo4j.serviceAccount` section

---

## P2 / LOW — Hardening and Polish

### 15. Worker-Beat Missing `terminationGracePeriodSeconds`

**Priority: P2 | Flagged by: Infra, SRE**

The worker deployment renders `terminationGracePeriodSeconds` from values (default 300s).
The worker-beat deployment does not — it uses the Kubernetes default of 30s. The field
should be exposed for consistency and operator configurability.

**Files:**
- `templates/worker_beat/deployment.yaml` — add field
- `values.yaml` — add `worker_beat.terminationGracePeriodSeconds: 30`

### 16. Hardcoded Secret Names Prevent External Secret Management

**Priority: P2 | Flagged by: Infra, Security**

`_helpers.tpl` (lines 87–162) hardcodes `prowler-postgres-secret` and
`prowler-valkey-secret` in all `secretKeyRef` lookups. Not configurable via values.

**Fix:** Add configurable secret names to `values.yaml` (with current names as
defaults for backward compatibility). Update `_helpers.tpl` to use them.

**Files:**
- `templates/_helpers.tpl` (lines 87–145)
- `values.yaml` — new `externalSecrets.postgres.secretName` / `valkey.secretName`

### 17. Neo4j Missing PDB and `terminationGracePeriodSeconds`

**Priority: P2 | Flagged by: SRE**

Neo4j is a stateful singleton with a RWO PVC. There is no PDB and no configurable
grace period. In Karpenter environments, the pod can be evicted with 30s notice,
risking data corruption during index builds or transactions.

**Fix:** Add `terminationGracePeriodSeconds` (default 120) and an optional PDB
template (disabled by default) for Neo4j.

**Files:**
- `templates/neo4j/deployment.yaml`
- New: `templates/neo4j/poddisruptionbudget.yaml`
- `values.yaml` — neo4j section

### 18. Scan Recovery Script Uses Unstructured `print()` Logging

**Priority: P2 | Flagged by: SRE**

`templates/worker/configmap-scan-recovery.yaml` (lines 9–115) uses `print()` while
the rest of the stack uses `DJANGO_LOGGING_FORMATTER: "ndjson"`. Recovery events are
invisible to log aggregation pipelines.

**Fix:** Use Python `logging` module with JSON formatter. Include affected scan IDs.

### 19. `DJANGO_ALLOWED_HOSTS` Defaults to Wildcard `*`

**Severity: LOW | Flagged by: Security**

`values.yaml` line 227 sets `DJANGO_ALLOWED_HOSTS: "*"`, disabling Django's Host
header validation. Defense in depth dictates restricting this.

**Fix:** Default to empty string with documentation, or auto-populate from
`api.ingress.hosts` when ingress is enabled.

### 20. Helm Test Pods Use Unpinned `busybox:latest` with No Security Context

**Severity: LOW | Flagged by: Security**

`templates/tests/test-api-connection.yaml` uses `busybox:latest` with no
`securityContext`. Pin to a specific version and add the chart's standard security
context.

### 21. Worker Network Policy Has Imprecise Cloud API Egress Rules

**Severity: LOW | Flagged by: Security**

`templates/worker/networkpolicy.yaml` lines 44–55 use `namespaceSelector: {}`
for port 443/6443 egress. This only matches in-cluster destinations, not external
cloud APIs. The intent and behavior diverge depending on CNI implementation.

**Fix:** Use explicit `to: []` (any destination) for port 443 with documentation,
or `ipBlock` rules for the K8s API server.

---

## Summary

| #  | Title                                                    | Priority / Severity | Source        |
|----|----------------------------------------------------------|---------------------|---------------|
| 1  | HPA scaleTargetRef bug                                   | P0 (bug)            | Infra, SRE    |
| 2  | Missing startupProbe on worker/worker-beat/UI            | P0                  | Infra, SRE, Sec |
| 3  | Worker-beat has no viable health check                   | P0                  | SRE, Sec, Infra |
| 4  | No extraEnv/extraEnvFrom support                         | P1                  | Infra         |
| 5  | Worker concurrency not configurable                      | P1                  | Infra         |
| 6  | Worker-beat missing Recreate strategy (duplicate beat)   | P1                  | SRE           |
| 7  | No preStop / graceful shutdown guidance                  | P1                  | SRE           |
| 8  | CronJob recovery race condition                          | P1                  | SRE           |
| 9  | CronJob inherits worker SA with cloud IAM                | HIGH                | Sec, Infra    |
| 10 | Key generator job supply chain risk                      | HIGH                | Sec           |
| 11 | ServiceAccount automount defaults to true everywhere     | MEDIUM              | Sec           |
| 12 | Network policies: single toggle, copy-paste errors       | MEDIUM              | Sec           |
| 13 | No image digest support                                  | MEDIUM              | Sec           |
| 14 | Neo4j has no ServiceAccount                              | MEDIUM              | Sec           |
| 15 | Worker-beat missing terminationGracePeriodSeconds        | P2                  | Infra, SRE    |
| 16 | Hardcoded secret names                                   | P2                  | Infra, Sec    |
| 17 | Neo4j missing PDB and terminationGracePeriodSeconds      | P2                  | SRE           |
| 18 | Recovery script unstructured logging                     | P2                  | SRE           |
| 19 | DJANGO_ALLOWED_HOSTS defaults to `*`                     | LOW                 | Sec           |
| 20 | Test pods unpinned image, no security context            | LOW                 | Sec           |
| 21 | Worker network policy imprecise egress                   | LOW                 | Sec           |
