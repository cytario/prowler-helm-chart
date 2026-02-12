# Scan Recovery Review Notes (2026-02-12)

## Critical Findings
1. **Multi-replica race condition**: With replicaCount: 2, init containers on both pods ping simultaneously, find zero workers, and may mark actively-starting scans as failed. The "idempotent, no conflict" claim in the doc is wrong -- a fast-starting replica B could accept a new scan task while replica A's init container is still running recovery.
2. **Valkey unreachable = destructive**: The exception handler falls through to `active_workers = 0` which kills all executing scans. Should be inverted to skip recovery on broker unreachability.

## Template Gaps
- Init container snippet missing: explicit securityContext, resources, full env/envFrom block, djangoConfigKeys secret
- CronJob snippet missing: all security hardening, concurrencyPolicy, history limits, serviceAccountName
- No shared helper template for env blocks (duplication across 3 deployments already exists)

## Recommended Approach
- CronJob with configurable threshold is safest for multi-replica
- Init container needs PostgreSQL advisory lock or single-replica guard if pursued
- Upstream `acks_late` is correct but requires scan idempotency verification
