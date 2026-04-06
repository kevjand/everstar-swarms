# Ticket Enrichment Research

## Problem Statement

Many Linear tickets from product/design lack:
- Explicit acceptance criteria
- Documented edge cases
- Test requirements
- Technical prerequisites
- Security considerations

This leads to:
- Incomplete implementations
- Missed edge cases
- Inadequate test coverage
- Back-and-forth during review

## Solution: Intelligent Ticket Analysis & Enrichment Phase

### Phase 0: Pre-Planning Ticket Analysis

**Goal:** Analyze ticket quality and enrich with missing details before planning begins.

## Ticket Quality Scoring Framework

### Quality Dimensions (0-100 score)

1. **Acceptance Criteria (25 points)**
   - [ ] Explicit acceptance criteria listed
   - [ ] Uses Given-When-Then format
   - [ ] Success/failure conditions clear
   - [ ] User-facing outcomes defined
   - [ ] Testable criteria

2. **Edge Cases (20 points)**
   - [ ] Boundary conditions identified
   - [ ] Error scenarios documented
   - [ ] Invalid input handling specified
   - [ ] Concurrent usage considered
   - [ ] Performance constraints noted

3. **Test Requirements (20 points)**
   - [ ] Unit test scenarios listed
   - [ ] Integration test needs documented
   - [ ] E2E test requirements specified
   - [ ] Test data requirements noted
   - [ ] Coverage expectations defined

4. **Prerequisites & Dependencies (15 points)**
   - [ ] Backend dependencies identified
   - [ ] Frontend dependencies listed
   - [ ] Third-party services noted
   - [ ] Database changes documented
   - [ ] Migration requirements specified

5. **Security Considerations (10 points)**
   - [ ] Auth/authz requirements clear
   - [ ] Input validation needs specified
   - [ ] Data sensitivity classified
   - [ ] API security requirements noted

6. **Technical Details (10 points)**
   - [ ] Affected components identified
   - [ ] API endpoints specified
   - [ ] Data models documented
   - [ ] UI/UX requirements clear

### Scoring Thresholds

- **90-100:** Excellent - minimal enrichment needed
- **70-89:** Good - minor elaboration helpful
- **50-69:** Fair - significant enrichment required
- **0-49:** Poor - major elaboration needed

## Enrichment Strategy

### If Score < 70: Automated Enrichment

#### 1. Generate Acceptance Criteria

**Format: Given-When-Then**

```
## Acceptance Criteria

### AC1: [Primary User Flow]
**Given** [initial state]
**When** [action performed]
**Then** [expected outcome]

### AC2: [Edge Case Handling]
**Given** [error condition]
**When** [error triggered]
**Then** [graceful handling]
```

#### 2. Identify Edge Cases

**Categories:**
- **Boundary Conditions:** Empty inputs, max limits, special characters
- **Error Scenarios:** Network failures, timeouts, invalid data
- **Concurrent Usage:** Race conditions, simultaneous updates
- **Performance:** Large datasets, slow connections
- **Compatibility:** Browser support, mobile devices

#### 3. Define Test Scenarios

```
## Test Requirements

### Unit Tests (>85% coverage)
- [ ] Test case 1: Normal flow
- [ ] Test case 2: Empty input
- [ ] Test case 3: Invalid data
- [ ] Test case 4: Boundary condition

### Integration Tests
- [ ] API endpoint integration
- [ ] Database interaction
- [ ] External service calls

### E2E Tests
- [ ] Complete user workflow
- [ ] Error recovery flow
```

#### 4. Document Prerequisites

```
## Prerequisites

### Backend
- [ ] Dependency: FastAPI >= 0.100.0
- [ ] Database migration required: Yes/No
- [ ] New environment variables: LIST

### Frontend
- [ ] Dependency: React component library
- [ ] State management updates: Redux slice
- [ ] New routes required: /path
```

#### 5. Security Analysis

```
## Security Considerations

- **Authentication:** Required/Not Required
- **Authorization:** Role-based checks
- **Input Validation:** SQL injection, XSS prevention
- **Data Exposure:** Sensitive fields, PII handling
- **Rate Limiting:** API endpoint throttling
```

## Implementation Architecture

### New 4-Phase Workflow

```
Phase 0: TICKET ANALYSIS & ENRICHMENT
├── Fetch Linear ticket
├── Ticket Analyzer Agent (type: reviewer)
│   ├── Score ticket quality (0-100)
│   ├── Identify gaps
│   └── Generate enrichment if score < 70
├── Write: /tmp/ruflo-ticket-enriched-ENG-XXXX.md
└── Output: Enhanced ticket or original if high quality

Phase 1: PLANNING
├── Planner Agent
├── Input: Enriched ticket (or original)
└── Output: /tmp/ruflo-plan-ENG-XXXX.md

Phase 2: PLAN REVIEW
├── Plan Reviewer Agent
└── Output: APPROVED / REJECTED with feedback

Phase 3: EXECUTION
├── 5 Parallel Agents (coder, tester, security, reviewer)
└── Output: Implementation + Tests + PR
```

### Ticket Analyzer Agent Behavior

```javascript
// Pseudocode
function analyzeTicket(ticket) {
  const score = calculateQualityScore(ticket);

  if (score >= 70) {
    return {
      quality: 'GOOD',
      enrichmentNeeded: false,
      originalTicket: ticket
    };
  }

  // Generate enrichments
  const enriched = {
    original: ticket,
    acceptanceCriteria: generateAcceptanceCriteria(ticket),
    edgeCases: identifyEdgeCases(ticket),
    testScenarios: defineTestScenarios(ticket),
    prerequisites: extractPrerequisites(ticket),
    securityConsiderations: analyzeSecurityNeeds(ticket)
  };

  return {
    quality: score < 50 ? 'POOR' : 'FAIR',
    enrichmentNeeded: true,
    enrichedTicket: enriched
  };
}
```

## Benefits

1. **Higher Quality Implementations**
   - All requirements explicit before coding starts
   - Edge cases identified upfront
   - Test requirements clear

2. **Reduced Review Cycles**
   - Fewer "what about..." questions
   - Complete implementations on first try
   - Better test coverage

3. **Better Estimations**
   - True complexity revealed
   - Hidden requirements surfaced
   - More accurate timelines

4. **Learning System**
   - Patterns learned from past tickets
   - Common edge cases database
   - Domain-specific rules

## Example: Before & After

### Before (Original Ticket)

```
Title: Add export CSV feature

Description:
Users need to export data as CSV.

Requirements:
- Button in UI
- Export current view
```

**Quality Score: 35/100** (Missing AC, edge cases, tests, security)

### After (Enriched Ticket)

```
Title: Add export CSV feature

Description:
Users need to export data as CSV.

## Acceptance Criteria

### AC1: Export Button Available
Given: User is on data table view
When: User clicks "Export CSV" button
Then: Download begins with current filtered data

### AC2: Large Dataset Handling
Given: User has >10,000 rows filtered
When: User clicks export
Then: System queues export job, notifies when ready

### AC3: Empty Data Handling
Given: No data matches current filters
When: User clicks export
Then: System shows "No data to export" message

## Edge Cases

- Empty result set → Show helpful message
- >100k rows → Use async job queue
- Special characters in data → Proper CSV escaping
- Concurrent exports → Rate limit per user (max 3)
- Browser compatibility → Test in Safari, Chrome, Firefox

## Test Requirements

### Unit Tests (>85% coverage)
- [ ] CSV generation with sample data
- [ ] CSV escaping for special chars
- [ ] Empty data handling
- [ ] Large dataset pagination

### Integration Tests
- [ ] API endpoint /api/export/csv
- [ ] Job queue integration
- [ ] File storage integration

### E2E Tests
- [ ] Complete export workflow
- [ ] Download verification
- [ ] Error scenarios

## Prerequisites

### Backend
- celery task queue (if not exists)
- S3 bucket for temporary files (large exports)
- CSV library: python-csv >= 1.0

### Frontend
- File download utility
- Progress indicator component
- Toast notification system

## Security Considerations

- **Authorization:** User can only export data they have access to
- **Input Validation:** Sanitize column names, filter values
- **Rate Limiting:** Max 3 exports per user per hour
- **Data Exposure:** Respect column-level permissions
- **File Cleanup:** Auto-delete export files after 24h
```

**Quality Score: 95/100** (Comprehensive, ready for implementation)

## Implementation Recommendation

### Script Structure

```bash
# Phase 0: Ticket Analysis (NEW)
echo "[STATS] Analyzing ticket quality..."

# Spawn ticket-analyzer agent
# Input: Linear ticket data
# Output: Quality score + enriched ticket (if needed)

if [ $QUALITY_SCORE -lt 70 ]; then
  echo "[WARN]  Ticket needs enrichment (score: $QUALITY_SCORE)"
  echo "[NEW] Generating acceptance criteria, edge cases, tests..."
  # Use enriched ticket for planning
else
  echo "[DONE] Ticket quality good (score: $QUALITY_SCORE)"
  # Use original ticket
fi

# Phase 1: Planning
# ... existing planning flow ...
```

### Agent Configuration

```yaml
ticket-analyzer:
  type: reviewer
  specialization: ticket-quality-analysis
  capabilities:
    - acceptance-criteria-generation
    - edge-case-identification
    - test-scenario-definition
    - security-analysis
  output: /tmp/ruflo-ticket-enriched-{TICKET_ID}.md
  run_in_background: true
```

## Next Steps

1. **Prototype:** Build ticket analyzer agent
2. **Test:** Run on 10 past tickets, measure score distribution
3. **Refine:** Adjust scoring weights based on results
4. **Integrate:** Add Phase 0 to automation script
5. **Monitor:** Track enrichment effectiveness (fewer review cycles?)

## Questions to Resolve

1. Should enrichment be written back to Linear or kept local?
   - **Recommendation:** Keep local (/tmp) to avoid Linear clutter

2. Should enrichment be mandatory or conditional?
   - **Recommendation:** Always analyze, conditionally enrich (score < 70)

3. How to handle disagreements between analyzer and human?
   - **Recommendation:** Log disagreements, learn patterns over time

4. Should user review enrichment before planning?
   - **Recommendation:** No - fully autonomous, but show enrichment in plan context
