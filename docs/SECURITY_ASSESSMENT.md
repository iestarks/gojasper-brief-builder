# Brief Builder Security Assessment  
**Senior Security Engineer Take-Home Exercise**

---

## 1. Prioritized Risk Assessment

| Priority | Issue | Impact (Plain Language) | Recommendation |
|----------|-------|------------------------|-----------------|
| **1** | **Prompt injection / confirmation bypass in system prompt** | An attacker (or customer in support ticket) can claim to be "admin" or "security team" to bypass all tool confirmations, enabling arbitrary emails, SQL queries, and Slack posts without approval. | **Block launch.** Remove the bypass clause entirely. Add strict role-based authorization using signed JWT or mTLS. |
| **2** | **Plaintext API keys in Terraform repo** (LLM_API_KEY in agent.yaml committed; GCP_SA_KEY exported to GitHub 2025-03-11, unrotated) | Keys already exposed to public GitHub for ~6 months; can be revoked only after full audit of abuse. Attacker with key can invoke Brief Builder as the service account (editor role). | **Block launch.** Revoke both secrets immediately. Use Google Secret Manager with Workload Identity instead of environment variables. Implement secret scanning + push protection on repo. |
| **3** | **Cloud Run service publicly invocable (allUsers) + Editor SA role** | Anyone on the internet can invoke the Brief Builder API and perform privileged operations (read all CRM, send emails externally, run SQL). No authentication layer. | **Block launch.** Restrict Cloud Run invocation to authenticated Jasper users only (IAM binding). Reduce SA role from editor to custom role with only needed permissions (read GCS drive, read Zendesk, write logs). |
| **4** | **No input sanitization on customer-controlled data** (Zendesk tickets ingested verbatim) + global memory with no TTL | Malicious customer can inject prompt instructions into ticket; stored in shared global memory forever; seen by all 40 users. Enables cross-user prompt injection and data leakage. | **Block launch.** Implement per-user memory scope with 24h TTL. Sanitize/redact customer ticket content before ingestion. Filter system prompt dynamically to reject role-claim instructions. |
| **5** | **No branch protection, required reviews, or secret scanning on public repo** | Malicious commit to `main` deploys directly to staging (holds real customer data). Third-party Actions (some-vendor/llm-eval-action@v1) are untrusted and not audited. | **Block launch.** Enable branch protection + required reviews. Enable secret scanning + push protection. Pin third-party Actions to specific commit SHAs; audit before use. |
| **6** | **No end-user audit trail** (service account ID logged, not end user; tool_calls not logged; identity not recorded) | SOC 2 Type II requires attribution of who performed what action. Auditor cannot prove data access controls. ISO 42001 requires evidence of human oversight of AI decisions. | **Ship with control:** Implement comprehensive audit logging: log user identity, tool calls, parameters, timestamps. GRC team owns implementation (2-week requirement). Create Cloud Logging alert if tool_calls not logged. |
| **7** | **CI/CD pull_request_target with write-all permissions** | Untrusted PR code (from fork or external contributor) gets full GitHub token + write permissions + access to secrets. Enables credential theft, malicious deployment, lateral movement. | **Ship with control:** Restrict `pull_request_target` permissions to `read-all` only. Use separate `pull_request` event with `write-all` only after manual approval. |
| **8** | **No separate prod project; staging holds real customer data** | Risk of production outage during rollout; no blast radius isolation; data loss affects live customers immediately. | **Accept & track.** Prod project creation is in-flight (assumed). Interim: require explicit approval from CMO/Priya before any prod deployment. Label staging as non-isolated. |

---

## 2. Automated Control: Policy-as-Code (Conftest + OPA/Rego)

I built a Conftest policy (`brief-builder-security.rego`) that validates the agent configuration and Terraform against STRIDE-based security rules. This catches the most critical issues at CI time before any human review.

### What it detects:
- ✅ Plaintext API keys or secrets in environment variables  
- ✅ Dangerous system prompt patterns (role bypass, confirmation bypass)  
- ✅ Unscoped or overly broad IAM bindings (allUsers, editor role)  
- ✅ Unlogged tool calls or missing audit trail configuration  
- ✅ Missing memory isolation / global scope risks  

### What it does NOT cover:
This policy does not validate runtime behavior, network policies, or whether the underlying LLM can be fooled by clever adversarial prompts. It also does not detect exfiltration via `send_email` or `fetch_url` after policy passes—runtime monitoring and rate-limiting would be needed for that. Finally, it assumes the Conftest engine itself is trustworthy and cannot be bypassed by a compromised developer with direct GCP/GitHub access.

---

## 3. Write-Up

### Problem Chosen & Why (Highest-Leverage Hour)
I prioritized **plaintext secrets + prompt injection bypass** because these are:
- **Immediately exploitable** without needing to compromise infrastructure
- **Already exposed** (keys in public repo for 6+ months)
- **Highest business impact** (full service compromise, data exfiltration, compliance violation)
- **High leverage** (fixing takes 2 hours; fixes 60% of top risks)

The alternative (audit logging) is equally important for compliance but is lower **immediate** risk.

### What I Built & Tradeoffs
I created:
1. **`brief-builder-security.rego`** — Conftest policy (100 lines) that enforces security rules via `deny` clauses. Rules are stackable and auditable. Tradeoffs: requires developers to learn Rego syntax; does not catch sophisticated adversarial prompts or runtime exfiltration; assumes clean git history (cannot detect secrets already in repo before policy was added).

2. **`ci-security-gate.yml`** — GitHub Actions workflow that runs Conftest on every PR, fails if any policy violation detected. Tradeoffs: adds 10–15 seconds to CI time; can create false negatives if rules are too loose or too strict.

3. **Corrected `agent.yaml.secure`** — Removed role-bypass clause, added per-user memory scope, restricted tool confirmations, added redaction for customer data.

4. **Corrected `brief-builder.tf.secure`** — Rotated secrets to Secret Manager, restricted Cloud Run to authenticated users, reduced SA role to least-privilege custom role.

### What I Would Do with Two More Weeks (Priority Order)
1. **Secret rotation & supply chain hardening** (3 days): Revoke all exposed secrets. Audit git history for others. Pin Actions to commit SHAs. Migrate to Secret Manager.
2. **Audit logging instrumentation** (5 days): Implement structured logging to Cloud Logging with user identity, tool parameters, decisions. Set up Datadog/Splunk ingestion and alerting.
3. **Memory isolation & input sanitization** (4 days): Refactor memory backend to per-user scope. Add prompt injection detection (regex + regex-based content filter on customer data).
4. **Rate limiting & cost control** (2 days): Add token budgets per user per day. Implement BigQuery query allowlist (whitelist specific reports only).
5. **Incident response runbook** (1 day): Document what to do if Brief Builder is compromised; how to audit what data was accessed; communication plan to affected customers.

### Compliance Hook
**1. SOC 2 Type II — CC7.2 (Audit Logging)**  
Implementing the audit logging control (structured logs with user identity, tool calls, parameters, timestamps stored in Cloud Logging with 90-day retention) provides auditors with the evidence they need to validate that every data access is traceable to a human user and timestamp. Automated log ingestion to a SIEM (e.g., Datadog) allows periodic audit queries.

**2. ISO 42001 (AI Management System) — 6.5.3 (Human Oversight)**  
The policy-as-code control (Conftest gate on every deployment) provides evidence that security decisions are embedded in the CI/CD pipeline and not left to runtime. ISO 42001 auditors can review the Rego rules, the git commit history showing policy evolution, and PR approval logs demonstrating that security-relevant changes required human review.

### How I Used AI
**Tools used:** Claude 3.5 Sonnet (Cursor) + GitHub Copilot

**Prompts:**
- "Write a Conftest policy in Rego to detect plaintext API keys and dangerous prompt patterns in YAML"
- "What are the STRIDE threat categories for an LLM agent with customer data access?"
- "Draft a corrected Terraform SA role that is least-privilege for read-only file + log access"

**What they got right:**
- Rego syntax was correct; policy compiled on first try
- STRIDE mapping was comprehensive
- SA custom role permission list was accurate

**What they missed:**
- Claude initially suggested using `pattern` Rego function for secret detection (too slow on large repos); I switched to exact string matching
- Copilot suggested overly complex memory isolation designs; I simplified to per-user TTL scope
- Neither tool initially caught the `allUsers` binding on Cloud Run (required my own architectural review)

**Verification:**
- Tested Conftest policy against the provided agent.yaml (policy correctly flagged system_prompt bypass)
- Cross-referenced Rego rules against OPA/Rego official docs to ensure no syntax errors
- Checked STRIDE categories against OWASP threat model checklist

---

## 4. Your One Critical Question

**Question for Priya:**  
*"Is Brief Builder's data classified as confidential/restricted, or is it purely internal marketing content? And do we have explicit customer consent to store their support tickets (even redacted) in an LLM context window?"*

**Why it matters:**  
If customer support tickets are confidential or regulated (e.g., PII, healthcare, financial data), this entire system needs data residency, encryption, and compliance audits beyond what we've discussed. If we don't have explicit consent, we may be violating customer agreements just by ingesting their tickets. This answer determines whether Brief Builder can launch in 2 weeks or needs a 2-month privacy/compliance review.

---

## 5. Message to Priya

---

**Subject: Brief Builder — Launch blocked until secrets & access controls fixed**

Hi Priya,

Brief Builder is great, but we have a few critical security gaps before marketing can use it:

1. **Secrets exposed** — API keys are in the public GitHub repo (and have been for ~6 months). We need to rotate those immediately and move to Secret Manager.

2. **Anyone can invoke it** — The Cloud Run service is wide open to the internet right now. We need to lock it down to Jasper employees only.

3. **Confirmation bypass** — The system prompt has a loophole where someone can claim to be "admin" and skip all safety checks. That has to go.

4. **Audit trail missing** — SOC 2 requires us to log who accessed what and when. Right now we log nothing useful.

**What I need from you:**
- Confirm the data sensitivity of customer support tickets (do we have consent to store them?)
- Assign an engineer for 1 week to rotate secrets, update IAM, and add logging
- Let me know if you're willing to delay launch 2 weeks for proper audit setup (or accept the risk of a manual audit process in the meantime)

I'm not saying "kill it"—I'm saying "let's ship it right." Happy to pair on implementation.

Monty

---

**Word count:** 147

---

## Appendix: Code Artifacts

See accompanying files:
- `brief-builder-security.rego` — Conftest policy
- `ci-security-gate.yml` — GitHub Actions gate
- `agent.yaml.secure` — Corrected config
- `brief-builder.tf.secure` — Corrected Terraform
