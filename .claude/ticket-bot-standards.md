# Ticket Bot Quality Standards

**PRIMARY RULE: Follow the project's CLAUDE.md first. These are fallback standards only.**

## BLOCKING Quality Gates (Must Pass Before Commit)

### 1. Tests Must Pass
- All tests passing (zero failures, zero skipped)
- Coverage >85% (configurable in project CLAUDE.md)
- Edge cases tested (boundaries, errors, empty inputs)

```bash
cd api && poetry run pytest --cov=src --cov-fail-under=85 -v
cd frontend && npm test -- --coverage --watchAll=false
```

### 2. Code Must Be Type-Safe
- 100% type coverage (Python type hints, TypeScript types)
- No type: ignore or any without justification

```bash
cd api && poetry run mypy src
cd frontend && npm run type-check
```

### 3. Linting Must Pass
- Zero errors, zero warnings

```bash
cd api && poetry run ruff check .
cd frontend && npm run lint
```

### 4. Security Requirements
- No hardcoded secrets (API keys, passwords, tokens)
- All user inputs validated at system boundaries
- Parameterized SQL queries only (no string concatenation)
- Protected endpoints require authentication

```bash
# Quick secret scan
git grep -E '(api_key|password|secret|token)\s*=\s*["\']'
```

### 5. Project Standards (CLAUDE.md)
- Read and follow ALL rules in project's CLAUDE.md
- Naming conventions (if specified)
- File organization (if specified)
- Architecture patterns (if specified)

## Failure Handling

If ANY gate fails:
1. Fix immediately
2. Re-run validation
3. Only proceed when ALL gates pass

## Notes

- No arbitrary size limits (use CLAUDE.md if project needs them)
- No style enforcement beyond linting (use CLAUDE.md for project style)
- Focus on what actually matters: correctness, safety, maintainability
