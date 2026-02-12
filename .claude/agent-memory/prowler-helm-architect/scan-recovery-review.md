# Scan Recovery Feature - Architecture Review Notes

## Problem
Worker eviction (Karpenter, OOM, node failure) leaves scans stuck in `executing` state.
Root cause: Celery `acks_late=False` (task removed from Valkey on receipt, not completion).

## Proposed Approaches
1. **Init container** on worker deployment: pings broker, marks orphaned scans as failed
2. **CronJob**: periodic time-threshold based recovery
3. **Upstream fix**: `acks_late=True` in Prowler's celery.py (not a chart-only fix)

## Key Implementation Issues Found
- Doc's YAML snippet incomplete: missing djangoConfigKeys secretRef, api.secrets, securityContext, volume mounts
- Valkey-unreachable case MUST skip recovery (not proceed) to avoid marking active scans as failed
- Need DRY refactoring of env/envFrom blocks BEFORE adding init container (avoid 4th copy)
- CronJob needs its own NetworkPolicy if network policies enabled
- Missing terminationGracePeriodSeconds on worker (prevention > recovery)

## Implementation Order
Phase 1: Extract envFrom/env helpers + add terminationGracePeriodSeconds
Phase 2: Init container (enabled by default)
Phase 3: CronJob (disabled by default)
