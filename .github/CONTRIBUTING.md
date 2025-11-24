# Contributing to Prowler Helm Chart

Thank you for your interest in contributing to the Prowler Helm Chart! We welcome contributions from the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Contribution Workflow](#contribution-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Environment details** (Kubernetes version, Helm version, cloud provider)
- **Relevant logs** (sanitized of sensitive information)
- **Chart version** you're using

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title and description**
- **Use case** - why is this enhancement needed?
- **Proposed solution** - how should it work?
- **Alternatives considered**
- **Impact** on existing users

### Contributing Code

We welcome pull requests for:

- Bug fixes
- New features
- Documentation improvements
- Test coverage improvements
- Performance improvements

## Development Setup

### Prerequisites

- **Kubernetes cluster** (minikube, kind, or k3s for local development)
- **Helm 3.0+** installed
- **kubectl** configured
- **Git** for version control

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/promptlylabs/prowler-helm-chart.git
   cd prowler-helm-chart
   ```

2. **Install dependencies:**
   ```bash
   cd charts/prowler
   helm dependency update
   ```

3. **Test locally:**
   ```bash
   # From repository root
   ./start.sh  # Interactive mode
   # or
   ./start.sh --yes  # Auto-approve mode
   ```

4. **View logs:**
   ```bash
   ./logs.sh
   ```

5. **Clean up:**
   ```bash
   ./stop.sh
   ```

### Linting and Validation

Before submitting a PR, ensure your changes pass all checks:

```bash
# Helm lint
helm lint charts/prowler

# Chart testing
ct lint --config ct.yaml --charts charts/prowler

# Template validation
helm template prowler charts/prowler --set postgresql.global.postgresql.auth.postgresPassword=test

# Kubeval validation
helm template prowler charts/prowler --set postgresql.global.postgresql.auth.postgresPassword=test | \
  kubeval --kubernetes-version 1.29.0 --strict --ignore-missing-schemas
```

## Contribution Workflow

1. **Fork the repository** to your GitHub account
2. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
3. **Make your changes** following the coding standards
4. **Test thoroughly** - ensure nothing breaks
5. **Commit your changes** using conventional commits
6. **Push to your fork**
7. **Create a Pull Request** against the `main` branch

## Coding Standards

### Helm Template Best Practices

1. **Use helpers** for repeated logic:
   ```yaml
   {{- include "prowler.labels" . | nindent 4 }}
   ```

2. **Indent consistently** (2 spaces)

3. **Use `toYaml` for complex structures:**
   ```yaml
   {{- with .Values.nodeSelector }}
   nodeSelector:
     {{- toYaml . | nindent 8 }}
   {{- end }}
   ```

4. **Add conditions** for optional features:
   ```yaml
   {{- if .Values.feature.enabled }}
   # Feature configuration
   {{- end }}
   ```

5. **Document values** with inline comments in `values.yaml`

### File Organization

- Component-specific templates in subdirectories (`api/`, `ui/`, `worker/`)
- Shared resources at template root
- Helper templates in `_helpers.tpl` files
- Tests in `templates/tests/`

### Security

- **Never hardcode secrets** in templates
- **Use secure defaults** (empty passwords, auto-generated keys)
- **Apply security contexts** to all pods
- **Run as non-root** user
- **Drop all capabilities** unless specifically needed
- **Use seccomp profiles** (RuntimeDefault)

### Resource Management

- **Define resource limits** for all containers
- **Use sensible defaults** for requests
- **Document resource requirements** in comments

## Testing

### Required Tests

1. **Helm Lint:**
   ```bash
   helm lint charts/prowler
   ```

2. **Template Rendering:**
   ```bash
   helm template prowler charts/prowler --set postgresql.global.postgresql.auth.postgresPassword=test
   ```

3. **Helm Tests:**
   ```bash
   helm test prowler -n prowler
   ```

4. **Local Deployment:**
   - Install the chart locally
   - Verify all pods start successfully
   - Test basic functionality (login, API access)

### Test Scenarios

Ensure your changes work with:

- Default values
- Production-like configuration
- External databases
- Network policies enabled
- High availability setup

## Documentation

### What to Document

1. **New features** - Add to README.md and Chart.yaml changelog
2. **Configuration options** - Document in values.yaml with comments
3. **Breaking changes** - Highlight in PR description and UPGRADING.md
4. **Examples** - Provide usage examples for new features

### Documentation Standards

- Use clear, concise language
- Include code examples
- Provide context and rationale
- Update all affected documentation files

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation changes
- **style:** Code style changes (formatting, no logic change)
- **refactor:** Code refactoring
- **test:** Adding or updating tests
- **chore:** Maintenance tasks, dependency updates
- **ci:** CI/CD changes
- **perf:** Performance improvements

### Examples

```
feat(api): add support for custom ingress annotations

Add ability to specify custom annotations for API ingress resource
to support various ingress controllers.

Closes #123
```

```
fix(worker): resolve memory leak in celery worker

Workers were not properly closing database connections, causing
memory growth over time. This fix ensures connections are released.

Fixes #456
```

```
docs: add troubleshooting guide for common issues

Created comprehensive troubleshooting guide covering:
- Database connection issues
- Pod startup failures
- Migration problems
```

### Breaking Changes

If your commit introduces breaking changes, add `BREAKING CHANGE:` in the footer:

```
feat(storage)!: change default shared storage to PVC

BREAKING CHANGE: The default value for sharedStorage.type has changed
from emptyDir to persistentVolumeClaim. Users upgrading will need to
either configure external storage or explicitly set type to emptyDir.

Migration guide: docs/UPGRADING.md#v1-to-v2
```

## Pull Request Process

### Before Submitting

- [ ] Code follows the project's coding standards
- [ ] All tests pass locally
- [ ] Documentation has been updated
- [ ] Commit messages follow conventional commits
- [ ] PR description clearly explains the changes

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
How has this been tested?

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally

## Related Issues
Closes #issue_number
```

### Review Process

1. **Automated checks** will run (lint, test, validate)
2. **Maintainer review** - may request changes
3. **Address feedback** - push additional commits
4. **Final approval** - maintainer approves PR
5. **Merge** - maintainer merges when ready

### After Merge

- PR will be automatically closed
- Changes will be included in next release
- Semantic versioning determines version bump
- CHANGELOG will be automatically updated

## Branch Naming Convention

Use descriptive branch names:

- `feature/add-monitoring-dashboard`
- `fix/worker-crash-on-startup`
- `docs/update-installation-guide`
- `chore/update-dependencies`
- `refactor/simplify-helper-templates`

See: [Git Branch Naming Conventions](https://medium.com/@abhay.pixolo/naming-conventions-for-git-branches-a-cheatsheet-8549feca2534)

## Release Process

Releases are automated using semantic-release:

1. **Commits merged to main** trigger release workflow
2. **Semantic versioning** determines version bump based on commits
3. **CHANGELOG generated** automatically
4. **GitHub release created** with release notes
5. **Chart published** to Helm repository

See [PIPELINE.md](../PIPELINE.md) for detailed CI/CD documentation.

## Getting Help

- **Documentation:** Check [README.md](../README.md) and [docs/](../docs/)
- **Issues:** Search existing [GitHub Issues](https://github.com/promptlylabs/prowler-helm-chart/issues)
- **Discussions:** Use [GitHub Discussions](https://github.com/promptlylabs/prowler-helm-chart/discussions)
- **Security:** For security issues, see [SECURITY.md](../SECURITY.md)

## Recognition

Contributors will be:
- Listed in release notes
- Credited in commit messages
- Acknowledged in the community

Thank you for contributing to Prowler Helm Chart! 🎉
