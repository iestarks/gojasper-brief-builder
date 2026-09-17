# Conftest policy for Brief Builder security validation (Rego v2 syntax)
# Usage: conftest test -p brief-builder-security.rego agent.yaml brief-builder.tf

package main

# RULE 1: Detect plaintext API keys / secrets in environment variables
deny contains msg if {
    value := input.agent.tools[_].env[_].value
    regex.match("(sk-|api_?key|token|secret|password)", lower(value))
    not startswith(value, "var.")
    not startswith(value, "${")
    msg := sprintf("CRITICAL: Plaintext secret detected in tool env: %s", [value])
}

# RULE 2: Detect plaintext secrets in Terraform resource
deny contains msg if {
    value := input.resource.google_cloud_run_service[_].template[0].spec[0].containers[0].env[_].value
    regex.match("(sk-|api_?key|token|secret|password)", lower(value))
    not startswith(value, "var.")
    not startswith(value, "${")
    not startswith(value, "google_secret_manager")
    msg := sprintf("CRITICAL: Plaintext secret in Cloud Run env: %s", [value])
}

# RULE 3: Detect system prompt with role bypass / confirmation bypass
deny contains msg if {
    prompt := input.agent.system_prompt
    regex.match("(skip.*confirmation|admin.*confirmation|security.*team.*confirmation|if.*admin|if.*security)", lower(prompt))
    msg := "CRITICAL: System prompt contains confirmation bypass clause. This enables prompt injection attacks."
}

# RULE 4: Detect tools with confirmation: never and high-risk operations
deny contains msg if {
    tool := input.agent.tools[_]
    tool.confirmation == "never"
    tool.name == "send_email"
    msg := sprintf("HIGH: %s tool has confirmation:never. Restrict 'to' field to allowlist.", [tool.name])
}

deny contains msg if {
    tool := input.agent.tools[_]
    tool.confirmation == "never"
    tool.name == "run_sql"
    msg := "HIGH: run_sql tool has confirmation:never. Add confirmation or enforce query allowlist."
}

deny contains msg if {
    tool := input.agent.tools[_]
    tool.confirmation == "never"
    tool.name == "fetch_url"
    msg := "HIGH: fetch_url tool has confirmation:never. Add URL allowlist to prevent SSRF."
}

# RULE 5: Detect global memory scope (data leakage between users)
deny contains msg if {
    input.agent.memory.scope == "global"
    ttl := input.agent.memory.ttl
    ttl == "none"
    msg := "HIGH: Global memory scope with no TTL. Enable per-user scope + 24h TTL."
}

deny contains msg if {
    input.agent.memory.scope == "global"
    ttl := input.agent.memory.ttl
    ttl == null
    msg := "HIGH: Global memory scope with no TTL. Enable per-user scope + 24h TTL."
}

# RULE 6: Detect missing or inadequate logging
deny contains msg if {
    logging := input.agent.logging
    logging.events[_] != "tool_calls"
    msg := "MEDIUM: Tool calls are not logged. Required for SOC 2 audit trail."
}

deny contains msg if {
    logging := input.agent.logging
    logging.identity == "service_account_id"
    msg := "MEDIUM: Logging identity is service account, not user. Log user identity for SOC 2."
}

deny contains msg if {
    logging := input.agent.logging
    logging.identity != "user_id"
    msg := "MEDIUM: Logging identity is not user_id. SOC 2 requires user attribution."
}

deny contains msg if {
    logging := input.agent.logging
    logging.redaction == "none"
    msg := "MEDIUM: No redaction of sensitive fields in logs. Enable redaction for PII."
}

# RULE 7: Detect overly broad IAM roles in Terraform
deny contains msg if {
    binding := input.resource.google_project_iam_member[_]
    binding.role == "roles/editor"
    msg := "CRITICAL: Service account has 'editor' role (full project access). Use least-privilege."
}

deny contains msg if {
    binding := input.resource.google_cloud_run_service_iam_member[_]
    binding.member == "allUsers"
    binding.role == "roles/run.invoker"
    msg := "CRITICAL: Cloud Run service is publicly invocable. Restrict to authenticated users."
}

# RULE 8: Detect unrotated service account keys
deny contains msg if {
    key := input.resource.google_service_account_key[_]
    msg := "CRITICAL: Service account key not using Workload Identity. Migrate to Workload Identity."
}

# RULE 9: Detect missing data access audit logs
deny contains msg if {
    not input.resource.google_project_iam_audit_config
    msg := "MEDIUM: Data Access audit logs not configured. Enable for compliance."
}

# RULE 10: Warn on production-like settings in staging
warn contains msg if {
    input.agent.version == "0.9.3-stg"
    input.agent.context_sources[_].note == "customer-submitted text, ingested verbatim into context"
    msg := "MEDIUM: Customer-submitted text without sanitization. Add input filtering."
}
