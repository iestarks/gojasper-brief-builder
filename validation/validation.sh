#!/bin/bash

################################################################################
# Brief Builder Security Validation Script
# Purpose: Validate security configurations against policy-as-code rules
# Logs: validation.log (captures all errors and validation results)
################################################################################

set -o pipefail  # Ensure we capture errors in pipes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/validation.log"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# Initialize log file
: > "$LOG_FILE"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    ((ERROR_COUNT++))
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    ((WARNING_COUNT++))
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    ((SUCCESS_COUNT++))
}

################################################################################
# Validation Functions
################################################################################

validate_file_exists() {
    local file_path="$1"
    local file_name="$2"
    
    if [[ -f "$file_path" ]]; then
        log_success "File exists: $file_name ($file_path)"
        return 0
    else
        log_error "MISSING FILE: $file_name ($file_path)"
        return 1
    fi
}

validate_yaml_syntax() {
    local file_path="$1"
    local file_name="$2"
    
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 not found, skipping YAML validation for $file_name"
        return 0
    fi
    
    if python3 -c "import yaml; yaml.safe_load(open('$file_path'))" 2>/dev/null; then
        log_success "YAML syntax valid: $file_name"
        return 0
    else
        log_error "YAML SYNTAX ERROR in $file_name: $(python3 -c "import yaml; yaml.safe_load(open('$file_path'))" 2>&1 | head -1)"
        return 1
    fi
}

validate_security_risks() {
    local file_path="$1"
    local file_name="$2"
    
    log_info "Scanning $file_name for security risks..."
    
    local risks_found=0
    
    # Check for plaintext secrets
    if grep -q "sk-proj-\|api_key\|LLM_API_KEY.*=.*sk-" "$file_path" 2>/dev/null; then
        log_error "SECURITY RISK in $file_name: Plaintext API key detected"
        ((risks_found++))
    fi
    
    # Check for confirmation: never
    if grep -q "confirmation: never" "$file_path" 2>/dev/null; then
        log_warning "SECURITY RISK in $file_name: Tool has 'confirmation: never' (requires approval)"
        ((risks_found++))
    fi
    
    # Check for allUsers IAM binding
    if grep -q "allUsers" "$file_path" 2>/dev/null; then
        log_error "SECURITY RISK in $file_name: Public access (allUsers) detected - should restrict to authenticated users"
        ((risks_found++))
    fi
    
    # Check for editor role
    if grep -q '"roles/editor"' "$file_path" 2>/dev/null; then
        log_error "SECURITY RISK in $file_name: Editor role too permissive - should use least-privilege custom role"
        ((risks_found++))
    fi
    
    # Check for global memory scope
    if grep -q "scope: global" "$file_path" 2>/dev/null; then
        log_warning "SECURITY RISK in $file_name: Global memory scope (data leakage between users) - should be per-user"
        ((risks_found++))
    fi
    
    # Check for missing logging
    if grep -q "tool_calls: false" "$file_path" 2>/dev/null; then
        log_warning "SECURITY RISK in $file_name: Tool calls not logged (audit trail missing)"
        ((risks_found++))
    fi
    
    return $risks_found
}

validate_conftest_policy() {
    log_info "Checking Conftest policy availability..."
    
    if ! command -v conftest &> /dev/null; then
        log_error "MISSING TOOL: Conftest not installed. Install via: brew install conftest"
        return 1
    fi
    
    log_success "Conftest available: $(conftest --version 2>&1 | head -1)"
    
    if [[ -f "${SCRIPT_DIR}/brief-builder-security.rego" ]]; then
        log_success "Conftest policy found: brief-builder-security.rego"
        return 0
    else
        log_warning "Conftest policy not found at ${SCRIPT_DIR}/brief-builder-security.rego (can still validate manually)"
        return 0
    fi
}

validate_secure_versions() {
    log_info "Checking secure versions of configuration files..."
    
    local secure_files=(
        "agent.yaml.secure"
        "brief-builder.tf.secure"
    )
    
    for file in "${secure_files[@]}"; do
        if validate_file_exists "${SCRIPT_DIR}/${file}" "$file"; then
            # Check that secure version has fixes
            if grep -q "per_user" "${SCRIPT_DIR}/agent.yaml.secure" 2>/dev/null; then
                log_success "Security fix verified in agent.yaml.secure: per-user memory scope enabled"
            fi
            if grep -q "workload_identity" "${SCRIPT_DIR}/brief-builder.tf.secure" 2>/dev/null; then
                log_success "Security fix verified in brief-builder.tf.secure: Workload Identity configured"
            fi
        fi
    done
}

validate_compliance_documentation() {
    log_info "Checking compliance documentation..."
    
    if validate_file_exists "${SCRIPT_DIR}/SECURITY_ASSESSMENT.md" "SECURITY_ASSESSMENT.md"; then
        # Check for required sections
        if grep -q "Prioritized Risk Assessment" "${SCRIPT_DIR}/SECURITY_ASSESSMENT.md"; then
            log_success "Compliance doc includes: Prioritized Risk Assessment"
        else
            log_warning "Compliance doc missing: Prioritized Risk Assessment section"
        fi
        
        if grep -q "SOC 2\|ISO 42001" "${SCRIPT_DIR}/SECURITY_ASSESSMENT.md"; then
            log_success "Compliance doc includes: SOC 2 / ISO 42001 mapping"
        else
            log_warning "Compliance doc missing: Compliance control mapping"
        fi
    fi
}

print_summary() {
    echo ""
    echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "VALIDATION SUMMARY" | tee -a "$LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "✓ Successes:  $SUCCESS_COUNT" | tee -a "$LOG_FILE"
    echo "⚠ Warnings:   $WARNING_COUNT" | tee -a "$LOG_FILE"
    echo "✗ Errors:     $ERROR_COUNT" | tee -a "$LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo ""
    echo "Full log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
    echo ""
}

################################################################################
# MAIN VALIDATION FLOW
################################################################################

echo "════════════════════════════════════════════════════════════════"
echo "Brief Builder Security Validation Script"
echo "════════════════════════════════════════════════════════════════"
echo ""

log_info "Starting validation in: $SCRIPT_DIR"

# Step 1: Validate file structure
log_info "STEP 1: Validating file structure..."
echo ""

validate_file_exists "${SCRIPT_DIR}/brief-builder/config/agent.yaml" "brief-builder/config/agent.yaml"
validate_file_exists "${SCRIPT_DIR}/infra/brief-builder.tf" "infra/brief-builder.tf"
validate_file_exists "${SCRIPT_DIR}/.github/workflows/ci.yml" ".github/workflows/ci.yml"

echo ""

# Step 2: Validate YAML syntax
log_info "STEP 2: Validating YAML syntax..."
echo ""

validate_yaml_syntax "${SCRIPT_DIR}/brief-builder/config/agent.yaml" "agent.yaml"
validate_yaml_syntax "${SCRIPT_DIR}/.github/workflows/ci.yml" "ci.yml"

echo ""

# Step 3: Security risk scanning
log_info "STEP 3: Scanning for security risks in vulnerable configurations..."
echo ""

validate_security_risks "${SCRIPT_DIR}/brief-builder/config/agent.yaml" "agent.yaml (VULNERABLE)"
validate_security_risks "${SCRIPT_DIR}/infra/brief-builder.tf" "brief-builder.tf (VULNERABLE)"
validate_security_risks "${SCRIPT_DIR}/.github/workflows/ci.yml" "ci.yml (VULNERABLE)"

echo ""

# Step 4: Check Conftest availability
log_info "STEP 4: Checking Conftest policy engine..."
echo ""

validate_conftest_policy

echo ""

# Step 5: Validate secure versions
log_info "STEP 5: Validating secure configuration versions..."
echo ""

validate_secure_versions

echo ""

# Step 6: Compliance documentation
log_info "STEP 6: Validating compliance documentation..."
echo ""

validate_compliance_documentation

echo ""

# Step 7: Try to run Conftest if available
if command -v conftest &> /dev/null && [[ -f "${SCRIPT_DIR}/brief-builder-security.rego" ]]; then
    log_info "STEP 7: Running Conftest policy validation..."
    echo ""
    
    log_info "Testing VULNERABLE configurations (should detect issues)..."
    if conftest test -p "${SCRIPT_DIR}/brief-builder-security.rego" \
        "${SCRIPT_DIR}/brief-builder/config/agent.yaml" \
        "${SCRIPT_DIR}/infra/brief-builder.tf" 2>&1 | tee -a "$LOG_FILE"; then
        log_warning "Conftest passed on vulnerable config (expected to fail) - check policy rules"
    else
        log_success "Conftest correctly identified issues in vulnerable configurations"
    fi
    
    echo ""
    
    log_info "Testing SECURE configurations (should pass)..."
    # Copy secure files to temporary names for Conftest testing (conftest can't parse .secure extension)
    cp "${SCRIPT_DIR}/agent.yaml.secure" /tmp/agent-secure.yaml 2>/dev/null || true
    cp "${SCRIPT_DIR}/brief-builder.tf.secure" /tmp/brief-builder-secure.tf 2>/dev/null || true
    
    if conftest test -p "${SCRIPT_DIR}/brief-builder-security.rego" \
        /tmp/agent-secure.yaml \
        /tmp/brief-builder-secure.tf 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Conftest passed on secure configurations"
    else
        log_warning "Conftest reported issues on secure configurations (may be expected if fixes not complete)"
    fi
    
    # Cleanup temp files
    rm -f /tmp/agent-secure.yaml /tmp/brief-builder-secure.tf 2>/dev/null || true
else
    log_warning "STEP 7: Conftest policy validation SKIPPED (conftest not installed or policy missing)"
fi

echo ""

# Print final summary
print_summary

# Exit with appropriate code
if [[ $ERROR_COUNT -gt 0 ]]; then
    log_error "Validation completed with errors"
    exit 1
else
    log_success "Validation completed successfully"
    exit 0
fi
