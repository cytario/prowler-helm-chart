# Prowler Helm Chart v1.4.0 -- Implementation Plan

Based on review of [helm-chart-change-requests.md](./helm-chart-change-requests.md) against
chart source at `charts/prowler/` (chart v1.3.5, appVersion 5.17.1).

---

## Table of Contents

- [Priority Review and Reassessment](#priority-review-and-reassessment)
- [Upstream Dependencies](#upstream-dependencies)
- [Phase 1: Bug Fixes (P0)](#phase-1-bug-fixes-p0) -- Items 1, 6
- [Phase 2: Probes and Health Checks (P0)](#phase-2-probes-and-health-checks-p0) -- Items 2, 3
- [Phase 3: Security -- HIGH (SA isolation, key-gen)](#phase-3-security-high) -- Items 9, 10, 14
- [Phase 4: Extensibility (extraEnv, configurable secrets)](#phase-4-extensibility) -- Items 4, 16
- [Phase 5: Worker Lifecycle (preStop, concurrency, beat grace)](#phase-5-worker-lifecycle) -- Items 5, 7, 15
- [Phase 6: Security -- MEDIUM (automount, digests, netpol)](#phase-6-security-medium) -- Items 11, 12, 13, 21
- [Phase 7: Hardening and Polish (P2/LOW)](#phase-7-hardening-and-polish) -- Items 17, 18, 19, 20
- [Phase 8: Scan Recovery Hardening](#phase-8-scan-recovery-hardening) -- Item 8
- [Breaking Changes Summary](#breaking-changes-summary)
- [Version Bump Strategy](#version-bump-strategy)

---

## Priority Review and Reassessment

### Agreements with Proposed Priorities

| # | Title | Proposed | Agreed? |
|---|-------|----------|---------|
| 1 | HPA scaleTargetRef bug | P0 (bug) | **Yes.** Silent no-op for any HPA user. |
| 2 | Missing startupProbe rendering | P0 | **Yes.** No workaround possible via values alone. |
| 6 | Worker-beat missing Recreate strategy | P1 | **Upgrade to P0.** Duplicate beat causes duplicate scans on every upgrade. |
| 9 | CronJob inherits worker SA | HIGH | **Yes.** Privilege escalation risk. |
| 10 | Key generator supply chain risk | HIGH | **Yes.** Runs on every install/upgrade. |

### Disagreements / Adjustments

| # | Title | Proposed | My Rating | Rationale |
|---|-------|----------|-----------|-----------|
| 3 | Worker-beat health check | P0 | **P1.** The default is `livenessProbe: {}` which means no probe is rendered (the `{{- with }}` block produces nothing for an empty map). This is not broken -- it is absent. Adding a working probe requires knowing whether Prowler's beat writes a pidfile. This is an enhancement, not a fix for broken behavior. The 17-hour outage cited is real but the fix depends on upstream image behavior. |
| 5 | Worker concurrency | P1 | **P1, but chart-side is limited.** The real fix is in `docker-entrypoint.sh`. The chart can only expose the env var via `extraEnv` (item 4) or `djangoConfig`. See [Upstream Dependencies](#upstream-dependencies). |
| 8 | CronJob race condition | P1 | **P2.** The CronJob is disabled by default and the threshold (7200s) is deliberately high. The `inspect().active()` check proposed in the doc adds Celery broker dependency to the CronJob, which partially negates the benefit of having a time-only fallback. A safer fix is the optimistic concurrency guard alone. |
| 11 | SA automount defaults | MEDIUM | **P1.** Zero-effort fix (change 3 boolean defaults). High security return. |
| 19 | DJANGO_ALLOWED_HOSTS wildcard | LOW | **Not recommended.** Changing this default will break existing installations where operators have not set up ingress hosts. Django behind an API gateway (common in K8s) needs `*` or the internal service name. Documenting the risk in comments is sufficient. |

### Items That Should NOT Be Implemented (or Need Reframing)

**Item 19 -- DJANGO_ALLOWED_HOSTS change:** Do NOT change the default from `"*"`. Instead,
add a comment in `values.yaml` explaining the security trade-off. The auto-populate-from-ingress
idea is clever but fragile (workers and beat do not use ingress hosts, and internal service
names would need to be added too). Leave as documentation-only.

**Item 6 -- Remove worker_beat HPA:** The change request suggests "consider removing
`templates/worker_beat/hpa.yaml`." Do NOT remove it. Removing a template is a breaking change
for anyone who has it in their values override (even if disabled). Instead, add a guard that
caps `maxReplicas` at 1 and add a comment. Or better: leave the HPA template as-is but add
a `NOTES.txt` warning when `worker_beat.autoscaling.enabled: true` and `maxReplicas > 1`.

---

## Upstream Dependencies

These items require changes to the Prowler container image, not just the Helm chart:

| # | What's Needed | Chart-Side Workaround |
|---|---------------|-----------------------|
| 3 | Confirmation of beat pidfile/schedule file path | Document `pgrep -f 'celery.*beat'` as recommended probe in values.yaml comments |
| 5 | `docker-entrypoint.sh` must read `CELERY_WORKER_CONCURRENCY` env var | Expose the env var via `extraEnv` (item 4). If the entrypoint ignores it, it has no effect. |
| 7 | Confirmation of `acks_late` behavior, scan-during-shutdown handling | Add `lifecycle` rendering to template. Document unknowns in values.yaml comments. |

---

## Phase 1: Bug Fixes (P0)

**PR title:** `fix: HPA scaleTargetRef names and worker-beat Recreate strategy`
**Risk:** Low -- fixes broken behavior, no behavioral change for existing users (HPAs are disabled by default; beat is already 1 replica)
**Backward compatible:** Yes

### Item 1 -- HPA scaleTargetRef Bug

All four HPA templates have `name: {{ include "prowler.fullname" . }}` on line 12.
The metadata `name` on line 5 is correct (includes suffix), but `scaleTargetRef.name` is wrong.

**Files to modify:**

#### `templates/api/hpa.yaml` -- line 12

```yaml
# BEFORE:
    name: {{ include "prowler.fullname" . }}
# AFTER:
    name: {{ include "prowler.fullname" . }}-api
```

#### `templates/worker/hpa.yaml` -- line 12

```yaml
# BEFORE:
    name: {{ include "prowler.fullname" . }}
# AFTER:
    name: {{ include "prowler.fullname" . }}-worker
```

#### `templates/worker_beat/hpa.yaml` -- line 12

```yaml
# BEFORE:
    name: {{ include "prowler.fullname" . }}
# AFTER:
    name: {{ include "prowler.fullname" . }}-worker-beat
```

#### `templates/ui/hpa.yaml` -- line 12

```yaml
# BEFORE:
    name: {{ include "prowler.fullname" . }}
# AFTER:
    name: {{ include "prowler.fullname" . }}-ui
```

### Item 6 -- Worker-Beat Recreate Strategy + Singleton Guard

The worker-beat deployment uses the default `RollingUpdate` strategy. During upgrades,
the old and new beat pods overlap, causing duplicate task scheduling.

**Files to modify:**

#### `templates/worker_beat/deployment.yaml` -- add strategy after line 9

```yaml
spec:
  {{- if not .Values.worker_beat.autoscaling.enabled }}
  replicas: {{ .Values.worker_beat.replicaCount }}
  {{- end }}
  # Recreate strategy is required because Celery Beat must be a singleton.
  # RollingUpdate would momentarily run two beat schedulers, causing duplicate task dispatch.
  strategy:
    type: Recreate
  selector:
```

#### `templates/worker_beat/hpa.yaml` -- add maxReplicas guard

```yaml
{{- if .Values.worker_beat.autoscaling.enabled }}
{{- if gt (int .Values.worker_beat.autoscaling.maxReplicas) 1 }}
{{- fail "worker_beat.autoscaling.maxReplicas must be 1 -- Celery Beat must be a singleton to prevent duplicate task scheduling" }}
{{- end }}
```

#### `values.yaml` -- worker_beat section comments

```yaml
worker_beat:
  # IMPORTANT: Celery Beat must run as a singleton (exactly one replica).
  # Running multiple beat instances causes duplicate task scheduling.
  # The deployment uses strategy: Recreate to prevent overlap during upgrades.
  replicaCount: 1
```

### Testing

```bash
# Verify HPA names
helm template prowler charts/prowler/ --set api.autoscaling.enabled=true \
  --set worker.autoscaling.enabled=true \
  --set ui.autoscaling.enabled=true \
  | grep -A5 "scaleTargetRef"

# Verify beat strategy
helm template prowler charts/prowler/ | grep -A2 "strategy:"

# Verify beat HPA guard
helm template prowler charts/prowler/ \
  --set worker_beat.autoscaling.enabled=true \
  --set worker_beat.autoscaling.maxReplicas=2 2>&1 | grep -i "singleton"
# Should fail with error message

# Lint
helm lint charts/prowler/
```

---

## Phase 2: Probes and Health Checks (P0)

**PR title:** `feat: add startupProbe rendering and beat health check guidance`
**Risk:** Low -- additive only, empty defaults preserve current behavior
**Backward compatible:** Yes

### Item 2 -- Add startupProbe Rendering to Worker, Worker-Beat, UI

The API deployment already renders `startupProbe` via `{{- with .Values.api.startupProbe }}`.
Worker, worker-beat, and UI templates are missing this block.

**Files to modify:**

#### `templates/worker/deployment.yaml` -- after readinessProbe block (line 106)

Add between the readinessProbe and resources blocks:

```yaml
          {{- with .Values.worker.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.worker.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.worker.resources }}
```

#### `templates/worker_beat/deployment.yaml` -- after readinessProbe block (line 69)

```yaml
          {{- with .Values.worker_beat.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.worker_beat.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.worker_beat.resources }}
```

#### `templates/ui/deployment.yaml` -- after readinessProbe block (line 67)

```yaml
          {{- with .Values.ui.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.ui.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.ui.resources }}
```

#### `values.yaml` -- add startupProbe to each component

Worker section (after `readinessProbe: {}` at line 498):

```yaml
  # Startup probe - useful for slow-starting workers (broker connection, task registration)
  # Celery workers can take 30-120s to initialize. On new Karpenter nodes, add image pull time.
  # Example:
  #   startupProbe:
  #     exec:
  #       command: ["/bin/sh", "-c", "celery -A config.celery inspect ping --timeout 5"]
  #     failureThreshold: 30
  #     periodSeconds: 10
  startupProbe: {}
```

Worker-beat section (after `readinessProbe: {}` at line 636):

```yaml
  # Startup probe for beat scheduler
  # Example:
  #   startupProbe:
  #     exec:
  #       command: ["/bin/sh", "-c", "pgrep -f 'celery.*beat' > /dev/null"]
  #     failureThreshold: 30
  #     periodSeconds: 10
  startupProbe: {}
```

UI section (after `readinessProbe` block at line 146):

```yaml
  # Startup probe for UI (Next.js build/startup can take 10-30s)
  # Example:
  #   startupProbe:
  #     httpGet:
  #       path: /
  #       port: http
  #     failureThreshold: 30
  #     periodSeconds: 10
  startupProbe: {}
```

### Item 3 -- Worker-Beat Health Check Guidance

The fix here is documentation in `values.yaml`, not a default probe. We do not know the
exact Prowler beat process name or pidfile path without upstream confirmation.

#### `values.yaml` -- worker_beat section, replace lines 634-636

```yaml
  # Health probes for Celery Beat scheduler
  #
  # WARNING: The commonly suggested "celery inspect ping" does NOT verify beat --
  # it pings workers via the broker. If workers respond but beat is dead, the probe passes.
  # A reliable beat probe must check something beat-specific.
  #
  # Recommended approach (verify process name matches your Prowler version):
  #   livenessProbe:
  #     exec:
  #       command: ["/bin/sh", "-c", "pgrep -f 'celery.*beat' > /dev/null"]
  #     initialDelaySeconds: 120
  #     periodSeconds: 60
  #     failureThreshold: 3
  #
  # Alternative if Prowler's beat writes a schedule file:
  #   livenessProbe:
  #     exec:
  #       command:
  #         - /bin/sh
  #         - -c
  #         - |
  #           # Fail if schedule file hasn't been touched in 5 minutes
  #           find /tmp -name 'celerybeat-schedule' -mmin -5 | grep -q .
  #     initialDelaySeconds: 120
  #     periodSeconds: 60
  #     failureThreshold: 3
  livenessProbe: {}
  readinessProbe: {}
```

### Testing

```bash
# Verify startupProbe renders when set
helm template prowler charts/prowler/ \
  --set 'worker.startupProbe.exec.command[0]=/bin/sh' \
  --set 'worker.startupProbe.failureThreshold=30' \
  | grep -A5 "startupProbe"

# Verify empty startupProbe produces no output
helm template prowler charts/prowler/ | grep "startupProbe" | wc -l
# Should only show API and neo4j startupProbes (the ones with defaults)

helm lint charts/prowler/
```

---

## Phase 3: Security -- HIGH

**PR title:** `fix(security): isolate CronJob SA, pin key-gen image, add Neo4j ServiceAccount`
**Risk:** Medium -- changes ServiceAccount bindings and image references
**Backward compatible:** Yes (fallback to existing SA when not configured)

### Item 9 -- Dedicated CronJob ServiceAccount

The scan recovery CronJob currently uses `prowler.worker.serviceAccountName` which carries
IRSA/Pod Identity annotations for cloud scanning. The CronJob only queries PostgreSQL.

**Files to create/modify:**

#### New: `templates/worker/serviceaccount-scan-recovery.yaml`

```yaml
{{- if and .Values.worker.scanRecoveryCronJob.enabled .Values.worker.scanRecoveryCronJob.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "prowler.scanRecovery.serviceAccountName" . }}
  labels:
    {{- include "prowler.labels" . | nindent 4 }}
    app.kubernetes.io/component: scan-recovery
  {{- with .Values.worker.scanRecoveryCronJob.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.worker.scanRecoveryCronJob.serviceAccount.automount }}
{{- end }}
```

#### `templates/_helpers.tpl` -- add new helper

```yaml
{{/*
Create the name of the scan recovery CronJob service account to use.
Falls back to the worker service account for backward compatibility.
*/}}
{{- define "prowler.scanRecovery.serviceAccountName" -}}
{{- if .Values.worker.scanRecoveryCronJob.serviceAccount.create }}
{{- default (printf "%s-%s" (include "prowler.fullname" .) "scan-recovery") .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- else if .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- .Values.worker.scanRecoveryCronJob.serviceAccount.name }}
{{- else }}
{{- include "prowler.worker.serviceAccountName" . }}
{{- end }}
{{- end }}
```

#### `templates/worker/cronjob-scan-recovery.yaml` -- line 28

```yaml
# BEFORE:
          serviceAccountName: {{ include "prowler.worker.serviceAccountName" . }}
# AFTER:
          serviceAccountName: {{ include "prowler.scanRecovery.serviceAccountName" . }}
```

#### `values.yaml` -- under `worker.scanRecoveryCronJob` section

```yaml
  scanRecoveryCronJob:
    enabled: false
    # ...existing fields...
    # ServiceAccount for the CronJob.
    # By default, creates a dedicated SA without cloud scanning IAM privileges.
    # Set create: false and name: "" to fall back to the worker ServiceAccount (not recommended).
    serviceAccount:
      create: true
      # Do not mount K8s API token -- CronJob only needs PostgreSQL access
      automount: false
      annotations: {}
      # Override the auto-generated name
      name: ""
```

### Item 10 -- Pin Key Generator Image + Remove apt-get

The key generator Job uses `bitnami/kubectl:latest` and runs `apt-get install openssl`
at runtime. This is a supply chain risk.

**Improvement over proposed fix:** Instead of just pinning the image, we can eliminate the
`apt-get install` entirely. The `bitnami/kubectl` image is Debian-based and recent versions
(1.28+) include `openssl` pre-installed. Alternatively, we can use pure `bash` + `kubectl`
to avoid the `openssl` dependency, but that makes key generation less portable. The cleanest
approach: use a dedicated image value and pin to a known version.

**Files to modify:**

#### `values.yaml` -- under `api.djangoConfigKeys` section

```yaml
  djangoConfigKeys:
    # Create secret with Django Keys using a Helm pre-install/pre-upgrade Job.
    # For production, generate keys manually (see comments below).
    create: true
    # Image used by the key generation Job.
    # Must include kubectl and openssl binaries.
    image:
      repository: bitnami/kubectl
      tag: "1.31.4"
      pullPolicy: IfNotPresent
```

#### `templates/api/job-generate-keys.yaml` -- lines 33-36, 58

Replace the image line:

```yaml
# BEFORE:
        image: bitnami/kubectl:latest
# AFTER:
        image: "{{ .Values.api.djangoConfigKeys.image.repository }}:{{ .Values.api.djangoConfigKeys.image.tag }}"
        imagePullPolicy: {{ .Values.api.djangoConfigKeys.image.pullPolicy }}
```

Replace the securityContext to enable readOnlyRootFilesystem:

```yaml
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          capabilities:
            drop:
            - ALL
```

Remove the `apt-get` line and update the script. The `bitnami/kubectl:1.31.4` image
includes `openssl`. If a future image does not, users can override the image value.

```yaml
        command:
        - sh
        - -c
        - |
          set -e
          echo "Checking if Django keys secret already exists..."

          # Check if secret exists
          if kubectl get secret {{ $secretName }} -n {{ .Release.Namespace }} 2>/dev/null; then
            echo "Secret already exists. Skipping key generation."
            exit 0
          fi

          echo "Generating new Django keys..."

          # Generate RSA key pair for JWT signing
          openssl genrsa -out /tmp/private.pem 2048 2>/dev/null
          openssl rsa -in /tmp/private.pem -pubout -out /tmp/public.pem 2>/dev/null

          # Generate Fernet encryption key (32 bytes base64 encoded)
          ENCRYPTION_KEY=$(openssl rand -base64 32)

          # Read the keys
          PRIVATE_KEY=$(cat /tmp/private.pem)
          PUBLIC_KEY=$(cat /tmp/public.pem)

          # Create the secret using kubectl
          kubectl create secret generic {{ $secretName }} \
            -n {{ .Release.Namespace }} \
            --from-literal=DJANGO_TOKEN_SIGNING_KEY="$PRIVATE_KEY" \
            --from-literal=DJANGO_TOKEN_VERIFYING_KEY="$PUBLIC_KEY" \
            --from-literal=DJANGO_SECRETS_ENCRYPTION_KEY="$ENCRYPTION_KEY"

          echo "Django keys generated and secret created successfully."

          # Clean up
          rm -f /tmp/private.pem /tmp/public.pem
```

Note: The `readOnlyRootFilesystem: true` works because we only write to `/tmp` which is
an emptyDir volume mount already present in the template.

### Item 14 -- Neo4j ServiceAccount

The Neo4j deployment does not specify `serviceAccountName`, so Kubernetes assigns the
namespace `default` ServiceAccount.

**Files to create/modify:**

#### New: `templates/neo4j/serviceaccount.yaml`

```yaml
{{- if and .Values.neo4j.enabled .Values.neo4j.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "prowler.neo4j.fullname" . }}
  labels:
    {{- include "prowler.neo4j.labels" . | nindent 4 }}
  {{- with .Values.neo4j.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.neo4j.serviceAccount.automount }}
{{- end }}
```

#### `templates/neo4j/_helpers.tpl` -- add serviceAccountName helper

```yaml
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
```

#### `templates/neo4j/deployment.yaml` -- add serviceAccountName after imagePullSecrets

```yaml
      {{- with .Values.neo4j.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "prowler.neo4j.serviceAccountName" . }}
      {{- with .Values.neo4j.podSecurityContext }}
```

#### `values.yaml` -- add to neo4j section

```yaml
neo4j:
  # ...existing fields...
  # ServiceAccount for Neo4j
  serviceAccount:
    create: true
    # Neo4j does not need Kubernetes API access
    automount: false
    annotations: {}
    name: ""
```

### Testing

```bash
# Verify CronJob SA is separate from worker SA
helm template prowler charts/prowler/ \
  --set worker.scanRecoveryCronJob.enabled=true \
  | grep "serviceAccountName" | sort -u
# Should show: prowler-api, prowler-worker, prowler-worker-beat, prowler-ui,
#              prowler-scan-recovery, prowler-neo4j, prowler-key-generator

# Verify Neo4j SA renders
helm template prowler charts/prowler/ | grep -A3 "kind: ServiceAccount" | grep "prowler-neo4j"

# Verify key-gen image is pinned
helm template prowler charts/prowler/ | grep "bitnami/kubectl"
# Should show bitnami/kubectl:1.31.4, NOT :latest

# Verify readOnlyRootFilesystem on key-gen
helm template prowler charts/prowler/ | grep -B1 -A10 "generate-keys" | grep readOnlyRootFilesystem

helm lint charts/prowler/
```

---

## Phase 4: Extensibility

**PR title:** `feat: add extraEnv/extraEnvFrom support and configurable secret names`
**Risk:** Low -- additive, empty defaults preserve current behavior
**Backward compatible:** Yes

### Item 4 -- extraEnv / extraEnvFrom Support

**Files to modify (4 deployment templates + values.yaml):**

#### Template pattern (same for all four components)

After the existing `env:` block in each deployment template, add:

```yaml
          env:
            {{- include "prowler.env" . | nindent 12 }}
            {{- with .Values.<component>.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
```

And after `envFrom:`:

```yaml
          envFrom:
            {{- include "prowler.envFrom" . | nindent 12 }}
            {{- with .Values.<component>.extraEnvFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
```

For the **UI**, which has its own envFrom (not the shared helper), add after the existing
`envFrom:` block:

```yaml
          envFrom:
            - configMapRef:
                name: {{ include "prowler.fullname" . }}-ui
            - secretRef:
                name: {{ include "prowler.fullname" . }}-ui-auth
            {{- with .Values.ui.extraEnvFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
```

And add an `env:` block to UI (which currently has none):

```yaml
          {{- with .Values.ui.extraEnv }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
```

**Exact files and locations:**

| File | envFrom location | env location |
|------|-----------------|--------------|
| `templates/api/deployment.yaml` | line 63 | line 65 |
| `templates/worker/deployment.yaml` | line 96 | line 98 |
| `templates/worker_beat/deployment.yaml` | line 59 | line 61 |
| `templates/ui/deployment.yaml` | line 56 | (add new block after envFrom) |

#### `values.yaml` -- add to each component section

```yaml
  # Extra environment variables to add to <component> pods.
  # Useful for per-component overrides (e.g., CELERY_WORKER_CONCURRENCY on workers only).
  # Example:
  #   extraEnv:
  #     - name: MY_VAR
  #       value: "my-value"
  #     - name: MY_SECRET
  #       valueFrom:
  #         secretKeyRef:
  #           name: my-secret
  #           key: password
  extraEnv: []

  # Extra envFrom sources to add to <component> pods.
  # Example:
  #   extraEnvFrom:
  #     - configMapRef:
  #         name: my-extra-config
  #     - secretRef:
  #         name: my-extra-secret
  extraEnvFrom: []
```

Add these two blocks to `api`, `worker`, `worker_beat`, and `ui` sections.

### Item 16 -- Configurable Secret Names

The shared `prowler.env` helper in `_helpers.tpl` hardcodes `prowler-postgres-secret` and
`prowler-valkey-secret`.

**Files to modify:**

#### `values.yaml` -- add at top level (after `fullnameOverride`)

```yaml
# External secret names for PostgreSQL and Valkey connections.
# These secrets must exist in the release namespace before installing the chart.
# Override these if you use External Secrets Operator, Sealed Secrets, or any
# tool that creates secrets with custom names.
externalSecrets:
  postgres:
    # Name of the Kubernetes Secret containing PostgreSQL connection details
    secretName: prowler-postgres-secret
  valkey:
    # Name of the Kubernetes Secret containing Valkey/Redis connection details
    secretName: prowler-valkey-secret
```

#### `templates/_helpers.tpl` -- update `prowler.env` named template

Replace all occurrences of hardcoded secret names:

```yaml
{{- define "prowler.env" -}}
# PostgreSQL connection from external secret
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_HOST
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalSecrets.postgres.secretName }}
      key: POSTGRES_PORT
# ... (repeat for all 7 postgres keys and 4 valkey keys)
```

There are 7 `prowler-postgres-secret` references and 4 `prowler-valkey-secret` references
to replace with `{{ .Values.externalSecrets.postgres.secretName }}` and
`{{ .Values.externalSecrets.valkey.secretName }}` respectively.

#### `templates/NOTES.txt` -- update the secret creation instructions

Replace hardcoded names:

```yaml
kubectl create secret generic {{ .Values.externalSecrets.postgres.secretName }} -n {{ .Release.Namespace }} \
```

```yaml
kubectl create secret generic {{ .Values.externalSecrets.valkey.secretName }} -n {{ .Release.Namespace }} \
```

### Testing

```bash
# Verify extraEnv renders
helm template prowler charts/prowler/ \
  --set 'worker.extraEnv[0].name=CELERY_WORKER_CONCURRENCY' \
  --set 'worker.extraEnv[0].value=4' \
  | grep -A2 "CELERY_WORKER_CONCURRENCY"

# Verify custom secret names
helm template prowler charts/prowler/ \
  --set 'externalSecrets.postgres.secretName=my-pg-secret' \
  | grep "my-pg-secret"

# Verify default secret names still work
helm template prowler charts/prowler/ | grep "prowler-postgres-secret"

helm lint charts/prowler/
```

---

## Phase 5: Worker Lifecycle

**PR title:** `feat: worker lifecycle hooks, concurrency docs, and beat terminationGracePeriod`
**Risk:** Low -- documentation + optional configuration
**Backward compatible:** Yes

### Item 5 -- Worker Concurrency Documentation

This is primarily an upstream image change. The chart-side fix is to document how to use
`extraEnv` (from Phase 4) to set the concurrency.

#### `values.yaml` -- worker section, add comment above `command:`

```yaml
  # Celery worker concurrency.
  # By default, Celery uses multiprocessing.cpu_count() which reads the NODE CPU count,
  # not the pod's CPU limit. A pod with 2 CPU on a 16-core node spawns 16 workers.
  #
  # To override (requires Prowler image support for CELERY_WORKER_CONCURRENCY env var):
  #   extraEnv:
  #     - name: CELERY_WORKER_CONCURRENCY
  #       value: "4"
  #
  # Alternative: override the command/args to pass --concurrency directly:
  #   args:
  #     - worker
  #     - --concurrency=4
```

**Note:** The `args` override approach works today without any upstream changes, because
`docker-entrypoint.sh` passes args through to `celery worker`. Verify this by reading the
entrypoint in the Prowler image. If confirmed, we can document this as the primary approach.

### Item 7 -- Worker lifecycle + preStop + Documentation

#### `templates/worker/deployment.yaml` -- add lifecycle after args block (after line 94)

```yaml
          {{- with .Values.worker.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.worker.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
```

#### `values.yaml` -- worker section

```yaml
  # Container lifecycle hooks.
  # Use preStop to ensure Celery workers finish in-flight tasks before SIGTERM.
  #
  # How Celery worker shutdown works:
  #   1. Kubernetes sends SIGTERM to the container
  #   2. Celery enters "warm shutdown" -- stops accepting new tasks, finishes current ones
  #   3. If tasks don't finish within terminationGracePeriodSeconds, SIGKILL is sent
  #
  # IMPORTANT: Prowler uses acks_late=False by default (verify with your version).
  # This means tasks are ACKed on receipt, NOT on completion. If a worker is killed
  # mid-scan, the task is NOT retried -- the scan recovery mechanism handles this.
  #
  # The preStop hook adds a small delay before SIGTERM to allow the pod to be removed
  # from Service endpoints first (prevents new connections during shutdown).
  #
  # Example:
  #   lifecycle:
  #     preStop:
  #       exec:
  #         command: ["/bin/sh", "-c", "sleep 15"]
  #
  # Tune terminationGracePeriodSeconds to match your longest expected scan duration.
  # Default is 300s (5 minutes). For long-running scans, increase accordingly.
  lifecycle: {}
```

### Item 15 -- Worker-Beat terminationGracePeriodSeconds

#### `templates/worker_beat/deployment.yaml` -- add after `securityContext` block

```yaml
      {{- with .Values.worker_beat.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.worker_beat.terminationGracePeriodSeconds }}
      containers:
```

#### `values.yaml` -- worker_beat section (add after replicaCount)

```yaml
  # Time in seconds to allow beat pod to gracefully shut down.
  # Beat does not process long-running tasks, so the default K8s value (30s) is usually fine.
  terminationGracePeriodSeconds: 30
```

### Testing

```bash
# Verify lifecycle renders when set
helm template prowler charts/prowler/ \
  --set 'worker.lifecycle.preStop.exec.command[0]=/bin/sh' \
  --set 'worker.lifecycle.preStop.exec.command[1]=-c' \
  --set 'worker.lifecycle.preStop.exec.command[2]=sleep 15' \
  | grep -A5 "lifecycle"

# Verify terminationGracePeriodSeconds on beat
helm template prowler charts/prowler/ | grep "terminationGracePeriodSeconds"
# Should show 300 for worker, 30 for worker-beat

helm lint charts/prowler/
```

---

## Phase 6: Security -- MEDIUM

**PR title:** `fix(security): SA automount defaults, image digest support, network policy fixes`
**Risk:** Medium -- changes default values (automount), adds new template logic
**Backward compatible:** Partially -- changing automount defaults is a **behavioral change**

### Item 11 -- ServiceAccount automount Defaults

**Breaking change analysis:** Changing `automount: true` to `automount: false` for UI,
worker-beat, and worker will break installations that depend on the K8s API token being
available (e.g., Pod Identity webhook on EKS/AKS that requires the projected token volume).

However, the principle of least privilege dictates that components that do not need K8s
API access should not mount tokens. The Worker is the borderline case -- it needs API
access only if scanning Kubernetes resources.

**Recommendation:**

| Component | Current | Proposed | Rationale |
|-----------|---------|----------|-----------|
| api | `true` | `true` | Needs K8s API for RBAC scanning |
| worker | `true` | `true` | May need K8s API for scanning; IRSA/Pod Identity needs projected token |
| worker_beat | `true` | `false` | Only talks to Valkey/PostgreSQL |
| ui | `true` | `false` | Only serves Next.js frontend |

#### `values.yaml` changes

```yaml
# ui section:
  serviceAccount:
    create: true
    # UI does not need Kubernetes API access
    automount: false

# worker_beat section:
  serviceAccount:
    create: true
    # Beat scheduler does not need Kubernetes API access.
    # Set to true only if using Pod Identity webhook that requires projected tokens.
    automount: false
```

Leave `api` and `worker` at `automount: true`.

### Item 13 -- Image Digest Support

Add an `image` helper to `_helpers.tpl` and use it across all deployment templates.

#### `templates/_helpers.tpl` -- add image helper

```yaml
{{/*
Render a container image reference, preferring digest over tag.
Usage: {{ include "prowler.image" (dict "imageConfig" .Values.api.image "defaultTag" .Chart.AppVersion) }}
*/}}
{{- define "prowler.image" -}}
{{- if .imageConfig.digest -}}
{{ .imageConfig.repository }}@{{ .imageConfig.digest }}
{{- else -}}
{{ .imageConfig.repository }}:{{ .imageConfig.tag | default .defaultTag }}
{{- end -}}
{{- end }}
```

#### Update all deployment templates

Replace image lines in each template:

```yaml
# BEFORE (in api, worker, worker_beat deployments):
          image: "{{ .Values.<component>.image.repository }}:{{ .Values.<component>.image.tag | default .Chart.AppVersion }}"
# AFTER:
          image: "{{ include "prowler.image" (dict "imageConfig" .Values.<component>.image "defaultTag" .Chart.AppVersion) }}"
```

For **neo4j** (which does not use `.Chart.AppVersion` as default):

```yaml
# BEFORE:
          image: "{{ .Values.neo4j.image.repository }}:{{ .Values.neo4j.image.tag }}"
# AFTER:
          image: "{{ include "prowler.image" (dict "imageConfig" .Values.neo4j.image "defaultTag" .Values.neo4j.image.tag) }}"
```

Also update: init container in `worker/deployment.yaml`, CronJob in `worker/cronjob-scan-recovery.yaml`.

**Files:** 6 image references across:
- `templates/api/deployment.yaml` (line 48)
- `templates/worker/deployment.yaml` (lines 53, 85)
- `templates/worker_beat/deployment.yaml` (line 48)
- `templates/ui/deployment.yaml` (line 49)
- `templates/neo4j/deployment.yaml` (line 49)
- `templates/worker/cronjob-scan-recovery.yaml` (line 40)

#### `values.yaml` -- add `digest: ""` to every image block

```yaml
  image:
    repository: prowlercloud/prowler-api
    pullPolicy: IfNotPresent
    tag: ""
    # Immutable image reference. When set, takes precedence over tag.
    # Example: sha256:abc123...
    digest: ""
```

Add to: `api.image`, `worker.image`, `worker_beat.image`, `ui.image`, `neo4j.image`.

### Item 12 -- Network Policy Fixes (Partial)

This is a large item. Split into two sub-PRs if needed.

**Sub-item 12a: Fix copy-paste errors and add per-component toggles**

#### `values.yaml` -- add networkPolicy to worker, worker_beat, ui

```yaml
# Under worker:
  networkPolicy:
    enabled: false
    # Additional egress rules
    egress: []

# Under worker_beat:
  networkPolicy:
    enabled: false
    # Additional egress rules
    egress: []

# Under ui:
  networkPolicy:
    enabled: false
    # Additional ingress rules
    ingress: []
    # Additional egress rules
    egress: []
```

#### Fix template guards

Each network policy template currently uses `{{- if .Values.api.networkPolicy.enabled -}}`.

| Template | Current Guard | Correct Guard |
|----------|--------------|---------------|
| `templates/api/networkpolicy.yaml` | `api.networkPolicy.enabled` | `api.networkPolicy.enabled` (correct) |
| `templates/worker/networkpolicy.yaml` | `api.networkPolicy.enabled` | `worker.networkPolicy.enabled` |
| `templates/worker_beat/networkpolicy.yaml` | `api.networkPolicy.enabled` | `worker_beat.networkPolicy.enabled` |
| `templates/ui/networkpolicy.yaml` | `api.networkPolicy.enabled` | `ui.networkPolicy.enabled` |

#### Fix copy-paste value references

`templates/ui/networkpolicy.yaml` lines 20-22 and 41-43:

```yaml
# BEFORE:
  {{- with .Values.api.networkPolicy.ingress }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  ...
  {{- with .Values.api.networkPolicy.egress }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
# AFTER:
  {{- with .Values.ui.networkPolicy.ingress }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  ...
  {{- with .Values.ui.networkPolicy.egress }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
```

`templates/worker/networkpolicy.yaml` lines 56-58:

```yaml
# BEFORE:
  {{- with .Values.api.networkPolicy.egress }}
# AFTER:
  {{- with .Values.worker.networkPolicy.egress }}
```

`templates/worker_beat/networkpolicy.yaml` lines 36-38:

```yaml
# BEFORE:
  {{- with .Values.api.networkPolicy.egress }}
# AFTER:
  {{- with .Values.worker_beat.networkPolicy.egress }}
```

**Sub-item 12b: Neo4j and CronJob network policies (deferred)**

Neo4j and CronJob network policies are new templates and can be added separately. Not
blocking for v1.4.0.

#### New: `templates/neo4j/networkpolicy.yaml`

```yaml
{{- if and .Values.neo4j.enabled .Values.neo4j.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "prowler.neo4j.fullname" . }}
  labels:
    {{- include "prowler.neo4j.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "prowler.neo4j.selectorLabels" . | nindent 6 }}
  policyTypes:
  - Ingress
  ingress:
  # Allow Bolt protocol from API and Worker only
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "prowler.fullname" . }}-api
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "prowler.fullname" . }}-worker
    ports:
    - protocol: TCP
      port: {{ .Values.neo4j.service.port }}
    - protocol: TCP
      port: {{ .Values.neo4j.service.httpPort }}
  {{- with .Values.neo4j.networkPolicy.ingress }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
```

Add to `values.yaml` neo4j section:

```yaml
  networkPolicy:
    enabled: false
    ingress: []
```

### Item 21 -- Worker Network Policy Imprecise Egress

The `namespaceSelector: {}` for ports 443 and 6443 only matches in-cluster destinations,
not external cloud APIs.

#### `templates/worker/networkpolicy.yaml` -- fix cloud API egress rules

```yaml
  # Allow egress to cloud provider APIs for scanning (any external destination on 443)
  - ports:
    - protocol: TCP
      port: 443
  # Allow egress to Kubernetes API server (any external destination on 6443)
  - ports:
    - protocol: TCP
      port: 6443
```

Note: Removing the `to:` block entirely means "allow to any destination on this port."
This is the correct intent for cloud API scanning. The `namespaceSelector: {}` only
matches pods in the cluster.

### Backward Compatibility Notes for Phase 6

1. **automount changes:** Users who depend on `automount: true` for UI or worker-beat
   (rare) will need to add an override. Document in CHANGELOG.
2. **networkPolicy toggle migration:** Users who set `api.networkPolicy.enabled: true`
   expecting all network policies to activate will now need to set each component's
   `networkPolicy.enabled: true`. Document as breaking change in CHANGELOG.
3. **Image digest:** Purely additive. `digest: ""` means no change.

### Testing

```bash
# Verify per-component network policy toggles
helm template prowler charts/prowler/ \
  --set worker.networkPolicy.enabled=true \
  --set ui.networkPolicy.enabled=false \
  | grep "kind: NetworkPolicy" -A3

# Verify digest overrides tag
helm template prowler charts/prowler/ \
  --set 'api.image.digest=sha256:abcdef1234567890' \
  | grep "prowlercloud/prowler-api@sha256"

# Verify automount defaults
helm template prowler charts/prowler/ \
  | grep -B5 "automountServiceAccountToken"

helm lint charts/prowler/
```

---

## Phase 7: Hardening and Polish

**PR title:** `chore: Neo4j PDB, structured logging, test pod hardening, allowed_hosts docs`
**Risk:** Low
**Backward compatible:** Yes

### Item 17 -- Neo4j terminationGracePeriodSeconds and PDB

#### `templates/neo4j/deployment.yaml` -- add terminationGracePeriodSeconds

```yaml
      {{- with .Values.neo4j.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.neo4j.terminationGracePeriodSeconds }}
      containers:
```

#### New: `templates/neo4j/poddisruptionbudget.yaml`

```yaml
{{- if and .Values.neo4j.enabled .Values.neo4j.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "prowler.neo4j.fullname" . }}
  labels:
    {{- include "prowler.neo4j.labels" . | nindent 4 }}
spec:
  {{- if .Values.neo4j.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.neo4j.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.neo4j.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.neo4j.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "prowler.neo4j.selectorLabels" . | nindent 6 }}
{{- end }}
```

#### `values.yaml` -- neo4j section

```yaml
neo4j:
  # ...existing fields...

  # Grace period for Neo4j shutdown. Neo4j needs time to flush transactions and
  # close the store lock. Default 120s covers most index build and transaction scenarios.
  terminationGracePeriodSeconds: 120

  # Pod Disruption Budget - protects the RWO PVC singleton during voluntary disruptions.
  # In Karpenter environments, prevents eviction with insufficient grace period.
  podDisruptionBudget:
    enabled: false
    minAvailable: 1
    # maxUnavailable: 0
```

### Item 18 -- Scan Recovery Structured Logging

Replace `print()` calls with Python `logging` using JSON formatter.

#### `templates/worker/configmap-scan-recovery.yaml` -- replace script

Replace the full Python script with structured logging. Key changes:

```python
    import django
    import json
    import logging
    import os
    import sys
    import time

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.django.production")
    django.setup()

    from config.celery import celery_app as app  # noqa: E402
    from datetime import timedelta  # noqa: E402
    from django.utils import timezone  # noqa: E402
    from api.models import Scan  # noqa: E402


    class JsonFormatter(logging.Formatter):
        def format(self, record):
            log_entry = {
                "timestamp": self.formatTime(record),
                "level": record.levelname,
                "message": record.getMessage(),
                "logger": "scan-recovery",
            }
            if hasattr(record, "extra_data"):
                log_entry.update(record.extra_data)
            return json.dumps(log_entry)


    logger = logging.getLogger("scan-recovery")
    logger.setLevel(logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger.addHandler(handler)

    RECOVERY_MODE = os.environ.get("RECOVERY_MODE", "init")
    GRACE_PERIOD_SECONDS = int(os.environ.get("GRACE_PERIOD_SECONDS", "600"))
    THRESHOLD_SECONDS = int(os.environ.get("THRESHOLD_SECONDS", "7200"))


    def check_broker_connectivity():
        """Verify Valkey/broker is reachable before making recovery decisions."""
        try:
            conn = app.connection()
            conn.ensure_connection(max_retries=3, interval_start=1, interval_step=1)
            conn.close()
            return True
        except Exception as e:
            logger.error("Cannot connect to broker", extra={"extra_data": {"error": str(e)}})
            return False


    def count_active_workers():
        """Ping Celery workers and return the count of those responding."""
        try:
            response = app.control.ping(timeout=5.0)
            return len(response) if response else 0
        except Exception as e:
            logger.warning("Could not ping workers", extra={"extra_data": {"error": str(e)}})
            return 0


    def recover_scans(queryset, reason):
        """Mark matching scans as failed and log summary with scan IDs."""
        count = queryset.count()
        if count:
            scan_ids = list(queryset.values_list("id", flat=True)[:50])
            queryset.filter(state="executing").update(state="failed", completed_at=timezone.now())
            logger.info(
                "Recovered orphaned scans",
                extra={"extra_data": {
                    "count": count,
                    "reason": reason,
                    "scan_ids": [str(sid) for sid in scan_ids],
                }},
            )
        else:
            logger.info("No orphaned scans found")
        return count


    def init_mode():
        """Init container recovery: check workers, then recover if none active."""
        if not check_broker_connectivity():
            logger.warning("Broker unreachable -- skipping recovery (cannot verify worker state)")
            sys.exit(0)

        active = count_active_workers()
        if active > 0:
            logger.info("Workers still active -- skipping recovery", extra={"extra_data": {"active_workers": active}})
            sys.exit(0)

        logger.info("No active workers detected -- recovering orphaned scans")
        qs = Scan.objects.filter(state="executing")
        if GRACE_PERIOD_SECONDS > 0:
            cutoff = timezone.now() - timedelta(seconds=GRACE_PERIOD_SECONDS)
            qs = qs.filter(started_at__lt=cutoff)
            logger.info("Applying grace period", extra={"extra_data": {"cutoff": cutoff.isoformat(), "grace_seconds": GRACE_PERIOD_SECONDS}})
        recover_scans(qs, "init container recovery")


    def cronjob_mode():
        """CronJob recovery: use time threshold to find stuck scans."""
        if not check_broker_connectivity():
            logger.warning("Broker unreachable -- skipping recovery")
            sys.exit(0)

        threshold = timedelta(seconds=THRESHOLD_SECONDS)
        cutoff = timezone.now() - threshold
        qs = Scan.objects.filter(state="executing", started_at__lt=cutoff)
        recover_scans(qs, f"stuck longer than {threshold}")


    if __name__ == "__main__":
        logger.info("Starting scan recovery", extra={"extra_data": {"mode": RECOVERY_MODE}})
        if RECOVERY_MODE == "cronjob":
            cronjob_mode()
        else:
            init_mode()
```

Note: The `recover_scans` function now includes the **optimistic concurrency guard** from
item 8: `queryset.filter(state="executing").update(...)` instead of `queryset.update(...)`.
This prevents overwriting a scan whose state changed between query and update. This is a
safe, low-risk improvement that partially addresses item 8.

### Item 19 -- DJANGO_ALLOWED_HOSTS Documentation

Do NOT change the default. Add a comment:

#### `values.yaml` -- djangoConfig section

```yaml
    # SECURITY: Wildcard allows any Host header. In production, restrict to your actual
    # domain(s) to prevent Host header injection attacks:
    #   DJANGO_ALLOWED_HOSTS: "prowler.example.com,prowler-api.prowler.svc.cluster.local"
    # Note: Internal service names must be included for pod-to-pod communication.
    DJANGO_ALLOWED_HOSTS: "*"
```

### Item 20 -- Test Pod Hardening

#### `templates/tests/test-api-connection.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "prowler.fullname" . }}-test-api-connection
  labels:
    {{- include "prowler.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: wget
      image: busybox:1.37.0
      command: ['wget']
      args: ['{{ include "prowler.fullname" . }}-api:{{ .Values.api.service.port }}/api/v1/docs']
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 65534
        capabilities:
          drop:
            - ALL
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  restartPolicy: Never
```

#### `templates/tests/test-ui-connection.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "prowler.fullname" . }}-test-ui-connection
  labels:
    {{- include "prowler.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command: ['sh', '-c']
      args:
        - |
          HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://{{ include "prowler.fullname" . }}-ui:{{ .Values.ui.service.port }}/)
          echo "HTTP Status: $HTTP_CODE"
          # Accept 2xx, 3xx as success (UI is working, redirects are expected)
          if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
            exit 0
          else
            exit 1
          fi
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 65534
        capabilities:
          drop:
            - ALL
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  restartPolicy: Never
```

### Testing

```bash
# Verify Neo4j PDB renders
helm template prowler charts/prowler/ \
  --set neo4j.podDisruptionBudget.enabled=true \
  | grep -A10 "PodDisruptionBudget" | grep "neo4j"

# Verify test pod images are pinned
helm template prowler charts/prowler/ | grep "busybox\|curlimages"
# Should show busybox:1.37.0 and curlimages/curl:8.11.1

# Verify test pods have securityContext
helm template prowler charts/prowler/ --show-only templates/tests/test-api-connection.yaml

helm lint charts/prowler/
```

---

## Phase 8: Scan Recovery Hardening

**PR title:** `fix: scan recovery optimistic concurrency guard`
**Risk:** Low -- the guard is additive and prevents a race condition
**Backward compatible:** Yes

### Item 8 -- Partial Fix (Optimistic Concurrency Only)

The full fix proposed in the change request (adding `inspect().active()` to CronJob mode)
is not recommended because:

1. It adds a Celery broker dependency to the CronJob, which is supposed to be a simple
   time-threshold fallback.
2. `inspect().active()` only shows tasks currently being processed, not tasks in transit.
   There is still a race window.
3. The optimistic concurrency guard (`filter(state="executing").update(...)`) is simpler,
   safer, and covers the most dangerous case (overwriting a scan that already completed).

The optimistic concurrency fix is already included in Phase 7's structured logging rewrite.
The key change in the `recover_scans` function:

```python
# BEFORE:
    queryset.update(state="failed", completed_at=timezone.now())
# AFTER:
    queryset.filter(state="executing").update(state="failed", completed_at=timezone.now())
```

This re-filters on `state="executing"` at UPDATE time, so a scan that transitioned to
`completed` between the original query and the update will not be overwritten.

**No additional changes needed beyond Phase 7.**

---

## Breaking Changes Summary

| Phase | Item | Change | Migration |
|-------|------|--------|-----------|
| 6 | 11 | `worker_beat.serviceAccount.automount` default `true` -> `false` | Add `worker_beat.serviceAccount.automount: true` to values override if needed |
| 6 | 11 | `ui.serviceAccount.automount` default `true` -> `false` | Add `ui.serviceAccount.automount: true` to values override if needed |
| 6 | 12 | Network policies now per-component toggle | If using `api.networkPolicy.enabled: true`, also set `worker.networkPolicy.enabled: true`, etc. |
| 4 | 16 | Secret names configurable (default unchanged) | No action needed -- defaults match current hardcoded names |

---

## Version Bump Strategy

### Chart Version: 1.3.5 -> 1.4.0

Rationale for minor version bump (not major):
- No changes to the fundamental chart structure
- All breaking changes have backward-compatible defaults or trivial migration
- New features are additive (extraEnv, digest, lifecycle)
- The automount and networkPolicy changes are the only behavioral changes and both
  affect non-default configurations (network policies were disabled; automount on
  beat/UI is rarely needed)

If the automount changes are deemed too risky, they can be deferred to 2.0.0 and
the rest can ship as 1.4.0.

### Implementation Order

| PR | Phase | Items | Est. Effort |
|----|-------|-------|-------------|
| 1 | Phase 1 | 1, 6 | Small (1-2h) |
| 2 | Phase 2 | 2, 3 | Small (1-2h) |
| 3 | Phase 3 | 9, 10, 14 | Medium (3-4h) |
| 4 | Phase 4 | 4, 16 | Medium (3-4h) |
| 5 | Phase 5 | 5, 7, 15 | Small (1-2h) |
| 6 | Phase 6 | 11, 12, 13, 21 | Large (4-6h) |
| 7 | Phase 7 | 17, 18, 19, 20 | Medium (2-3h) |
| 8 | Phase 8 | 8 | Included in Phase 7 |

**Total estimated effort:** 15-23 hours

Phases 1 and 2 should be merged first (bug fixes). Phases 3-7 can be parallelized
across developers if needed, as they have no inter-dependencies (except Phase 5 item 5
benefits from Phase 4 item 4 being merged first for the `extraEnv` mechanism).

---

## JSON Schema Considerations

The chart includes `values.schema.json`. Every new value added to `values.yaml` must
also be reflected in the JSON schema, or `helm install --verify` will fail.

Items that add new schema keys:
- Phase 3: `worker.scanRecoveryCronJob.serviceAccount.*`, `api.djangoConfigKeys.image.*`, `neo4j.serviceAccount.*`
- Phase 4: `*.extraEnv`, `*.extraEnvFrom`, `externalSecrets.*`
- Phase 5: `worker.lifecycle`, `worker_beat.terminationGracePeriodSeconds`
- Phase 6: `*.image.digest`, `worker.networkPolicy.*`, `worker_beat.networkPolicy.*`, `ui.networkPolicy.*`, `neo4j.networkPolicy.*`
- Phase 7: `neo4j.terminationGracePeriodSeconds`, `neo4j.podDisruptionBudget.*`

Each phase PR must include the corresponding `values.schema.json` updates.
