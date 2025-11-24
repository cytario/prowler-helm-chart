# CI/CD Pipeline Documentation

This document describes the CI/CD pipeline setup for the Prowler Helm Chart.

## Overview

The pipeline is designed for Helm chart releases using semantic versioning. It consists of:
- **CI (Pull Requests)**: Quality checks only
- **CD (Main branch)**: Quality checks + Semantic release + Helm chart release

## Pipeline Structure

### 1. CI Workflow (`.github/workflows/ci.yml`)

Runs on pull requests to `main` branch.

**Jobs:**
- `qa-checks`: Runs Helm linting and validation

**Triggers:**
```yaml
on:
  pull_request:
    branches:
      - main
```

### 2. CD Workflow (`.github/workflows/cd.yml`)

Runs on push to `main` branch.

**Jobs:**
1. `qa-checks`: Runs Helm linting and validation
2. `release`: Creates semantic version and Helm chart release (only if QA passes)

**Triggers:**
```yaml
on:
  push:
    branches:
      - main
```

### 3. QA Checks Workflow (`.github/workflows/qa-checks.yml`)

Reusable workflow for quality assurance checks.

**Steps:**
1. Checkout repository
2. Set up Helm
3. Set up chart-testing tool
4. Build chart dependencies
5. Run `helm lint`
6. Run `ct lint` (chart-testing)
7. Run `helm template` (multiple configurations)
8. Validate Kubernetes manifests with kubeval

**What it validates:**
- Chart.yaml syntax and metadata
- Template syntax and rendering
- Values.yaml schema
- Kubernetes manifest validity
- Best practices compliance

### 4. Release Workflow (`.github/workflows/release.yml`)

Reusable workflow that handles versioning and releases.

**Jobs:**

#### Job 1: Semantic Release
1. Checkout repository
2. Install Node.js dependencies (semantic-release)
3. Run semantic-release to:
   - Analyze commits using conventional commits
   - Determine next version
   - Update Chart.yaml version
   - Update README badges
   - Generate CHANGELOG.md
   - Create GitHub release
   - Push changes back to repository

#### Job 2: Helm Chart Release (only if semantic release publishes)
1. Checkout repository
2. Configure Git
3. Set up Helm
4. Run chart-releaser to:
   - Package the Helm chart
   - Create GitHub release with chart artifact
   - Update GitHub Pages with chart index

**Outputs:**
- `version`: The new semantic version
- `published`: Whether a release was published

## Semantic Release Configuration

Configuration file: `.releaserc.yml`

### Commit Convention

Uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Release Rules

| Commit Type | Release Type | Description |
|-------------|--------------|-------------|
| `feat` | minor | New feature |
| `fix` | patch | Bug fix |
| `perf` | patch | Performance improvement |
| `docs` | patch | Documentation update |
| `refactor` | patch | Code refactoring |
| `security` | patch | Security fix |
| `revert` | patch | Revert previous change |
| `BREAKING CHANGE` | major | Breaking change |
| `chore` | none | Maintenance tasks |
| `test` | none | Test updates |
| `ci` | none | CI/CD updates |
| `build` | none | Build updates |

### Examples

```bash
# Patch release (0.0.2 -> 0.0.3)
git commit -m "fix: resolve django secret generation issue"

# Minor release (0.0.2 -> 0.1.0)
git commit -m "feat: add network policy templates"

# Major release (0.0.2 -> 1.0.0)
git commit -m "feat!: remove deprecated API endpoints

BREAKING CHANGE: The /v1/api endpoint has been removed. Use /v2/api instead."

# No release
git commit -m "chore: update dependencies"
```

## Chart Release Process

### Automatic Release (via GitHub Actions)

1. Push commits to `main` branch using conventional commit format
2. GitHub Actions workflow triggers:
   - QA checks run
   - Semantic release analyzes commits
   - If changes warrant release:
     - Chart.yaml version is updated
     - CHANGELOG.md is generated
     - GitHub release is created
     - Helm chart is packaged
     - Chart is published to GitHub Pages
     - Helm repository index is updated

### Manual Release (if needed)

```bash
# 1. Ensure you're on main branch
git checkout main
git pull

# 2. Run semantic release locally (requires GITHUB_TOKEN)
export GITHUB_TOKEN=your_token
npx semantic-release

# 3. The chart will be automatically released by the workflow
```

## Configuration Files

### `.releaserc.yml`
Semantic release configuration:
- Release branches (main, beta, alpha)
- Commit analysis rules
- Changelog generation
- Version updating in Chart.yaml and READMEs
- Git commit and push settings

### `ct.yaml`
Chart testing configuration:
- Remote repository (origin)
- Target branch (main)
- Chart directories
- External chart repositories (Bitnami)
- Validation settings

### `package.json`
Node.js dependencies for semantic-release:
- `@semantic-release/changelog` - Generate CHANGELOG.md
- `@semantic-release/commit-analyzer` - Analyze commits
- `@semantic-release/exec` - Execute shell commands
- `@semantic-release/git` - Commit and push changes
- `@semantic-release/github` - Create GitHub releases
- `@semantic-release/release-notes-generator` - Generate release notes
- `conventional-changelog-conventionalcommits` - Conventional commits preset
- `semantic-release` - Core semantic-release

## Helm Chart Publishing

### GitHub Pages Repository

The chart is published to GitHub Pages at:
```
https://<owner>.github.io/prowler-helm-chart
```

### Adding the Repository

Users can add the repository with:
```bash
helm repo add prowler-app https://<owner>.github.io/prowler-helm-chart
helm repo update
```

### Installing the Chart

```bash
helm install prowler prowler-app/prowler
```

## Workflow Permissions

### Required GitHub Token Permissions

The `GITHUB_TOKEN` used in workflows needs:
- `contents: write` - Push commits, create releases
- `issues: write` - Comment on released issues
- `pull-requests: write` - Comment on released PRs
- `pages: write` - Update GitHub Pages (if needed)

These are automatically granted to the workflow when configured correctly.

## Monitoring and Debugging

### Viewing Workflow Runs

1. Go to GitHub repository
2. Click "Actions" tab
3. Select workflow (CI or CD)
4. View run details and logs

### Job Summaries

Each workflow generates a summary visible in the Actions UI:
- QA Checks: Shows which checks passed/failed
- Semantic Release: Shows version and release URL
- Helm Release: Shows chart version and Pages URL

### Troubleshooting

**Issue: Semantic release doesn't create a release**
- Check commits follow conventional commit format
- Ensure commit types warrant a release (not `chore`, `test`, etc.)
- Verify you're on the `main` branch

**Issue: Helm chart not published**
- Check semantic release created a new version
- Verify GitHub Pages is enabled in repository settings
- Check `gh-pages` branch exists and is updated
- Review helm-release job logs

**Issue: QA checks failing**
- Run `helm lint charts/prowler` locally
- Run `helm template prowler charts/prowler` locally
- Check for syntax errors in templates
- Verify values.yaml is valid

## Local Development

### Running QA Checks Locally

```bash
# Lint the chart
helm lint charts/prowler

# Template the chart
helm template prowler charts/prowler

# Install chart-testing
brew install chart-testing

# Run chart-testing lint
ct lint --config ct.yaml --charts charts/prowler
```

### Testing Semantic Release

```bash
# Install dependencies
npm install

# Run semantic release in dry-run mode
npx semantic-release --dry-run

# This will show what would happen without making changes
```

## Best Practices

1. **Always use conventional commits** on the main branch
2. **Squash merge PRs** to keep commit history clean
3. **Include breaking changes** in commit message when needed
4. **Test locally** before pushing to main
5. **Review generated CHANGELOG** after releases
6. **Monitor workflow runs** for any failures

## Migration from Old Pipeline

The old pipeline included:
- Manual version bumping in Chart.yaml
- Manual CHANGELOG updates
- GPG signing (optional)
- ArtifactHub annotations

The new pipeline:
- Automatic version bumping via semantic-release
- Automatic CHANGELOG generation
- No GPG signing (can be added if needed)
- Simplified using helm-chart-releaser action
- Better integration with conventional commits workflow

## Next Steps

Consider adding:
1. **Chart testing with K8s cluster** - Use kind/minikube in CI
2. **Security scanning** - Add Snyk or Trivy for vulnerability scanning
3. **GPG signing** - Add chart signing for additional security
4. **Slack/Discord notifications** - Alert on releases
5. **Multi-environment deploys** - Separate staging/production releases
