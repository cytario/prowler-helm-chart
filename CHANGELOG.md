# Changelog

All notable changes to this project will be documented in this file.

## [3.1.0](https://github.com/cytario/prowler-helm-chart/compare/v3.0.4...v3.1.0) (2026-02-15)

### Features

* simplify chart, wire Celery tuning values, bump to 5.18.2 ([fceeaab](https://github.com/cytario/prowler-helm-chart/commit/fceeaabfd38d03ab3fab908e02a92b877b99af2e))

## [3.0.4](https://github.com/cytario/prowler-helm-chart/compare/v3.0.3...v3.0.4) (2026-02-15)

### Bug Fixes

* default worker concurrency to 1 to prevent OOM on large accounts ([663be5e](https://github.com/cytario/prowler-helm-chart/commit/663be5e6ee5929bf1078f45db1bf6436811ed3f4))

## [3.0.3](https://github.com/cytario/prowler-helm-chart/compare/v3.0.2...v3.0.3) (2026-02-14)

### Bug Fixes

* disable Neo4j strict config validation for APOC plugin compat ([e19db6d](https://github.com/cytario/prowler-helm-chart/commit/e19db6db84c976f2c51dfd3c4574299b5152442b))

## [3.0.2](https://github.com/cytario/prowler-helm-chart/compare/v3.0.1...v3.0.2) (2026-02-14)

### Bug Fixes

* remove unsupported dbms.default_database and dbms.max_databases env vars ([f79c7b4](https://github.com/cytario/prowler-helm-chart/commit/f79c7b4fecdbfbb6078714c6d7226decbb1c0988))

## [3.0.1](https://github.com/cytario/prowler-helm-chart/compare/v3.0.0...v3.0.1) (2026-02-14)

### Bug Fixes

* revert Neo4j env vars to dbms_* prefix for DozerDB compatibility ([6856b50](https://github.com/cytario/prowler-helm-chart/commit/6856b50d794171d50e28c5c948f529f22d22bb24))

## [3.0.0](https://github.com/cytario/prowler-helm-chart/compare/v2.0.3...v3.0.0) (2026-02-14)

### ⚠ BREAKING CHANGES

* Neo4j memory env vars renamed for 5.x compatibility
* api.rbac config moved to worker.rbac
* remove worker-beat HPA and add singleton fail guard
* worker.concurrency defaults to 2, bypassing the
entrypoint. Set worker.concurrency to null to restore previous
behavior. Default worker memory limits changed from 512Mi/2Gi to
2Gi/4Gi.

### Features

* add worker concurrency control to prevent OOM evictions ([8e26fcf](https://github.com/cytario/prowler-helm-chart/commit/8e26fcf6f1f63b73f4ee5415d1c8f482b2b46f96))

### Bug Fixes

* add configurable netpol ports and conditional Neo4j egress ([6d0dfbe](https://github.com/cytario/prowler-helm-chart/commit/6d0dfbe6082148315367b3dc11f100ff211d5fc3))
* correct Neo4j 5.x environment variable naming ([144f625](https://github.com/cytario/prowler-helm-chart/commit/144f6254f53e877aa321c76891019276b870adba))
* move RBAC from API to Worker ServiceAccount ([f966463](https://github.com/cytario/prowler-helm-chart/commit/f9664635966225609882fdaf6503b002e7dcf38c))
* remove deprecated annotations, duplicate values, and stale docs ([418d511](https://github.com/cytario/prowler-helm-chart/commit/418d5119b97db80d56249f3836a3570ec6c8ce81))
* remove worker-beat HPA and add singleton fail guard ([32a1e76](https://github.com/cytario/prowler-helm-chart/commit/32a1e76e9cd43421b87eb333f14b8f914d29321c))

### Code Refactoring

* DRY shared-storage and topology spread into helpers ([af4df7e](https://github.com/cytario/prowler-helm-chart/commit/af4df7e72cc0a42c4325c50275eb5f9eba3d8173))

## [2.0.3](https://github.com/cytario/prowler-helm-chart/compare/v2.0.2...v2.0.3) (2026-02-13)

### Bug Fixes

* replace pgrep/celery probe examples with /proc-based checks ([121012b](https://github.com/cytario/prowler-helm-chart/commit/121012b5f34de94edf1f5deb0012c1b63f581f73))

## [2.0.2](https://github.com/cytario/prowler-helm-chart/compare/v2.0.1...v2.0.2) (2026-02-13)

### Bug Fixes

* avoid using separate kubectl image ([e7af682](https://github.com/cytario/prowler-helm-chart/commit/e7af682e66ee8be99cba37130b5e22a616e08acd))

## [2.0.1](https://github.com/cytario/prowler-helm-chart/compare/v2.0.0...v2.0.1) (2026-02-13)

### Bug Fixes

* avoid using separate kubectl image ([719e57b](https://github.com/cytario/prowler-helm-chart/commit/719e57bdb1b536fef1e85bb7ce9788fb59f20518))

## [2.0.0](https://github.com/cytario/prowler-helm-chart/compare/v1.3.5...v2.0.0) (2026-02-13)

### ⚠ BREAKING CHANGES

* ui.serviceAccount.automount and
worker_beat.serviceAccount.automount now default to false. Network
policies are now per-component (worker.networkPolicy.enabled,
ui.networkPolicy.enabled, worker_beat.networkPolicy.enabled) instead
of the single api.networkPolicy.enabled toggle. Scan recovery script
now outputs structured JSON logs instead of plain text.

### Features

* comprehensive chart hardening, security fixes, and extensibility ([1e236eb](https://github.com/cytario/prowler-helm-chart/commit/1e236eb77b4dbcf0581bf387b5c6dabe6882b57d))

## [1.3.5](https://github.com/cytario/prowler-helm-chart/compare/v1.3.4...v1.3.5) (2026-02-12)

### Bug Fixes

* **neo4j:** use Recreate strategy to prevent RWO PVC store lock deadlock ([b444f67](https://github.com/cytario/prowler-helm-chart/commit/b444f671b8d8b3db8a98952ce2ed55730c3e3515))

## [1.3.4](https://github.com/cytario/prowler-helm-chart/compare/v1.3.3...v1.3.4) (2026-02-12)

### Bug Fixes

* **worker:** bump scan recovery resource limits to prevent OOMKill ([14cc1a9](https://github.com/cytario/prowler-helm-chart/commit/14cc1a900ff096ff3f92378c9c0551acedbb5385))

## [1.3.3](https://github.com/cytario/prowler-helm-chart/compare/v1.3.2...v1.3.3) (2026-02-12)

### Bug Fixes

* **chart:** review fixes from chart guardian and helm architect ([558f427](https://github.com/cytario/prowler-helm-chart/commit/558f4278582f8a173e5e4ef738ea3de4279bd1d4))

## [1.3.2](https://github.com/cytario/prowler-helm-chart/compare/v1.3.1...v1.3.2) (2026-02-12)

### Bug Fixes

* **worker:** fix scan recovery script import and PYTHONPATH ([11bc182](https://github.com/cytario/prowler-helm-chart/commit/11bc182d49d5247bf1bcd60c9a928c2ac7841a37))

## [1.3.1](https://github.com/cytario/prowler-helm-chart/compare/v1.3.0...v1.3.1) (2026-02-12)

### Bug Fixes

* **worker:** set PYTHONPATH for scan recovery script ([64cff9c](https://github.com/cytario/prowler-helm-chart/commit/64cff9c8ca942949f8d2d028fa575dde511f6394))

## [1.3.0](https://github.com/cytario/prowler-helm-chart/compare/v1.2.0...v1.3.0) (2026-02-12)

### Features

* **worker:** add scan recovery and refactor shared env helpers ([b4636c2](https://github.com/cytario/prowler-helm-chart/commit/b4636c2bb41306dfb6d501911c87151df741fb88))

## [1.2.0](https://github.com/cytario/prowler-helm-chart/compare/v1.1.5...v1.2.0) (2026-02-09)

### Features

* **neo4j:** make health probes configurable via values.yaml ([572eb00](https://github.com/cytario/prowler-helm-chart/commit/572eb00a91519476de5f593c144da23f9e409776))

## [1.1.5](https://github.com/cytario/prowler-helm-chart/compare/v1.1.4...v1.1.5) (2026-02-02)

### Bug Fixes

* correct AppVersion badge to 5.17.1 ([c49b910](https://github.com/cytario/prowler-helm-chart/commit/c49b91012dd8de27fcf8b6b39c07afc02bc00ae6))

### Code Refactoring

* **ci:** consolidate version updates in semantic-release only ([a449354](https://github.com/cytario/prowler-helm-chart/commit/a449354f813c08a1fefd718dfb6d4c7e6b20f77e))

## [1.1.4](https://github.com/cytario/prowler-helm-chart/compare/v1.1.3...v1.1.4) (2026-02-02)

### Bug Fixes

* correct AppVersion badge to 5.17.1 ([27e10da](https://github.com/cytario/prowler-helm-chart/commit/27e10da7d7adbe985dc0d0434c8c80fb7e20f4f1))

## [1.1.3](https://github.com/cytario/prowler-helm-chart/compare/v1.1.2...v1.1.3) (2026-02-02)

### Bug Fixes

* **ci:** stop overwriting appVersion, auto-update README badges ([02ff584](https://github.com/cytario/prowler-helm-chart/commit/02ff584a893a2591aa52bdc55a7791f5ee07147d))

## [1.1.2](https://github.com/cytario/prowler-helm-chart/compare/v1.1.1...v1.1.2) (2026-02-02)

### Documentation

* remove Artifact Hub links, add AWS EFS troubleshooting ([b29544a](https://github.com/cytario/prowler-helm-chart/commit/b29544a3ba3032cf30227aca595c171b7f6114f5))

## [1.1.1](https://github.com/cytario/prowler-helm-chart/compare/v1.1.0...v1.1.1) (2026-02-02)

### Documentation

* update URLs to cytario, add OCI instructions, bump to v1.1.0 ([7502d5e](https://github.com/cytario/prowler-helm-chart/commit/7502d5e7e8db93963123ae62890c33c8eeb30de1))

## [1.1.0](https://github.com/cytario/prowler-helm-chart/compare/v1.0.0...v1.1.0) (2026-01-29)

### Features

* add Neo4j (DozerDB) support for Attack Paths feature ([119121b](https://github.com/cytario/prowler-helm-chart/commit/119121ba4dfa4442c091d52ec29e5234a6034b22))
* auto-generate Neo4j password if not provided ([5753d46](https://github.com/cytario/prowler-helm-chart/commit/5753d46e2506f8ce1073f43dc6028cd38d37347c))

### Documentation

* add Neo4j documentation to all markdown files ([f045b63](https://github.com/cytario/prowler-helm-chart/commit/f045b634494b49bbdbf99ae0465b176e4c173a92))

## 1.0.0 (2025-11-24)

### Features

* add production-ready features, CI/CD and documentation ([1dd07cd](https://github.com/cytario/prowler-helm-chart/commit/1dd07cd6c75e3671ca1b0368f2cefb8473da041b))
* Clean up Chart.yaml ([ceb8c01](https://github.com/cytario/prowler-helm-chart/commit/ceb8c019a5c54265ec8c330aaaf36e756f54347a))
* env var setup + workers command fix ([0013b03](https://github.com/cytario/prowler-helm-chart/commit/0013b030c599bd71c7d228eb137463669c70ce32))
* Initial Prowler components ([cb4cb94](https://github.com/cytario/prowler-helm-chart/commit/cb4cb942120cd9955a683b09cef2e2b0deb78f7d))
* Setup env vars for configuration ([9246c51](https://github.com/cytario/prowler-helm-chart/commit/9246c51f44526aa816dff2d318939dfb3521e574))

### Bug Fixes

* Add ArtifactHub badge to README, README inside Chart and fix images URLs ([8850b60](https://github.com/cytario/prowler-helm-chart/commit/8850b60df38d8b9bad83091b56e9b9949dc42971))
* add git sync step before semantic-release ([7c9cad6](https://github.com/cytario/prowler-helm-chart/commit/7c9cad6fa219b8622f83c3f65ea22b564769a25a))
* add packages write permission to release workflow ([9f57cbd](https://github.com/cytario/prowler-helm-chart/commit/9f57cbd5c40447c4f0aa9c414a7bf6ca8c46fabe))
* add required secrets instructions to NOTES.txt ([7de94bf](https://github.com/cytario/prowler-helm-chart/commit/7de94bfad4fe5fb917cf0b31b9ad310a6ff6ff5f))
* Chart release github action ([b02c715](https://github.com/cytario/prowler-helm-chart/commit/b02c715d2dd3afd9c152bb99a8fd2b865e7afc3e))
* ensure semantic-release uses latest main branch ([4c82c56](https://github.com/cytario/prowler-helm-chart/commit/4c82c56039ddfca2e3200fc002aa688a46db59a7))
* typo in Chart.yaml ([10e1bd5](https://github.com/cytario/prowler-helm-chart/commit/10e1bd584b1dcba1487e2d2b13114a6ef456dd2f))
* update repository URL to SSH format ([d2f4a1b](https://github.com/cytario/prowler-helm-chart/commit/d2f4a1b6e8c6251c9c6b30c75a9f9072832a0685))
* valkey standalone mode + ServiceAccount setups ([a242ab3](https://github.com/cytario/prowler-helm-chart/commit/a242ab380b47e083e5f1342ff4b93bfa0f238046))

### Documentation

* update examples and documentation for new secret names ([2262fb7](https://github.com/cytario/prowler-helm-chart/commit/2262fb7f61e5190f5f2759f7037473f9409f6598))

### Code Refactoring

* remove chart dependencies and use external secrets ([9d5f5c0](https://github.com/cytario/prowler-helm-chart/commit/9d5f5c02fc8942fb2ff7c570e84e8357d1c20723))

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** This changelog is automatically generated by [semantic-release](https://github.com/semantic-release/semantic-release).
> Manual edits to this file will be overwritten on the next release.

## [Unreleased]

### Added
- Comprehensive CONTRIBUTING.md with development guidelines
- License file at repository root for better visibility
- Initial CHANGELOG.md for tracking release history

### Fixed
- Django key generation now creates real RSA keys instead of fake templates
- Worker Beat deployment stability with proper PostgreSQL authentication
- MicroK8s addon validation in start.sh script

### Security
- Pre-install job for secure key generation with RBAC
- All components run with security contexts (non-root, dropped capabilities)
- Network policies available for enhanced security

---

## Previous Releases

For information about releases prior to this changelog, please see:
- [GitHub Releases](https://github.com/cytario/prowler-helm-chart/releases)
- [Chart.yaml annotations](charts/prowler/Chart.yaml) for recent changes
