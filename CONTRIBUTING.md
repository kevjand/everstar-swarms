# Contributing to Everstar Swarms

Thank you for your interest in contributing! This document provides guidelines for improving the autonomous ticket execution system.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone git@github.com:YOUR_USERNAME/everstar-swarms.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Run setup: `./scripts/setup.sh`

## Development Workflow

### Testing Changes

Before submitting changes, test the full workflow:

```bash
# Test Phase 0: Ticket Analysis
./scripts/everstar-cli.sh TEST-001

# Verify output files
ls -la /tmp/ruflo-*

# Check swarm status
cd /path/to/everstar/repo
npx @claude-flow/cli@latest swarm status
```

### Making Changes

#### To Modify the 4-Phase Workflow

Edit [scripts/everstar-cli.sh](scripts/everstar-cli.sh):

```bash
# Phase 0: Ticket Analysis & Enrichment (lines 100-150)
# Phase 1: Planning (lines 160-210)
# Phase 2: Automated Plan Review (lines 220-270)
# Phase 3: Parallel Execution (lines 280-400)
```

#### To Update Quality Standards

Edit [.claude/ticket-bot-standards.md](.claude/ticket-bot-standards.md)

#### To Adjust Scoring Thresholds

In `scripts/everstar-cli.sh`:

```bash
# Ticket quality threshold (default: 70)
ENRICHMENT_THRESHOLD=70

# Plan review threshold (default: 85)
PLAN_APPROVAL_THRESHOLD=85

# Test coverage threshold (default: 85)
TEST_COVERAGE_THRESHOLD=85
```

## Contribution Types

### 🐛 Bug Fixes

If you find a bug:

1. Check if an issue exists: https://github.com/everstarai/everstar-swarms/issues
2. If not, create one with:
   - Description of bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Output from `/tmp/ruflo-*.md` files
3. Submit PR with fix and reference issue number

### ✨ New Features

For new features:

1. Open an issue first to discuss the approach
2. Get consensus from maintainers
3. Implement with tests
4. Update documentation (README.md, SETUP.md)
5. Submit PR

### 📚 Documentation

Documentation improvements are always welcome:

- Clarify setup instructions
- Add troubleshooting tips
- Fix typos or broken links
- Add examples

### 🔧 Agent Improvements

To add or improve agents:

1. Add agent to [.claude/agents/]((.claude/agents/))
2. Document role and capabilities
3. Test in isolation
4. Test in swarm coordination
5. Update CLAUDE.md if needed

## Code Standards

### Shell Scripts

- Use `set -e` for error handling
- Add clear comments for complex logic
- Use meaningful variable names
- Test on macOS (primary platform)

### Documentation

- Use clear, concise language
- Include code examples
- Test all commands before documenting
- Link to related documentation

### Commit Messages

Follow conventional commits:

```
feat: add Phase 0 ticket enrichment
fix: correct Linear MCP configuration path
docs: update setup instructions for M1 Macs
chore: clean up experimental scripts
```

## Testing

### Manual Testing Checklist

Before submitting PR:

- [ ] Setup works on fresh clone: `./scripts/setup.sh`
- [ ] Automation completes end-to-end: `./scripts/everstar-cli.sh ENG-XXXX`
- [ ] Cleanup works: `./scripts/cleanup.sh --all`
- [ ] Documentation is accurate
- [ ] No secrets in commits

### Test Environments

Tested on:
- macOS 12+ (Monterey, Ventura, Sonoma)
- Apple Silicon (M1/M2/M3)
- Intel Macs

## Submitting Pull Requests

### PR Checklist

- [ ] Branch is up to date with `main`
- [ ] Changes are tested locally
- [ ] Documentation updated if needed
- [ ] Commit messages follow conventions
- [ ] No secrets or API keys in code
- [ ] `.gitignore` updated if new files added

### PR Description Template

```markdown
## What Changed

Brief description of what changed and why.

## Testing

How you tested these changes:
- [ ] Ran setup.sh
- [ ] Tested ticket workflow: ENG-XXXX
- [ ] Verified output in /tmp/ruflo-*.md

## Related Issues

Fixes #123
Relates to #456
```

## Getting Help

- **Questions:** Open a discussion: https://github.com/everstarai/everstar-swarms/discussions
- **Bugs:** Open an issue: https://github.com/everstarai/everstar-swarms/issues
- **Slack:** #engineering-tools channel (for team members)

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Help others learn and grow
- Celebrate contributions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

**Thank you for contributing to Everstar Swarms!** 🎉
