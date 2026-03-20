# ⚛ Nucleus Verify — GitHub Action

Deterministic code verification with cryptographically signed certificates. Runs 681 static analysis operators and maps findings to 11 compliance frameworks (ISO 27001, DORA, FCA, PSD2, SWIFT CSP, OWASP, NIST, GDPR, HIPAA, PCI-DSS, SOC 2).

## Quick Start

```yaml
name: Verify
on: [push]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: Alter-Menta-Technologies/nucleus-verify-action@v1
        id: verify
        with:
          api_key: ${{ secrets.NUCLEUS_API_KEY }}

      - name: Check result
        run: echo "Verdict: ${{ steps.verify.outputs.verdict }}"
```

## Get an API Key

1. Sign up at [altermenta.com](https://altermenta.com)
2. Go to Dashboard → API Keys
3. Generate a key — save it securely
4. Add it as a GitHub secret: `Settings → Secrets → NUCLEUS_API_KEY`

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api_key` | Yes | — | Nucleus Verify API key (use `${{ secrets.NUCLEUS_API_KEY }}`) |
| `repo_url` | No | Current repo | Repository URL to verify |
| `fail_on_unverified` | No | `false` | Fail workflow if verdict is UNVERIFIED |
| `fail_on_findings` | No | `false` | Fail workflow if HIGH or CRITICAL findings exist |

## Outputs

| Output | Description |
|--------|-------------|
| `verdict` | `VERIFIED`, `PARTIAL`, or `UNVERIFIED` |
| `trust_score` | Trust score 0–100 |
| `certificate_url` | Public URL of the signed verification certificate |
| `findings_count` | Total number of security findings |
| `high_count` | Number of HIGH severity findings |
| `critical_count` | Number of CRITICAL severity findings |
| `proof_pack_url` | URL to download the cryptographic proof pack |

## Examples

### Block deployment on UNVERIFIED

```yaml
- uses: Alter-Menta-Technologies/nucleus-verify-action@v1
  with:
    api_key: ${{ secrets.NUCLEUS_API_KEY }}
    fail_on_unverified: true
```

### Block on HIGH/CRITICAL findings

```yaml
- uses: Alter-Menta-Technologies/nucleus-verify-action@v1
  with:
    api_key: ${{ secrets.NUCLEUS_API_KEY }}
    fail_on_findings: true
```

### Post certificate as PR comment

```yaml
- uses: Alter-Menta-Technologies/nucleus-verify-action@v1
  id: verify
  with:
    api_key: ${{ secrets.NUCLEUS_API_KEY }}

- uses: actions/github-script@v7
  if: github.event_name == 'pull_request'
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## ⚛ Nucleus Verify — ${{ steps.verify.outputs.verdict }}

        | | |
        |---|---|
        | **Trust Score** | ${{ steps.verify.outputs.trust_score }}/100 |
        | **Findings** | ${{ steps.verify.outputs.findings_count }} |
        | **Certificate** | [View →](${{ steps.verify.outputs.certificate_url }}) |`
      })
```

### Use in matrix strategy

```yaml
jobs:
  verify:
    strategy:
      matrix:
        repo: [frontend, backend, shared-lib]
    steps:
      - uses: Alter-Menta-Technologies/nucleus-verify-action@v1
        with:
          api_key: ${{ secrets.NUCLEUS_API_KEY }}
          repo_url: https://github.com/myorg/${{ matrix.repo }}
```

## What It Checks

- **5 verification gates**: validity, determinism, contract, build, structural
- **432 standard operators** across 31 families (security, supply chain, compliance, code quality, AI/LLM risks)
- **249 enhanced operators** (Business plan) including Semgrep, CVE database, secrets deep scan
- **11 compliance frameworks** mapped automatically

## How It Works

1. Submits your repository URL to the Nucleus Verify API
2. Polls for completion (max 10 minutes)
3. Outputs verdict, score, and certificate URL
4. Writes a job summary with results table
5. Optionally fails the workflow based on verdict or findings

No source code is retained. Clone → scan → delete.

## Links

- [Nucleus Verify](https://altermenta.com)
- [Enterprise](https://altermenta.com/enterprise)
- [Documentation](https://altermenta.com/benchmark)
- [Pricing](https://altermenta.com/#pricing)

---

© 2026 Alter Menta Technologies Ltd · London, EC1V 2NX · [altermenta.com](https://altermenta.com)
