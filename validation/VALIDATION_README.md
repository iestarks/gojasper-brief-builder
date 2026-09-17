# Brief Builder Exercise Validation Infrastructure

## Quick Start

Run the validation script to test all security controls:

```bash
./validation.sh
```

This will execute a comprehensive 7-step validation process and output results to `validation.log`.

## What's Included

### 📋 Configuration Artifacts

Three vulnerable configuration files extracted from the SECURITY_ASSESSMENT.md PDF:

- **brief-builder/config/agent.yaml** - Agent configuration with 6 security issues
- **infra/brief-builder.tf** - Terraform with 5 security issues  
- **.github/workflows/ci.yml** - GitHub Actions CI/CD with 3 security issues

### 🔒 Security Policy

- **brief-builder-security.rego** - OPA/Rego policy with 10 detection rules
  - Validates all configuration files against security best practices
  - Uses Conftest for automated policy enforcement

### ✅ Validation Script

- **validation.sh** - Comprehensive validation with 7 steps:
  1. File structure validation
  2. YAML syntax validation
  3. Security risk pattern scanning
  4. Conftest installation check
  5. Secure version verification
  6. Compliance documentation validation
  7. Automated policy testing with Conftest

### 📝 Error Logging

- **validation.log** - Timestamped output capturing all validation results
- Automatically updated each time validation.sh runs

### 📖 Documentation

- **VALIDATION_SUMMARY.md** - Detailed validation guide with expected results
- **SECURITY_ASSESSMENT.md** - Complete security assessment with risk table

## Validation Steps Explained

### Step 1: File Structure Validation
Checks that all three vulnerable configuration files exist in the correct locations.

**Expected**: ✅ 3 files found

### Step 2: YAML Syntax Validation  
Validates that YAML files are syntactically correct using Python's yaml parser.

**Expected**: ✅ 2 files valid

### Step 3: Security Risk Scanning
Scans configuration files for known vulnerability patterns:
- Plaintext API keys (CRITICAL)
- Tools with confirmation:never (HIGH)
- Global memory scope (HIGH)
- Missing logging (MEDIUM)
- Overpermissioned IAM roles (CRITICAL)

**Expected**: ❌ 6+ issues detected in vulnerable configs

### Step 4: Conftest Availability Check
Verifies Conftest is installed and policy file is valid.

**Expected**: ✅ Conftest v0.70+ installed

### Step 5: Secure Version Verification
Confirms that corrected/secure versions exist and contain expected fixes.

**Expected**: ✅ 2 secure files with fixes verified

### Step 6: Compliance Documentation
Checks that SECURITY_ASSESSMENT.md includes required sections:
- Prioritized Risk Assessment table
- SOC 2 / ISO 42001 compliance mapping

**Expected**: ✅ All sections present

### Step 7: Automated Policy Testing
Runs Conftest to validate configurations against security rules.

**Vulnerable Configs**: Should have 12+ failures (security issues detected)  
**Secure Configs**: Should have 3 or fewer failures (issues fixed)

## Installation Requirements

### Automatic
The validation.sh script will check for and guide installation of:
- Python 3 with PyYAML module
- Conftest policy engine

### Manual Installation

**MacOS**:
```bash
brew install conftest
python3 -m pip install pyyaml
```

**Linux**:
```bash
# Install Conftest
wget https://github.com/open-policy-agent/conftest/releases/download/v0.70.0/conftest_0.70.0_Linux_x86_64.tar.gz
tar xzf conftest_0.70.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Install PyYAML
python3 -m pip install pyyaml
```

## Understanding the Results

### Validation Summary Output

```
════════════════════════════════════════════════════════════════
VALIDATION SUMMARY
════════════════════════════════════════════════════════════════
✓ Successes:  15    ← All checks that passed
⚠ Warnings:   4     ← Issues that need attention
✗ Errors:     3     ← Critical failures (expected for vulnerable configs)
════════════════════════════════════════════════════════════════
```

### Conftest Results

When validating the vulnerable configurations, you should see output like:

```
FAIL - brief-builder/config/agent.yaml - main - CRITICAL: System prompt contains confirmation bypass clause
FAIL - brief-builder/config/agent.yaml - main - HIGH: Global memory scope with no TTL
FAIL - infra/brief-builder.tf - main - CRITICAL: Plaintext secret detected
```

**This is expected** - the vulnerability detection is working correctly.

## Key Vulnerabilities Detected

### Agent Configuration (agent.yaml)
| Issue | Severity | Rule |
|-------|----------|------|
| Role bypass clause in system prompt | CRITICAL | Rule 3 |
| Tools allow skipping confirmation | HIGH | Rule 4 |
| Global memory scope shared by all users | HIGH | Rule 5 |
| Tool calls not logged | MEDIUM | Rule 6 |
| Service account instead of user identity logging | MEDIUM | Rule 6 |
| No PII redaction in logs | MEDIUM | Rule 6 |

### Terraform Configuration (brief-builder.tf)
| Issue | Severity | Rule |
|-------|----------|------|
| Plaintext API key in environment variable | CRITICAL | Rule 2 |
| Cloud Run publicly invocable (allUsers) | CRITICAL | Rule 7 |
| Service account with editor role | CRITICAL | Rule 7 |
| Unrotated service account key | CRITICAL | Rule 8 |
| Missing data access audit logs | MEDIUM | Rule 9 |

### CI/CD Workflow (ci.yml)
- pull_request_target with write-all permissions
- Untrusted third-party action without version pin
- Secrets deployed on every PR

## Next Steps

1. **Study the Vulnerabilities**
   - Compare vulnerable configs with secure versions in `agent.yaml.secure` and `brief-builder.tf.secure`
   - Review security fixes documented in SECURITY_ASSESSMENT.md

2. **Understand the Policy**
   - Read brief-builder-security.rego to see how each rule works
   - Modify rules to match your organization's security standards

3. **Integrate into CI/CD**
   - Use ci-security-gate.yml as a reference for GitHub Actions security gates
   - Run conftest in your CI/CD pipeline to validate all PRs

4. **Deploy Secure Versions**
   - Use agent.yaml.secure and brief-builder.tf.secure as starting points
   - Customize for your environment and deployment

## Support & Troubleshooting

### validation.sh refuses to run
```bash
chmod +x validation.sh
```

### Conftest not found
```bash
# macOS
brew install conftest

# Or download from: https://github.com/open-policy-agent/conftest/releases
```

### YAML parsing errors
```bash
python3 -m pip install pyyaml
```

### Conftest policy errors
Check that brief-builder-security.rego is in the same directory as validation.sh

### Need to see all errors in detail
```bash
cat validation.log
```

## File Structure

```
gojasper-brief-builder/
├── brief-builder/
│   └── config/
│       └── agent.yaml              ← Vulnerable agent config
├── infra/
│   └── brief-builder.tf            ← Vulnerable Terraform
├── .github/workflows/
│   └── ci.yml                      ← Vulnerable CI/CD workflow
├── brief-builder-security.rego     ← Conftest policy (10 rules)
├── agent.yaml.secure               ← Secure reference implementation
├── brief-builder.tf.secure         ← Secure reference implementation
├── validation.sh                   ← Validation script (MAIN TOOL)
├── validation.log                  ← Error log output
├── ci-security-gate.yml            ← GitHub Actions security gate
├── SECURITY_ASSESSMENT.md          ← Security analysis document
├── VALIDATION_SUMMARY.md           ← Detailed validation guide
└── README_SUBMISSION.md            ← Exercise submission summary
```

## Validation Success Criteria

✅ **PASS** when:
- All 7 validation steps complete
- Vulnerable configurations show 10+ failures in Conftest
- Secure configurations show <5 failures in Conftest
- validation.log captures all results with timestamps

## Performance

- **Validation Time**: ~3-5 seconds (depends on system and Conftest installation)
- **Log Size**: ~7-8 KB per run
- **Policy Load Time**: <1 second
- **Conftest Tests**: 34 total tests run per configuration set

---

**Last Updated**: 2026-09-16  
**Validation Status**: ✅ OPERATIONAL  
**All Artifacts**: ✅ COMPLETE
