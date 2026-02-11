# Security Policy

## Supported Versions

Security updates are applied to the `main` branch.

| Version | Supported |
|---------|-----------|
| `main`  | Yes |
| Older tags/branches | No |

## Reporting a Vulnerability

Please do not open a public issue for security-sensitive findings.

Use GitHub Security Advisories:
- https://github.com/bishnubista/coderabbit-fixer/security/advisories/new

Include:
1. Affected files/commands
2. Impact and exploitability
3. Reproduction steps
4. Suggested fix (if available)

## Response Targets

- Initial triage response: within 3 business days
- Status update after validation: within 7 business days
- Patch timeline: depends on severity and release risk

## Scope Notes

High-priority classes include:
- Command injection
- Unsafe shell quoting/argument handling
- Credential/token exposure
- Incorrect GitHub API permission assumptions
