# Brief Builder Security Assessment - Submission Package

**Submitted for:** Jasper Senior Security Engineer Take-Home Exercise  
**Candidate:**  Irving Starks

**Technical Recruiter:** Monty Gill  
**Due:** Within 3 business days  
**Status:** Complete

---

## 📦 Package Contents

### 1. **SECURITY_ASSESSMENT.md** (Main Submission)
- **Prioritized Risk Assessment Table** (8 items, ranked by impact)
- **Automated Control** (Conftest policy + GitHub Actions workflow)
- **Write-Up** (problem selection, approach, 2-week roadmap, compliance mapping, AI usage)
- **Critical Question** for Priya
- **Draft Slack Message** to stakeholder

**Page Count:** 3 pages (markdown equivalent)

### 2. **Code Artifacts**

#### `brief-builder-security.rego` (Conftest Policy)
- **Lines:** 100+
- **Purpose:** Automated policy-as-code validation of agent configuration and Terraform
- **Enforces:** 10 security rules covering secrets, prompt injection, IAM, logging, audit trails
- **Format:** OPA/Rego (runnable via `conftest test`)

#### `ci-security-gate.yml` (GitHub Actions Workflow)
- **Lines:** 140+
- **Purpose:** CI/CD security gate that runs on every PR to main
- **Functionality:**
  - Installs Conftest v0.53.0
  - Converts YAML/HCL to JSON
  - Runs security policy checks
  - Uploads results to GitHub Security tab (SARIF)
  - Comments on PR with policy pass/fail status
  - Includes Trufflehog secret scanning
- **Integration:** Drop into `.github/workflows/` directory

#### `agent.yaml.secure` (Corrected Configuration)
- **Lines:** 200+
- **Purpose:** Secure version of the agent configuration with all vulnerabilities fixed
- **Key Changes:**
  - Removed role bypass clause from system prompt
  - Per-user memory scope + 24h TTL (vs. global unbounded)
  - All dangerous tools require user confirmation
  - Email/URL allowlists
  - Enabled tool_calls and prompt_text logging
  - User identity + redaction for audit trail
  - Input sanitization for customer Zendesk tickets
  - Rate limiting per user/hour
- **Status:** Ready for prod (after secrets are rotated into Secret Manager)

#### `brief-builder.tf.secure` (Corrected Infrastructure)
- **Lines:** 350+
- **Purpose:** Secure Terraform with all infrastructure vulnerabilities fixed
- **Key Changes:**
  - Custom IAM role (least-privilege) vs. editor
  - Secrets moved from plaintext env vars → Google Secret Manager
  - Cloud Run restricted to authenticated users (vs. allUsers)
  - Workload Identity (no static service account keys)
  - Data Access audit logs enabled
  - Optional IAP (Identity-Aware Proxy) for OAuth
  - Structured logging with audit sink
- **Status:** Production-ready (requires 2-week secret rotation + IAM testing)

---

## 🚀 How to Use

### Option A: Run the Conftest Policy Locally

```bash
# Install Conftest
curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.53.0/conftest_0.53.0_Linux_x86_64.tar.gz | tar xz

# Test the original (vulnerable) config
conftest test -p brief-builder-security.rego config/agent.yaml infra/brief-builder.tf
# Expected result: Multiple CRITICAL violations

# Test the secure version
conftest test -p brief-builder-security.rego agent.yaml.secure brief-builder.tf.secure
# Expected result: No violations (all policies pass)
```

### Option B: Integrate GitHub Actions Workflow

1. Copy `ci-security-gate.yml` to `.github/workflows/ci-security-gate.yml`
2. Push to a branch; create a PR to main
3. Workflow runs automatically on PR
4. Results appear in PR checks + GitHub Security tab

### Option C: Manual Code Review

1. Compare `agent.yaml` vs `agent.yaml.secure` to see specific fixes
2. Compare `brief-builder.tf` vs `brief-builder.tf.secure` to see infrastructure changes
3. See inline comments (marked with `# Changed from:` and `# NEW:`) for rationale

---

## 🎯 Key Risk Mitigation Matrix

| Risk | Addressed by | Format |
|------|--------------|--------|
| Prompt injection / role bypass | Conftest rule #3 + agent.yaml.secure (system prompt) | Policy + Config |
| Plaintext secrets in repo | Conftest rule #1-2 + Secret Manager in Terraform | Policy + IaC |
| Public Cloud Run invocation | Conftest rule #7 + IAM restriction in Terraform | Policy + IaC |
| No audit trail (SOC 2 violation) | Conftest rule #6 + audit logging in agent.yaml.secure | Policy + Config |
| Global memory data leakage | Conftest rule #5 + per-user scope in agent.yaml.secure | Policy + Config |
| Unvetted third-party Actions | CI/CD workflow with pinned versions + allowlist | Workflow |

---

## 📋 Checklist for Priya (Launch Readiness)

- [ ] **Week 1:** Rotate all exposed secrets (LLM_API_KEY, GCP_SA_KEY)
- [ ] **Week 1:** Enable branch protection + required reviews on GitHub
- [ ] **Week 1:** Enable secret scanning + push protection
- [ ] **Week 2:** Migrate Terraform to use Secret Manager (apply brief-builder.tf.secure)
- [ ] **Week 2:** Update agent config to use per-user memory scope (apply agent.yaml.secure)
- [ ] **Week 2:** Run Conftest on all future deployments (integrate ci-security-gate.yml)
- [ ] **Week 3:** Implement audit logging (logs shipped to Datadog/Splunk)
- [ ] **Week 3:** Manual security review of LLM prompt + tool scope
- [ ] **Week 4:** Launch to marketing org with audit trail enabled

---

## 🤔 Questions & Clarifications

**Assumption:** Brief Builder operates in staging only until security controls are in place. Production launch delayed until audit logging is operational.

**Assumption:** Customer support ticket data is classified as internal/confidential and not shared externally.

**Assumption:** Jasper has existing Secret Manager infrastructure and can populate secrets via separate process.

---

## 📞 Contact

**Submission prepared by:** Monty Gill  
**For questions about this exercise:** monty.gill@jasper.ai  
**Security escalation:** Use the critical question outlined in SECURITY_ASSESSMENT.md

---

## Compliance Evidence

This package provides the following artifacts for SOC 2 Type II & ISO 42001 audits:

1. **Risk Assessment:** Ranked prioritization showing security engineering rigor (CC3.1, CC3.2)
2. **Policy-as-Code:** Automated controls embedded in CI/CD (CC6.1, CC7.2)
3. **Audit Logging Config:** Structured logs with user identity & timestamps (CC7.2)
4. **IAM Least-Privilege:** Custom role with explicit permissions (CC6.2)
5. **Secret Management:** Secrets isolated in Secret Manager (CC6.1)

---

**Last updated:** 2026-09-16  
**Total time invested:** ~75 minutes (well within 90-minute cap)
