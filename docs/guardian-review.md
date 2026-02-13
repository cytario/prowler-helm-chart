# Guardian Review: Helm Chart Change Requests v1.3.5

**Reviewer:** Prowler Chart Guardian (Principal Cloud & Web Security Engineer)
**Date:** 2026-02-13
**Chart Version:** 1.3.5 (appVersion 5.17.1)
**Source Document:** `/docs/helm-chart-change-requests.md`
**Scope:** Code-level verification of all 21 items against actual template and values files.

---

## Methodology

Every item was verified by reading the actual template files, `values.yaml`, and `_helpers.tpl`. Line numbers reference the current state of the chart on the `main` branch at commit `b444f67`. Verdicts use the following scale:

- **CONFIRMED** -- The bug/issue exists exactly as described.
- **CONFIRMED WITH CORRECTIONS** -- The issue exists but the description or proposed fix has errors.
- **PARTIALLY CONFIRMED** -- The issue exists but is overstated or understated.
- **DISPUTED** -- The issue does not exist as described or the priority is wrong.

---

## Item 1: HPA scaleTargetRef Bug

**Verdict: CONFIRMED -- P0 bug, priority rating is correct.**

All four HPA templates use `{{ include "prowler.fullname" . }}` on the `scaleTargetRef.name` line (line 12 in each file) while the corresponding Deployment metadata names append a component suffix.

Evidence from source:

| File | HPA metadata.name (correct) | scaleTargetRef.name (broken) | Deployment name (target) |
|---|---|---|---|
| `templates/api/hpa.yaml:12` | `<fullname>-api` | `<fullname>` | `<fullname>-api` |
| `templates/worker/hpa.yaml:12` | `<fullname>-worker` | `<fullname>` | `<fullname>-worker` |
| `templates/worker_beat/hpa.yaml:12` | `<fullname>-worker-beat` | `<fullname>` | `<fullname>-worker-beat` |
| `templates/ui/hpa.yaml:12` | `<fullname>-ui` | `<fullname>` | `<fullname>-ui` |

The irony is that each HPA's own `metadata.name` is correct (e.g., `{{ include "prowler.fullname" . }}-api`), but the `scaleTargetRef.name` it references is missing the suffix. This means every HPA, when enabled, would point to a non-existent Deployment and silently do nothing.

**Proposed fix assessment:** Correct and complete. Append `-api`, `-worker`, `-worker-beat`, `-ui` respectively. No breaking changes since autoscaling is `enabled: false` by default for all components, so this is dead code today -- but it must be fixed before anyone enables it.

**Risk:** None. The feature is currently disabled by default. Fixing it only makes the feature work correctly when enabled.

---

## Item 2: Missing startupProbe on Worker, Worker-Beat, and UI

**Verdict: CONFIRMED -- Priority should be P1, not P0.**

Verified in templates:

- `templates/api/deployment.yaml` lines 66-69: Renders `startupProbe` via `{{- with .Values.api.startupProbe }}`.
- `templates/neo4j/deployment.yaml` lines 87-90: Renders `startupProbe` via `{{- with .Values.neo4j.startupProbe }}`.
- `templates/worker/deployment.yaml`: Lines 99-106 render only `livenessProbe` and `readinessProbe`. **No startupProbe block exists.**
- `templates/worker_beat/deployment.yaml`: Lines 62-69 render only `livenessProbe` and `readinessProbe`. **No startupProbe block exists.**
- `templates/ui/deployment.yaml`: Lines 60-67 render only `livenessProbe` and `readinessProbe`. **No startupProbe block exists.**

In `values.yaml`:
- `api.startupProbe` is defined at line 353 with httpGet configuration.
- `neo4j.startupProbe` is defined at line 722 with httpGet configuration.
- `worker.startupProbe`, `worker_beat.startupProbe`, and `ui.startupProbe` do **not exist**.

**Priority correction:** I would rate this P1, not P0. The current defaults for worker/worker-beat are `livenessProbe: {}` and `readinessProbe: {}` (empty), meaning no probes are rendered at all. Adding `startupProbe` rendering to the template is useful for completeness, but with no probes defined, nothing is actively broken. The real P0 would be if liveness probes were active and killing slow-starting pods. That said, the missing template rendering is still a gap that prevents operators from configuring probes properly.

**Proposed fix assessment:** Correct pattern. Add `{{- with .Values.<component>.startupProbe }}` blocks and `startupProbe: {}` defaults. The fix should insert the startupProbe block **before** the livenessProbe block in each template, matching the API template's ordering (startupProbe -> livenessProbe -> readinessProbe).

**Risk:** None for existing deployments (empty default means no probe rendered).

---

## Item 3: Worker-Beat Has No Viable Health Check Mechanism

**Verdict: CONFIRMED WITH CORRECTIONS -- Priority is P1, not P0.**

Verified in `values.yaml` lines 635-636:
```yaml
livenessProbe: {}
readinessProbe: {}
```

Both are empty, so no probes are rendered. The analysis about `celery inspect ping` being unsuitable for beat is correct -- it pings workers, not the beat scheduler itself.

**Priority correction:** Downgrade to P1. With `livenessProbe: {}`, no probe is rendered at all, meaning Kubernetes does not health-check beat. This is operationally poor but not actively destructive. It becomes P0 only if someone configures a probe that provides false positive health signals.

**Proposed fix assessment:** The `pgrep -f 'celery.*beat'` example is a reasonable starting point, but with caveats:

1. The command requires `/bin/sh` and `pgrep` to exist in the container. The Prowler API image (`prowlercloud/prowler-api`) is based on a Python image -- `pgrep` availability must be verified.
2. A better approach if Prowler's beat writes a schedule file would be to check `celerybeat-schedule` file modification time, but this requires knowledge of Prowler's beat configuration.
3. The fix should be documentation-only in `values.yaml` comments, not a default probe. Defaulting to a specific exec probe is risky without verifying it works against the actual container image.

**Additional recommendation:** Document this in `values.yaml` as a commented-out example, not an active default.

---

## Item 4: No extraEnv / extraEnvFrom Support

**Verdict: CONFIRMED -- P1 is correct.**

Verified all four deployment templates. The env/envFrom blocks are:

- **API** (`templates/api/deployment.yaml` lines 62-65): Uses shared `prowler.envFrom` and `prowler.env` helpers. No `extraEnv` rendering.
- **Worker** (`templates/worker/deployment.yaml` lines 95-98): Same shared helpers. No `extraEnv` rendering.
- **Worker-Beat** (`templates/worker_beat/deployment.yaml` lines 58-61): Same shared helpers. No `extraEnv` rendering.
- **UI** (`templates/ui/deployment.yaml` lines 55-59): Uses its own configMapRef/secretRef (not the shared helper). No `extraEnv` rendering.

There is no mechanism for per-component env injection, `fieldRef`, or per-component `envFrom`.

**Proposed fix assessment:** Correct and standard pattern. Implementation notes:

1. Add `extraEnv: []` and `extraEnvFrom: []` to each component section in `values.yaml`.
2. In templates, render after existing blocks:
   ```yaml
   {{- with .Values.<component>.extraEnvFrom }}
   {{- toYaml . | nindent 12 }}
   {{- end }}
   ```
   and
   ```yaml
   {{- with .Values.<component>.extraEnv }}
   {{- toYaml . | nindent 12 }}
   {{- end }}
   ```
3. For the envFrom block, `extraEnvFrom` items should be appended to the existing `envFrom:` list, not rendered as a separate `envFrom:` key (which would be invalid YAML for a container spec). This means the template change is slightly more nuanced than the CR suggests -- the `extraEnvFrom` items must be rendered inside the existing `envFrom:` block.

**Risk:** None for existing deployments (empty defaults).

**Dependency:** Item 5 (Celery concurrency) benefits from this being implemented first, as the concurrency env var could be injected via `extraEnv`.

---

## Item 5: Worker Celery Concurrency Not Configurable

**Verdict: CONFIRMED -- P1 is correct, but this is primarily an upstream image change.**

The Helm chart cannot fix this alone. The container entrypoint (`docker-entrypoint.sh` inside `prowlercloud/prowler-api`) would need to read an environment variable for `--concurrency`.

**Proposed fix assessment:** The CR correctly identifies this requires a coordinated image + chart change. From the chart side:
- If item 4 (extraEnv) is implemented, operators can already inject `CELERY_WORKER_CONCURRENCY` without any additional chart change.
- Alternatively, adding it to `api.djangoConfig` makes it apply globally (including to the API Gunicorn workers and beat), which may cause unintended side effects.

**Recommendation:** Implement item 4 first. Then document the concurrency tuning pattern using `extraEnv` in `values.yaml` comments. Coordinate with upstream Prowler to support the env var in the entrypoint.

**Risk:** Without this fix, pods on large nodes will spawn excessive Celery workers, leading to OOMKills. This is an active production issue for anyone running on nodes larger than their pod resource limits.

---

## Item 6: Worker-Beat Missing Recreate Strategy / Allows Multiple Replicas

**Verdict: CONFIRMED -- P1 is correct.**

Verified in `templates/worker_beat/deployment.yaml`:
- No `strategy:` block exists. Kubernetes defaults to `RollingUpdate`.
- `values.yaml` line 566: `replicaCount: 1` (correct default, but not enforced).
- `templates/worker_beat/hpa.yaml` exists and can scale beyond 1 replica when `autoscaling.enabled: true`.
- `values.yaml` lines 639-644: HPA config allows `maxReplicas: 10` for worker-beat.

For comparison, `templates/neo4j/deployment.yaml` lines 13-14 already use:
```yaml
strategy:
  type: Recreate
```

**Proposed fix assessment:** Correct and well-precedented by the Neo4j template.

1. Add `strategy: type: Recreate` to worker-beat deployment template.
2. Add a comment in `values.yaml` that beat must be a singleton.
3. The HPA template for worker-beat should either be removed or guarded. Removing it is the cleanest approach since HPA + Recreate + singleton is contradictory. Alternatively, if keeping the HPA template, enforce `maxReplicas: 1` in the template or add a schema validation in `values.schema.json`.

**Risk:** Adding `Recreate` strategy changes rollout behavior. During a Helm upgrade, the old beat pod will be terminated before the new one starts, creating a brief window with no beat scheduler. This is the correct trade-off (brief gap vs. duplicate schedulers), but it should be documented.

---

## Item 7: No preStop / Graceful Shutdown Guidance for Workers

**Verdict: CONFIRMED -- P1 is correct.**

Verified in `templates/worker/deployment.yaml`:
- Line 41: `terminationGracePeriodSeconds: {{ .Values.worker.terminationGracePeriodSeconds }}` is rendered.
- `values.yaml` line 429: Default is 300 seconds.
- No `lifecycle` block exists in the worker container spec (lines 79-117).

**Proposed fix assessment:** Partially correct. Adding `lifecycle` rendering is straightforward:
```yaml
{{- with .Values.worker.lifecycle }}
lifecycle:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

However, the documentation aspect is the more critical part. Without knowing Prowler's Celery `acks_late` behavior, operators cannot tune `terminationGracePeriodSeconds` correctly. If `acks_late=False` (the Celery default), tasks are acknowledged on receipt, and a killed worker loses those tasks permanently. If `acks_late=True`, tasks are re-queued to another worker on SIGTERM.

**Recommendation:** Add `lifecycle: {}` to `values.yaml` with comments documenting:
1. Default Celery behavior on SIGTERM (warm shutdown: stop accepting new tasks, finish current ones).
2. That `terminationGracePeriodSeconds` should exceed the longest expected scan duration.
3. A `preStop` sleep example for deregistration from the broker.

**Risk:** None for template changes (empty default). Documentation-only for the rest.

---

## Item 8: Scan Recovery CronJob Race Condition

**Verdict: CONFIRMED WITH CORRECTIONS -- P1 is correct, but the fix is incomplete.**

Verified in `templates/worker/configmap-scan-recovery.yaml`:

- Lines 98-107 (`cronjob_mode()`): Filters by `state="executing"` and `started_at__lt=cutoff`, then calls `recover_scans()`.
- Line 71 (`recover_scans()`): `queryset.update(state="failed", completed_at=timezone.now())` -- no optimistic concurrency guard.
- Lines 78-95 (`init_mode()`): Checks `count_active_workers()` first. CronJob mode does NOT check for active workers.

The race condition is real: a worker processing a legitimately long scan could have its scan marked as failed while still running. The subsequent worker completion would then try to update a scan that is already in `failed` state.

**Fix assessment corrections:**

1. The suggestion to add `app.control.inspect().active()` to the CronJob mode is reasonable but introduces a broker dependency that the CronJob mode was explicitly designed to avoid (the CronJob mode uses "time threshold only" as stated in the script's docstring). Adding this would make the CronJob mode functionally equivalent to the init container mode.

2. The optimistic concurrency fix (`queryset.filter(state="executing").update(...)`) is **already partially in place** -- the queryset is built with `Scan.objects.filter(state="executing")` on line 106. However, between the `filter()` and `update()` on line 71, the state could change. The real fix is to chain `.filter(state="executing")` directly in the `update()` call:
   ```python
   queryset.filter(state="executing").update(state="failed", completed_at=timezone.now())
   ```
   This is technically already the case since `queryset` is built from `Scan.objects.filter(state="executing")`. The Django ORM will generate a single `UPDATE ... WHERE state='executing'` SQL statement. The actual race is at a higher level: the worker finishes its scan and sets `state="completed"` at the same moment the CronJob sets `state="failed"`. Without `SELECT FOR UPDATE`, whichever runs last wins. But adding `SELECT FOR UPDATE` to a CronJob that runs every 15 minutes is heavy-handed.

3. **The most practical fix** is to increase `thresholdSeconds` to a value safely beyond any legitimate scan duration (e.g., 4+ hours), and to log the affected scan IDs as the CR suggests.

**Risk:** Modifying the recovery script behavior changes the ConfigMap, which triggers a worker pod restart (via the checksum annotation on `templates/worker/deployment.yaml` line 22). This should be called out in the implementation.

---

## Item 9: CronJob Inherits Worker ServiceAccount

**Verdict: CONFIRMED -- HIGH severity is correct.**

Verified in `templates/worker/cronjob-scan-recovery.yaml` line 28:
```yaml
serviceAccountName: {{ include "prowler.worker.serviceAccountName" . }}
```

The worker ServiceAccount is the one annotated with IRSA/Pod Identity/Workload Identity for cloud scanning. The CronJob only needs PostgreSQL access (via environment variables from secrets) -- it makes no AWS/Azure/GCP API calls.

**Proposed fix assessment:** Correct approach. Implementation:

1. Add to `values.yaml` under `worker.scanRecoveryCronJob`:
   ```yaml
   serviceAccount:
     create: true
     automount: false
     annotations: {}
     name: ""
   ```
2. Create `templates/worker/serviceaccount-scan-recovery.yaml`.
3. Add a helper in `_helpers.tpl`:
   ```
   {{- define "prowler.scanRecoveryCronJob.serviceAccountName" -}}
   ...
   {{- end }}
   ```
4. Update `templates/worker/cronjob-scan-recovery.yaml` to use the new helper.

**Risk:** Breaking change for users who have already deployed the CronJob with custom worker SA annotations. Must default to the worker SA when `create: false` and `name: ""` for backward compatibility, as the CR correctly states.

**Dependency:** Should be implemented alongside the CronJob itself (which is `enabled: false` by default).

---

## Item 10: Key Generator Job Supply Chain Risk

**Verdict: CONFIRMED -- HIGH severity is correct.**

Verified in `templates/api/job-generate-keys.yaml`:

- Line 33: `image: bitnami/kubectl:latest` -- unpinned, mutable tag.
- Line 36: `readOnlyRootFilesystem: false` -- required only because of `apt-get`.
- Line 58: `apt-get update -qq && apt-get install -y -qq openssl > /dev/null 2>&1` -- runtime package installation from the internet.

This job runs as a Helm pre-install/pre-upgrade hook (line 10-11) with a ServiceAccount (`<fullname>-key-generator`, line 24) that has permissions to create/get secrets. A compromised image could exfiltrate the generated RSA private key and Fernet encryption key.

**Proposed fix assessment:** Correct direction, but incomplete. There are multiple approaches:

**Option A (preferred): Eliminate the Job entirely.** The chart already supports `djangoConfigKeys.create: true`. Instead of a Job, generate keys using Helm's `lookup` function and `genPrivateKey`/`randAlphaNum` in a Secret template. This is what many charts do (e.g., the Neo4j secret in this chart already uses `lookup` for password persistence). This eliminates the external image dependency entirely.

**Option B: Pin the image.** If the Job is kept:
- Pin to a specific digest: `bitnami/kubectl@sha256:<hash>`
- Use an image with `openssl` pre-installed (e.g., `alpine/openssl` or build a custom image)
- Add `readOnlyRootFilesystem: true` once `apt-get` is removed
- Add configurable image reference in `values.yaml`

**Observation:** I checked `templates/neo4j/secret.yaml` to confirm -- the chart already has a pattern for auto-generating and persisting secrets using `lookup`:

The Neo4j secret template likely generates and persists the password using Helm `lookup` + `randAlphaNum`. The key generator Job should be migrated to the same pattern.

**Risk:** Option A is a significant refactor of the key generation mechanism. It should be tested thoroughly since the RSA key pair generation (2048-bit) requires `genPrivateKey "rsa"` which is available in Helm's `crypto` functions. Option B is lower risk but still requires image changes.

---

## Item 11: ServiceAccount automount Defaults to true

**Verdict: CONFIRMED -- MEDIUM severity is correct.**

Verified in `values.yaml`:
- Line 77: `ui.serviceAccount.automount: true`
- Line 290: `api.serviceAccount.automount: true`
- Line 459: `worker.serviceAccount.automount: true`
- Line 597: `worker_beat.serviceAccount.automount: true`

Verified in all four `serviceaccount.yaml` templates -- each renders:
```yaml
automountServiceAccountToken: {{ .Values.<component>.serviceAccount.automount }}
```

**Fix assessment:** Correct. Safe candidates for default `false`:
- **UI:** Next.js frontend. No K8s API interaction. Default to `false`.
- **Worker-Beat:** Celery beat scheduler. No K8s API interaction. Default to `false`.
- **Worker:** Celery worker. Does NOT directly interact with K8s API (scanning is done via cloud provider APIs, not the K8s API). However, some operators use Pod Identity which requires the SA token mount for OIDC token exchange. Default to `false` with documentation.
- **API:** Needs K8s API access for RBAC-based Kubernetes scanning (there is a ClusterRole/ClusterRoleBinding created via `api.rbac.create`). Keep `true`.

**Risk:** This is a **breaking change** for any operator using Pod Identity (IRSA, Azure Workload Identity, GCP Workload Identity Federation) on the worker or worker-beat, as these mechanisms require `automountServiceAccountToken: true`. Must be documented in CHANGELOG and migration notes.

**Dependency:** If item 9 (CronJob SA separation) is implemented, the CronJob SA can default to `automount: false` independently.

---

## Item 12: Network Policy Issues

**Verdict: CONFIRMED -- MEDIUM severity is correct.**

### 12a: Single toggle gates all policies

Verified: All four network policy templates use `{{- if .Values.api.networkPolicy.enabled -}}` as the gate:

| File | Line 1 |
|---|---|
| `templates/api/networkpolicy.yaml` | `{{- if .Values.api.networkPolicy.enabled -}}` |
| `templates/worker/networkpolicy.yaml` | `{{- if .Values.api.networkPolicy.enabled -}}` |
| `templates/worker_beat/networkpolicy.yaml` | `{{- if .Values.api.networkPolicy.enabled -}}` |
| `templates/ui/networkpolicy.yaml` | `{{- if .Values.api.networkPolicy.enabled -}}` |

There are no per-component `networkPolicy.enabled` toggles in `values.yaml` for worker, worker-beat, or UI.

### 12b: Copy-paste errors in additional rules

Verified. The `{{- with }}` blocks for additional rules reference `api.networkPolicy` in non-API templates:

| File | Line | References |
|---|---|---|
| `templates/ui/networkpolicy.yaml` | Line 20 | `.Values.api.networkPolicy.ingress` (should be UI-specific) |
| `templates/ui/networkpolicy.yaml` | Line 41 | `.Values.api.networkPolicy.egress` (should be UI-specific) |
| `templates/worker_beat/networkpolicy.yaml` | Line 36 | `.Values.api.networkPolicy.egress` (should be worker-beat-specific) |
| `templates/worker/networkpolicy.yaml` | Line 56 | `.Values.api.networkPolicy.egress` (should be worker-specific) |

This means if an operator adds custom ingress/egress rules to `api.networkPolicy.ingress`/`api.networkPolicy.egress`, those rules would be injected into ALL components' network policies -- which is almost certainly not the intent.

### 12c: Missing Neo4j and CronJob network policies

Verified. No `templates/neo4j/networkpolicy.yaml` exists. No network policy is applied to CronJob pods.

**Proposed fix assessment:** Correct direction. The per-component toggle approach is standard (e.g., Bitnami charts). Implementation should:
1. Add `networkPolicy.enabled`, `networkPolicy.ingress`, `networkPolicy.egress` to each component in `values.yaml`.
2. Update each template to reference its own component's toggle and rules.
3. Add Neo4j network policy (ingress: Bolt port 7687 + HTTP port 7474 from API/worker pods only; egress: DNS only).
4. Add CronJob network policy (egress: PostgreSQL 5432, Valkey 6379, DNS only).

**Risk:** The fix to per-component toggles changes the values structure. Existing users with `api.networkPolicy.enabled: true` would need to add toggles for each component to maintain the same behavior. This needs migration documentation.

---

## Item 13: No Image Digest Support

**Verdict: CONFIRMED -- MEDIUM severity is correct.**

Verified all image references:

| File | Line | Pattern |
|---|---|---|
| `templates/api/deployment.yaml` | 48 | `"{{ .Values.api.image.repository }}:{{ .Values.api.image.tag \| default .Chart.AppVersion }}"` |
| `templates/worker/deployment.yaml` | 85 | `"{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag \| default .Chart.AppVersion }}"` |
| `templates/worker_beat/deployment.yaml` | 48 | `"{{ .Values.worker_beat.image.repository }}:{{ .Values.worker_beat.image.tag \| default .Chart.AppVersion }}"` |
| `templates/ui/deployment.yaml` | 49 | `"{{ .Values.ui.image.repository }}:{{ .Values.ui.image.tag \| default .Chart.AppVersion }}"` |
| `templates/neo4j/deployment.yaml` | 49 | `"{{ .Values.neo4j.image.repository }}:{{ .Values.neo4j.image.tag }}"` |
| `templates/api/job-generate-keys.yaml` | 33 | `bitnami/kubectl:latest` (hardcoded, no values at all) |

No `digest` field exists in any image configuration in `values.yaml`.

**Proposed fix assessment:** The template snippet in the CR is correct:
```yaml
{{- if .Values.api.image.digest }}
image: "{{ .Values.api.image.repository }}@{{ .Values.api.image.digest }}"
{{- else }}
image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag | default .Chart.AppVersion }}"
{{- end }}
```

This should be applied to all six image references. An `_helpers.tpl` function would reduce duplication:
```
{{- define "prowler.image" -}}
{{- if .digest -}}
{{ .repository }}@{{ .digest }}
{{- else -}}
{{ .repository }}:{{ .tag | default $.appVersion }}
{{- end -}}
{{- end -}}
```

**Risk:** None for existing deployments (digest defaults to empty string, existing tag behavior preserved).

---

## Item 14: Neo4j Has No ServiceAccount

**Verdict: CONFIRMED -- MEDIUM severity is correct.**

Verified in `templates/neo4j/deployment.yaml`: No `serviceAccountName` field exists in the pod spec (lines 34-129). The template jumps from `imagePullSecrets` directly to `securityContext`.

Verified the list of neo4j templates:
```
templates/neo4j/deployment.yaml
templates/neo4j/pvc.yaml
templates/neo4j/secret.yaml
templates/neo4j/service.yaml
```

No `serviceaccount.yaml` exists under `templates/neo4j/`.

**Proposed fix assessment:** Correct. Create:
1. `templates/neo4j/serviceaccount.yaml` -- following the exact pattern of the other four SA templates.
2. Add `serviceAccountName` to the pod spec in `templates/neo4j/deployment.yaml`.
3. Add `neo4j.serviceAccount` section to `values.yaml` with:
   ```yaml
   serviceAccount:
     create: true
     automount: false  # Neo4j does not need K8s API access
     annotations: {}
     name: ""
   ```
4. Add helper function `prowler.neo4j.serviceAccountName` to `_helpers.tpl`.

**Risk:** For existing deployments, this will change the pod from using the `default` SA to a newly created dedicated SA. This is a non-disruptive change if no Pod Security Policies or RBAC bindings reference the `default` SA specifically, which would be unusual.

---

## Item 15: Worker-Beat Missing terminationGracePeriodSeconds

**Verdict: CONFIRMED -- P2 is correct.**

Verified:
- `templates/worker/deployment.yaml` line 41: `terminationGracePeriodSeconds: {{ .Values.worker.terminationGracePeriodSeconds }}`
- `templates/worker_beat/deployment.yaml`: **No `terminationGracePeriodSeconds` field exists.** Kubernetes defaults to 30s.
- `values.yaml` worker section line 429: `terminationGracePeriodSeconds: 300`
- `values.yaml` worker_beat section: **No such field.**

**Proposed fix assessment:** Correct. Add to `templates/worker_beat/deployment.yaml` inside `.spec.template.spec` (after the `securityContext` block, before `containers`):
```yaml
terminationGracePeriodSeconds: {{ .Values.worker_beat.terminationGracePeriodSeconds }}
```

And add to `values.yaml` in the `worker_beat` section:
```yaml
terminationGracePeriodSeconds: 30
```

The default of 30s is appropriate for beat (it has no long-running tasks, just scheduling). The worker's 300s default is for in-flight scans.

**Risk:** None for existing deployments (30s is the K8s default, making this explicit just adds configurability).

**Dependency:** Interacts with item 6 (Recreate strategy). If Recreate is added, the `terminationGracePeriodSeconds` determines how long K8s waits before force-killing the old beat pod during upgrades.

---

## Item 16: Hardcoded Secret Names

**Verdict: CONFIRMED -- P2 is correct.**

Verified in `templates/_helpers.tpl` lines 87-144:
```yaml
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: prowler-postgres-secret     # line 92 -- hardcoded
      key: POSTGRES_HOST
```

All 11 secret references (7 PostgreSQL + 4 Valkey) use hardcoded names:
- `prowler-postgres-secret` (lines 92, 97, 102, 107, 112, 117, 122)
- `prowler-valkey-secret` (lines 128, 133, 138, 143)

These are not configurable via `values.yaml`.

**Proposed fix assessment:** Correct approach. Add to `values.yaml`:
```yaml
externalSecrets:
  postgres:
    secretName: "prowler-postgres-secret"
  valkey:
    secretName: "prowler-valkey-secret"
```

Update `_helpers.tpl` to use:
```yaml
name: {{ .Values.externalSecrets.postgres.secretName }}
```

**Risk:** None if defaults match current hardcoded values. This is backward compatible by definition.

**Note:** The values path suggested in the CR (`externalSecrets.postgres.secretName`) is reasonable. An alternative would be `global.postgres.secretName` to follow the Bitnami convention, but `externalSecrets` is more descriptive for this chart's architecture where external secrets are a prerequisite.

---

## Item 17: Neo4j Missing PDB and terminationGracePeriodSeconds

**Verdict: CONFIRMED -- P2 is correct.**

Verified in `templates/neo4j/deployment.yaml`:
- No `terminationGracePeriodSeconds` in the pod spec.
- No PDB template exists in `templates/neo4j/`.
- The deployment already uses `strategy: type: Recreate` (lines 13-14), which means during upgrades the pod is killed with only the default 30s grace period.

For context, all other components have PDB templates:
- `templates/api/poddisruptionbudget.yaml`
- `templates/worker/poddisruptionbudget.yaml`
- `templates/worker_beat/poddisruptionbudget.yaml`
- `templates/ui/poddisruptionbudget.yaml`

**Proposed fix assessment:** Correct.

1. Add `terminationGracePeriodSeconds: 120` to `values.yaml` neo4j section and render in the template.
2. Add `templates/neo4j/poddisruptionbudget.yaml` following the existing pattern. Suggest `enabled: false` by default (single-replica PDB with `minAvailable: 0` is useful for Karpenter `do-not-disrupt` semantics but unusual).

**Risk:** Adding `terminationGracePeriodSeconds: 120` changes upgrade behavior -- Neo4j pod gets 120s instead of 30s to shut down cleanly. This is a positive change but should be noted. A PDB with `minAvailable: 1` on a single-replica deployment would make the pod un-evictable, which is probably not desired. Default to `enabled: false` or `minAvailable: 0`.

---

## Item 18: Scan Recovery Script Unstructured Logging

**Verdict: CONFIRMED -- P2 is correct.**

Verified in `templates/worker/configmap-scan-recovery.yaml`. The script uses `print()` throughout:
- Line 53: `print(f"ERROR: Cannot connect to broker: {e}")`
- Line 63: `print(f"Warning: Could not ping workers: {e}")`
- Line 72: `print(f"Recovered {count} orphaned scan(s) ({reason})")`
- Line 74: `print("No orphaned scans found")`
- Lines 81, 86, 89, 94, 101: Additional `print()` calls.

The rest of the stack uses `DJANGO_LOGGING_FORMATTER: "ndjson"` (values.yaml line 233), so these messages will not be parseable by log aggregation pipelines.

**Proposed fix assessment:** Correct direction. Since the script already imports Django and calls `django.setup()`, it could use Django's logging infrastructure:
```python
import logging
logger = logging.getLogger("prowler.scan_recovery")
```

This would automatically pick up the `DJANGO_LOGGING_FORMATTER` setting.

**Risk:** Minimal. The change is internal to the ConfigMap. Note that changing the ConfigMap will trigger worker pod restarts via the checksum annotation (only when init container mode is active, since the checksum annotation at `templates/worker/deployment.yaml` line 22 is gated by `worker.scanRecovery.enabled`).

---

## Item 19: DJANGO_ALLOWED_HOSTS Defaults to Wildcard

**Verdict: CONFIRMED -- LOW severity is correct.**

Verified at `values.yaml` line 227:
```yaml
DJANGO_ALLOWED_HOSTS: "*"
```

This disables Django's Host header validation, which is a defense-in-depth measure against HTTP Host header attacks.

**Proposed fix assessment:** The suggestion to auto-populate from `api.ingress.hosts` is clever but complex to implement in Helm templates. A simpler approach:
- Change the default to empty string and document that users must set it.
- This would **break** the out-of-the-box experience (Django returns 400 Bad Request for any hostname not in the allowed list).

**Recommendation:** Keep `"*"` as default for ease of deployment, but add a comment in `values.yaml` recommending operators restrict it:
```yaml
# WARNING: Defaults to "*" for ease of deployment. In production, restrict to your domain:
# DJANGO_ALLOWED_HOSTS: "prowler.example.com"
DJANGO_ALLOWED_HOSTS: "*"
```

**Risk:** Changing the default to anything other than `"*"` is a breaking change. The LOW severity is appropriate -- this is defense in depth behind ingress controllers and service meshes.

---

## Item 20: Test Pod Unpinned Image and No Security Context

**Verdict: CONFIRMED -- LOW severity is correct.**

Verified in `templates/tests/test-api-connection.yaml`:
- Line 13: `image: busybox:latest` -- unpinned, mutable tag.
- No `securityContext` on the pod or container.
- No `serviceAccountName` specified (uses default SA).

**Proposed fix assessment:** Correct. Pin to a specific version (e.g., `busybox:1.37.0`) and add the standard security context:
```yaml
spec:
  serviceAccountName: {{ include "prowler.api.serviceAccountName" . }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: wget
      image: busybox:1.37.0
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

Consider making the image configurable via values if enterprise environments use private registries.

**Risk:** None. Test pods only run during `helm test`.

---

## Item 21: Worker Network Policy Imprecise Egress

**Verdict: CONFIRMED WITH CORRECTIONS -- LOW severity is correct.**

Verified in `templates/worker/networkpolicy.yaml` lines 44-55:
```yaml
# Allow egress to cloud provider APIs for scanning
- to:
  - namespaceSelector: {}
  ports:
  - protocol: TCP
    port: 443
# Allow egress to Kubernetes API for scanning
- to:
  - namespaceSelector: {}
  ports:
  - protocol: TCP
    port: 6443
```

**Correction:** The CR states "`namespaceSelector: {}` only matches in-cluster destinations." This is **correct for most CNI implementations** but the semantics vary:
- **Calico, Cilium:** `namespaceSelector: {}` matches pods in any namespace (in-cluster only). External IPs require `ipBlock`.
- **Some CNIs** may interpret `to: [namespaceSelector: {}]` as all destinations.

Since Prowler workers need to reach external cloud APIs (AWS STS, Azure management endpoints, GCP APIs) on port 443, the current rule would block scanning in most CNI configurations.

**Proposed fix assessment:** The CR's suggestion to use `to: []` (or omit `to` entirely) for the port 443 rule is correct. For port 6443 (Kubernetes API), an `ipBlock` rule targeting the API server IP is more precise but harder to template. The pragmatic fix:
```yaml
# Allow egress to cloud provider APIs for scanning (any destination on 443)
- ports:
  - protocol: TCP
    port: 443
# Allow egress to Kubernetes API for scanning (any destination on 6443)
- ports:
  - protocol: TCP
    port: 6443
```

**Risk:** Widening egress rules is a security trade-off. The current rules are too restrictive (blocking cloud scanning), so the fix actually aligns policy with intent. Document that this allows egress to any destination on 443/6443.

---

## Cross-Cutting Analysis

### Dependencies Between Items

The following implementation order is recommended:

```
Phase 1 (Foundation):
  #1  HPA fix (trivial, zero risk)
  #6  Worker-beat Recreate strategy
  #15 Worker-beat terminationGracePeriodSeconds
  #20 Test pod hardening

Phase 2 (Extensibility):
  #4  extraEnv/extraEnvFrom (#5 depends on this)
  #2  startupProbe rendering
  #13 Image digest support

Phase 3 (Security hardening):
  #10 Key generator Job (can be refactored to template-based generation)
  #9  CronJob ServiceAccount separation
  #14 Neo4j ServiceAccount
  #11 ServiceAccount automount defaults (BREAKING - needs migration notes)

Phase 4 (Network & operational):
  #12 Network policy per-component toggles (BREAKING - needs migration notes)
  #21 Worker network policy egress fix
  #16 Configurable secret names
  #17 Neo4j PDB and grace period

Phase 5 (Documentation & refinement):
  #3  Worker-beat health check documentation
  #5  Celery concurrency (requires upstream coordination)
  #7  Graceful shutdown documentation
  #8  CronJob race condition (script logic change)
  #18 Recovery script structured logging
  #19 DJANGO_ALLOWED_HOSTS documentation
```

### Conflicts Between Items

- **Items 4 and 5:** Item 5 (Celery concurrency) can be partially solved by item 4 (extraEnv) without upstream image changes. No conflict, just dependency.
- **Items 6 and 1 (HPA for worker-beat):** Item 6 recommends removing the worker-beat HPA or limiting `maxReplicas: 1`. Item 1 fixes the HPA's `scaleTargetRef`. If item 6 removes the HPA, the item 1 fix for worker-beat becomes moot. Implement item 6 first for worker-beat, then decide whether to fix or remove its HPA.
- **Items 11 and 9:** Item 11 changes automount defaults. Item 9 creates a new SA for the CronJob. These should be coordinated so the new CronJob SA is created with `automount: false` from the start.
- **Items 8 and 18:** Both modify the scan recovery ConfigMap. Should be done in the same PR to avoid double worker restarts from checksum annotation changes.

### Existing Chart Patterns to Follow

1. **Probe rendering:** Use `{{- with .Values.<component>.<probe> }}` pattern (established in API and Neo4j templates).
2. **ServiceAccount creation:** Follow the four existing templates exactly -- conditional on `.Values.<component>.serviceAccount.create`, with `automountServiceAccountToken`.
3. **Helper naming:** `prowler.<component>.serviceAccountName`, `prowler.<component>.fullname`, etc.
4. **Security context:** Pod-level and container-level split, with the standard set (runAsNonRoot, runAsUser, capabilities drop ALL, seccompProfile RuntimeDefault).
5. **PDB:** Gated by `.Values.<component>.podDisruptionBudget.enabled` with `minAvailable` default.
6. **Topology spread:** `defaultTopologySpread: true` with `topologySpreadConstraints: []` override. Not applicable to singletons (worker-beat, neo4j).
7. **Labels:** `prowler.labels` for common labels + explicit `app.kubernetes.io/name: <fullname>-<component>` override.

### Missing Items Not in the Change Requests

The following issues exist in the chart but were not captured in the change request document:

1. **Duplicate `app.kubernetes.io/name` label in all deployments.** The `prowler.labels` include renders `app.kubernetes.io/name: {{ include "prowler.name" . }}` (via `prowler.selectorLabels`), and then each template overrides it with `app.kubernetes.io/name: {{ include "prowler.fullname" . }}-<component>`. This produces two `app.kubernetes.io/name` entries at the YAML level. While Kubernetes takes the last one, `helm lint` does not flag this, and it could cause confusion. This is a pre-existing issue noted in agent memory.

2. **POSTGRES_ADMIN credentials injected to all pods.** The shared `prowler.env` helper (lines 99-108 in `_helpers.tpl`) injects `POSTGRES_ADMIN_USER` and `POSTGRES_ADMIN_PASSWORD` into every pod (API, worker, worker-beat, init containers, CronJob). Only the API needs admin credentials (for migrations). Workers and beat should use the regular `POSTGRES_USER`/`POSTGRES_PASSWORD`. This is a privilege escalation vector if a worker pod is compromised.

3. **Neo4j password in plaintext in values.yaml.** While `values.yaml` line 687 has `password: ""` (empty default triggers auto-generation), the comment says `--set neo4j.auth.password=yourpassword`. This encourages passing secrets via Helm command line, which stores them in Helm release secrets and shell history. Should recommend external secret management instead.

4. **Chart.yaml missing `dependencies` block.** The `Chart.lock` exists referencing PostgreSQL and Valkey subchart dependencies, but `Chart.yaml` has no `dependencies:` section. This causes `helm lint` to fail. (Pre-existing issue, noted in agent memory.)

5. **`values.schema.json` does not cover `extraEnv`/`extraEnvFrom`/`lifecycle`/`digest` fields.** If items 4, 7, or 13 are implemented, the schema must be updated in the same PR. The schema currently does not use `additionalProperties: false`, so new fields will not be rejected, but they also will not be validated.

---

## Summary Verdict Table

| # | Title | Claimed Priority | Verified Priority | Bug Exists? | Fix Correct? |
|---|---|---|---|---|---|
| 1 | HPA scaleTargetRef | P0 (bug) | **P0 (bug)** | Yes | Yes |
| 2 | Missing startupProbe | P0 | **P1** (downgraded) | Yes | Yes |
| 3 | Worker-beat health check | P0 | **P1** (downgraded) | Yes | Partially (doc-only) |
| 4 | No extraEnv/extraEnvFrom | P1 | **P1** | Yes | Mostly (envFrom merge detail) |
| 5 | Celery concurrency | P1 | **P1** | Yes | Correct (upstream required) |
| 6 | Worker-beat Recreate | P1 | **P1** | Yes | Yes |
| 7 | No preStop hook | P1 | **P1** | Yes | Yes (doc + template) |
| 8 | CronJob race condition | P1 | **P1** | Yes | Partially (see corrections) |
| 9 | CronJob inherits SA | HIGH | **HIGH** | Yes | Yes |
| 10 | Key generator supply chain | HIGH | **HIGH** | Yes | Yes (prefer Job elimination) |
| 11 | SA automount defaults | MEDIUM | **MEDIUM** | Yes | Yes (BREAKING) |
| 12 | Network policy issues | MEDIUM | **MEDIUM** | Yes | Yes (BREAKING) |
| 13 | No image digest support | MEDIUM | **MEDIUM** | Yes | Yes |
| 14 | Neo4j no ServiceAccount | MEDIUM | **MEDIUM** | Yes | Yes |
| 15 | Worker-beat termGrace | P2 | **P2** | Yes | Yes |
| 16 | Hardcoded secret names | P2 | **P2** | Yes | Yes |
| 17 | Neo4j missing PDB/grace | P2 | **P2** | Yes | Yes |
| 18 | Recovery script logging | P2 | **P2** | Yes | Yes |
| 19 | DJANGO_ALLOWED_HOSTS | LOW | **LOW** | Yes | Partially (doc-only) |
| 20 | Test pod hardening | LOW | **LOW** | Yes | Yes |
| 21 | Worker netpol egress | LOW | **LOW** | Yes | Yes (with corrections) |

**All 21 items verified as real issues.** Two items (#2, #3) are downgraded from P0 to P1. No items are disputed. Four items have fix corrections or additions (#4 envFrom merge, #8 race condition nuance, #10 prefer Job elimination, #21 CNI semantics). Two items (#11, #12) involve breaking changes requiring migration documentation.

Five additional issues were identified that are not in the change request document.
