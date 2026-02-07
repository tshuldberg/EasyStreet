# EasyStreet: Agent-Powered Engineering Organization

## Operating Model

**You** = Engineering Director. You make all decisions, approve plans, and own the product.
**Claude Code Agent Teams** = Your engineering staff. Each team has a specific mandate, headcount, and Standard Operating Procedure (SOP).

Every team's SOP lives in `docs/sops/` as a markdown file that agents are instructed to follow. SOPs are living documents — you update them as processes evolve.

**Gap analysis:** See `docs/plans/2026-02-06-agent-plan-gap-analysis.md` for the full comparison against `team-composition.md` (tier-1 human org).

---

## Organization Chart

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                         YOU — Engineering Director                             │
│           Decisions · Approvals · Product Direction · QA on Device              │
├─────────────┬─────────────┬───────────────────┬───────────────────────────────┤
│  Product    │ Coordination│   Architecture    │  UX & Accessibility           │
│  Strategy   │ Agent       │   & Planning      │  Team (2)                     │
│  (1)        │ (1)         │   (1-2)           │                               │
├─────────────┴─────────────┴───────────────────┴───────────────────────────────┤
│  iOS Dev    │ Android Dev │   QA Team         │  Code Review Team             │
│  Team (2-3) │ Team (2-3)  │   (3-4)           │  (4)                          │
├─────────────┴─────────────┴───────────────────┴───────────────────────────────┤
│  DevOps /   │ Security &  │   Documentation   │  Analytics & Insights         │
│  Release (2)│ Compliance  │   Team (1-2)      │  (1-2, post-launch)           │
│             │ (1-2)       │                   │                               │
└─────────────┴─────────────┴───────────────────┴───────────────────────────────┘
```

---

## Model Tier Mapping

Not all agents need the same capability level. Tier the models like seniority — senior judgment where it matters, speed where it doesn't.

| Agent Role | Recommended Model | Rationale |
|-----------|-------------------|-----------|
| Architecture / Planning | **Opus** | Deepest reasoning, architectural judgment |
| Code Review (all 4) | **Opus** | Must catch subtle bugs, security issues, performance |
| Security Audit | **Opus** | Can't afford false negatives |
| Product Strategy | **Opus** | Strategic thinking, market analysis |
| iOS / Android Feature Dev | **Sonnet** | Good speed/quality balance for implementation |
| QA Unit Test Agent | **Sonnet** | Test writing needs good coverage instinct |
| QA Integration Test Agent | **Sonnet** | Needs understanding of component interactions |
| QA Test Plan Agent | **Sonnet** | Needs understanding of user flows |
| QA Regression Agent | **Haiku** | Mostly running commands and comparing output |
| UX & Accessibility | **Sonnet** | Pattern matching, checklist execution |
| Analytics & Insights | **Sonnet** | Data analysis, report generation |
| Documentation | **Haiku** | Structured, template-driven work |
| DevOps / CI/CD | **Sonnet** | YAML/config work, moderate complexity |
| Coordination Agent | **Haiku** | File tracking, status reporting |

---

## Team Definitions

### 1. Product Strategy Agent (NEW)

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1 |
| **Model** | Opus |
| **SOP file** | `docs/sops/product-strategy.md` |
| **Input** | Feature ideas, user feedback, market context from you |
| **Output** | Prioritized backlog with problem statements, success metrics, and rationale |

**Why this team?** Without a PM-equivalent, you make every product decision with no structured analysis. This agent does the research and framing; you decide what ships.

**Responsibilities:**
- Analyze user feedback, App Store reviews, competitor apps
- Prioritize features based on impact vs. effort
- Write problem statements and success metrics for each proposed feature
- Maintain a structured backlog document
- Research market trends and competitive landscape

**What stays with you:** Final prioritization decisions. The agent proposes; you dispose.

---

### 2. Coordination Agent (NEW)

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1 |
| **Model** | Haiku |
| **SOP file** | `docs/sops/coordination.md` |
| **Input** | Current branch state, active work across all teams |
| **Output** | Status summaries, conflict warnings, dependency tracking |

**Why this team?** With 12+ agents across 8+ teams, nobody tracks cross-team dependencies. Without coordination, agents silently conflict — one refactors a file while another writes tests against the old structure.

**Responsibilities:**
- Before any team starts work, check if another team is modifying the same files
- Maintain a "current work" state file listing all active branches and file ownership
- Flag conflicts early ("iOS Feature Agent and QA Unit Test Agent are both modifying SweepingRuleEngine.swift")
- Produce status summaries: what's in-flight, what's blocked, what's ready for review
- Track the dependency graph between tasks

**This is the single highest-leverage addition.** The TPM equivalent for agent teams.

---

### 3. Architecture & Planning Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1-2 |
| **Model** | Opus |
| **When to scale** | 2 agents for major features or cross-platform work |
| **SOP file** | `docs/sops/architecture-planning.md` |
| **Input** | Feature request or problem statement from you |
| **Output** | Implementation plan with file paths, approach, risks, estimates |

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **Planning Agent** | Spec writer | Explores codebase, identifies affected files, designs approach, writes implementation plan |
| **Impact Analysis Agent** | Risk assessor | Analyzes a proposed plan for risks, conflicts with existing code, performance concerns, missing edge cases |

**SOP Summary:**
1. **Planning Agent:**
   - Explore the codebase thoroughly before proposing anything
   - Identify all files that will be modified
   - Reference existing patterns and utilities to reuse
   - Produce a numbered task list with dependencies
   - Include verification steps
2. **Impact Analysis Agent:**
   - Review the plan against current codebase state
   - Flag conflicts (two plans touching same file)
   - Identify risks (data migration needed? breaking changes?)
   - Estimate complexity (S/M/L per task)
   - Recommend whether to proceed, revise, or split the plan

---

### 4. UX & Accessibility Team (NEW)

| Attribute | Detail |
|-----------|--------|
| **Agents** | 2 |
| **Model** | Sonnet |
| **SOP file** | `docs/sops/ux-accessibility.md` |
| **Input** | New/modified UI code, feature branches |
| **Output** | Accessibility audit report, UX consistency findings, remediation list |

**Why this team?** Accessibility is tier-1 table stakes. Agents can't do visual design, but they CAN enforce accessibility standards and UI consistency.

**Agent Specializations:**

| Agent | Focus | What it does |
|-------|-------|-------------|
| **Accessibility Auditor** | A11y compliance | VoiceOver/TalkBack labels, Dynamic Type support, color contrast ratios (WCAG AA), touch target sizes (44pt minimum), semantic markup |
| **UX Consistency Agent** | Cross-platform parity | Reviews UI code for consistent spacing, naming conventions, string formatting, error state handling, microcopy tone. Cross-references iOS and Android for behavioral parity |

**What stays with you:** Visual design decisions, icon/screenshot creation, subjective "feel" assessments.

---

### 5. iOS Development Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 2-3 (parallel via git worktrees) |
| **Model** | Sonnet |
| **When to scale** | 3 agents when 2+ independent features are in-flight |
| **SOP file** | `docs/sops/ios-development.md` |
| **Tools** | Xcode, xcodebuild, XcodeGen, SwiftLint |
| **Input** | Approved spec/plan from Architecture team |
| **Output** | Feature branch with code + unit tests + passing build |

**Agent Specializations:**
- **Feature Agent(s)** — Implements new features on isolated worktree branches
- **Bug Fix Agent** — Triages and fixes bugs from QA team reports
- **Platform/Infra Agent** (when scaled to 3) — XcodeGen project maintenance, build time optimization, SwiftLint rule management, shared framework extraction, DerivedData caching strategy

**SOP Summary:**
1. Read the approved plan and relevant existing code before writing anything
2. Branch from `main` using naming convention `feature/`, `bugfix/`, `refactor/`
3. Follow existing patterns in the codebase (MVC, repository pattern, singletons)
4. Write unit tests for all new logic (minimum: happy path + 2 edge cases)
5. Run `xcodebuild build` and `xcodebuild test` — both must pass
6. Run SwiftLint — zero violations
7. Self-review the diff before declaring work complete
8. Output: branch name, files changed, test results, known limitations

---

### 6. Android Development Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 2-3 (parallel via git worktrees) |
| **Model** | Sonnet |
| **When to scale** | 3 agents when achieving feature parity push |
| **SOP file** | `docs/sops/android-development.md` |
| **Tools** | Gradle, ktlint/detekt, Android SDK |
| **Input** | Approved spec/plan from Architecture team |
| **Output** | Feature branch with code + unit tests + passing build |

**Agent Specializations:**
- **Feature Agent(s)** — Implements features (Compose UI + ViewModel + Repository)
- **Parity Agent** — Ports iOS features to Android, adapting patterns to Kotlin/Compose
- **Platform/Infra Agent** (when scaled to 3) — Gradle optimization (build cache, dependency resolution), module architecture, ktlint/detekt configuration, ProGuard/R8 rules

**SOP Summary:**
1. Read the approved plan and equivalent iOS implementation for reference
2. Follow MVVM + Compose patterns established in the codebase
3. Write unit tests (JUnit) for ViewModels and business logic
4. Run `./gradlew build` and `./gradlew test` — both must pass
5. Run ktlint — zero violations
6. Self-review diff before declaring complete
7. Output: branch name, files changed, test results

---

### 7. QA Team (Enablement Model)

| Attribute | Detail |
|-----------|--------|
| **Agents** | 3-4 (this is where parallelism pays off most) |
| **Model** | Sonnet (Unit, Integration, Test Plan) / Haiku (Regression) |
| **When to scale** | 4 agents during release candidate testing |
| **SOP file** | `docs/sops/qa-testing.md` |
| **Input** | Merged feature branch or release candidate |
| **Output** | Test reports, coverage analysis, sign-off or rejection |

**Operating model:** Enablement, not gatekeeping. Dev agents write their own unit tests. QA agents audit coverage, find gaps, build test infrastructure, and write *missing* tests. This follows the tier-1 pattern where "SDETs build test infrastructure and frameworks; feature engineers write their own tests."

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **Test Coverage Auditor** | Gap finder | Reads new/changed code, audits existing tests for gaps, writes *missing* tests covering edge cases, error conditions, boundary values. Reports coverage delta |
| **Integration Test Agent** | Cross-component tester | Tests interactions between components (e.g., does parking pin → notification → sweeping rule pipeline work end-to-end?) |
| **Regression Agent** | Full suite runner | Runs entire test suite after every merge, compares results to baseline, flags new failures with exact failing test + likely cause |
| **Test Plan Agent** | Manual test plan creator | Generates step-by-step manual test plans for you to execute on a real device (things agents can't test: GPS, notifications, UI feel) |

**QA Gate:** A feature cannot be released until:
- Unit test coverage ≥ 80% for changed files
- Zero regression failures
- Manual test plan executed by you with all items checked

---

### 8. Code Review Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 4 (run in parallel on every PR) |
| **Model** | Opus |
| **SOP file** | `docs/sops/code-review.md` |
| **Input** | PR diff + full file context |
| **Output** | Review report with approve/request-changes + specific findings |

**Why 4 agents?** Each reviewer has a different lens. Tier-1 companies get this by having 2-3 senior engineers review every PR. You get it by running 4 focused agents in parallel.

**Agent Specializations:**

| Agent | Focus | Checks |
|-------|-------|--------|
| **Correctness Reviewer** | Logic & behavior | Does the code do what the spec says? Are there off-by-one errors? Missing nil checks? Race conditions? Correct algorithm? |
| **Security Reviewer** | Vulnerabilities & data | No hardcoded secrets? No SQL injection? Proper input validation? Permissions handled correctly? Data encrypted at rest? |
| **Architecture Reviewer** | Patterns & maintainability | Follows existing patterns? No unnecessary abstractions? No dead code? Proper separation of concerns? Naming conventions? |
| **Performance Reviewer** (NEW) | Speed & efficiency | Main-thread blocking? Excessive allocations? Unoptimized SQLite queries? Missing caching? Redundant computations? N+1 patterns? Memory leaks? |

**SOP Summary:**
1. Read the full PR diff and all modified files in their entirety (not just the diff)
2. Read the spec/plan that motivated the change
3. Each agent produces a structured review:
   ```
   ## [Agent Name] Review

   ### Verdict: APPROVE | REQUEST_CHANGES | COMMENT

   ### Critical Issues (must fix before merge)
   - [file:line] Description of issue

   ### Suggestions (improve but not blocking)
   - [file:line] Description of suggestion

   ### Positive Notes
   - What was done well
   ```
4. **Merge rule:** All 4 agents must APPROVE or COMMENT. Any single REQUEST_CHANGES blocks the merge.
5. After developer addresses feedback, re-run the requesting agent(s) only

---

### 9. DevOps / Release Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 2 |
| **Model** | Sonnet |
| **SOP file** | `docs/sops/devops-release.md` |
| **Input** | CI/CD requirements, release requests |
| **Output** | Working pipelines, release artifacts, deployment status |

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **CI/CD Agent** | Pipeline engineer + DX owner | Creates and maintains GitHub Actions workflows, caching, build optimization. Also owns developer experience: build time monitoring, flaky test detection/quarantine, PR size monitoring (flag >500 lines), branch cleanup |
| **Release Agent** | Release manager | Cuts release branches, bumps versions, generates changelogs, coordinates submission checklist |

**SOP Summary:**
1. **CI/CD Agent:**
   - Maintain `.github/workflows/` files
   - Every PR must trigger: lint → build → test
   - Cache dependencies (DerivedData, Gradle) for speed
   - Alert on flaky tests (same test fails intermittently)
   - Monitor build times — alert if CI exceeds 5 minutes
   - Flag PRs >500 lines as too large to review effectively
2. **Release Agent:**
   - Follow release checklist exactly
   - Bump version in Info.plist / build.gradle
   - Generate changelog from commit messages since last release
   - Verify all QA sign-offs exist before proceeding
   - Tag the release in git

---

### 10. Security & Compliance Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1-2 |
| **Model** | Opus |
| **When to scale** | 2 agents before App Store / Play Store submission |
| **SOP file** | `docs/sops/security-compliance.md` |
| **Input** | Codebase snapshot, privacy policy, store requirements |
| **Output** | Audit report, threat model, compliance checklist, remediation tasks |

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **Security Audit Agent** | Vulnerability scanner + threat modeler | Reviews code for OWASP Mobile Top 10, checks dependencies for known CVEs, verifies no secrets in repo. **Also produces threat model:** what data is stored, what attack surfaces exist, what happens if the SQLite DB is extracted from device |
| **Compliance Agent** | Store requirements | Verifies App Store / Play Store guidelines compliance, privacy policy accuracy, permission justifications, data handling declarations |

**SOP Summary:**
1. **Security Audit Agent:**
   - Scan all source files for hardcoded secrets, API keys, credentials
   - Check Info.plist / AndroidManifest.xml for unnecessary permissions
   - Review data storage (is sensitive data encrypted? using Keychain/EncryptedSharedPreferences?)
   - Check network calls (HTTPS only? certificate pinning?)
   - Review dependencies for known vulnerabilities
   - **Produce threat model** before each release (data flows, attack surfaces, trust boundaries)
   - Maintain a "security assumptions" document
   - Output: findings ranked by severity (Critical/High/Medium/Low)
2. **Compliance Agent:**
   - Cross-reference app behavior with privacy policy claims
   - Verify all permission usage descriptions are accurate and user-friendly
   - Check App Store Review Guidelines compliance (no private APIs, proper attribution)
   - Verify age rating accuracy
   - Check accessibility (VoiceOver/TalkBack support)

---

### 11. Documentation Team

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1-2 |
| **Model** | Haiku |
| **SOP file** | `docs/sops/documentation.md` |
| **Input** | Merged code changes, release milestones |
| **Output** | Updated docs, changelogs, API docs, timeline entries |

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **Code Docs Agent** | Internal documentation | Updates CLAUDE.md, README.md, inline documentation for complex logic, architecture decision records |
| **Release Docs Agent** | External documentation | Writes App Store release notes, changelog entries, user-facing help text, privacy policy updates |

**SOP Summary:**
1. After each sprint/release, review all merged PRs
2. Update CLAUDE.md with any new patterns, files, or conventions
3. Update timeline.md per the existing timeline requirements
4. Generate changelog from structured commit messages
5. Write user-facing release notes (plain language, not technical)

---

### 12. Analytics & Insights Team (NEW — Post-Launch)

| Attribute | Detail |
|-----------|--------|
| **Agents** | 1-2 |
| **Model** | Sonnet |
| **When to activate** | After initial App Store launch |
| **SOP file** | `docs/sops/analytics-insights.md` |
| **Input** | Crash reports, App Store reviews, usage data |
| **Output** | Health reports, instrumentation code, actionable insights |

**Agent Specializations:**

| Agent | Role | What it does |
|-------|------|-------------|
| **Analytics Instrumentation Agent** | Event tracking | Adds analytics events to new features (once Firebase/analytics SDK is integrated). Ensures consistent event naming. Verifies all key user flows have tracking |
| **Insights Agent** | Post-release analysis | Analyzes crash reports, App Store reviews, usage patterns. Produces a "health report" after each release with actionable findings |

---

## Team Coordination: How It All Fits Together

### Feature Development Flow (Full Pipeline)

```
YOU: "I want to add parking history"
    │
    ▼
PRODUCT STRATEGY (1 agent)
    ├── Researches: who needs this? what's the success metric?
    └── Output: problem statement + success criteria
    │
    ▼
YOU: Approve the problem framing
    │
    ▼
COORDINATION AGENT checks for conflicts with in-flight work
    │
    ▼
ARCHITECTURE TEAM (1-2 agents)
    ├── Planning Agent explores codebase, writes spec
    ├── Impact Agent reviews spec for risks
    └── Output: approved implementation plan
    │
    ▼
YOU: Review and approve plan
    │
    ▼
DEVELOPMENT TEAM (2-3 agents, parallel worktrees)
    ├── iOS Agent implements on feature/parking-history-ios
    ├── Android Agent implements on feature/parking-history-android
    └── Output: feature branches with code + tests
    │
    ▼
QA TEAM (3-4 agents, parallel)
    ├── Test Coverage Auditor finds gaps, writes missing tests
    ├── Integration Test Agent tests cross-component flows
    ├── Regression Agent runs full suite
    └── Test Plan Agent creates manual test checklist for you
    │
    ▼
CODE REVIEW TEAM (4 agents, parallel on each PR)
    ├── Correctness Reviewer
    ├── Security Reviewer
    ├── Architecture Reviewer
    ├── Performance Reviewer
    └── Output: approve or request changes per PR
    │
    ▼
UX & ACCESSIBILITY TEAM (2 agents)
    ├── Accessibility Auditor checks a11y compliance
    ├── UX Consistency Agent checks cross-platform parity
    └── Output: remediation list or approval
    │
    ▼
YOU: Execute manual test plan on real device
    │
    ▼
YOU: Approve merge
    │
    ▼
DEVOPS TEAM (1-2 agents)
    ├── CI validates the merge
    ├── Release Agent cuts release branch when ready
    └── Output: release candidate build
    │
    ▼
SECURITY TEAM (1-2 agents, before store submission)
    ├── Security audit + threat model of release candidate
    ├── Compliance check against store guidelines
    └── Output: go/no-go recommendation
    │
    ▼
DOCUMENTATION TEAM (1-2 agents)
    ├── Update changelogs, release notes
    ├── Update CLAUDE.md, timeline.md
    └── Output: all docs current
    │
    ▼
YOU: Submit to App Store / Play Store
    │
    ▼
ANALYTICS TEAM (1-2 agents, post-launch)
    ├── Verify instrumentation is live
    ├── Produce health report after 48 hours
    └── Output: release health assessment
```

### Parallel Execution Map

```
Time ──────────────────────────────────────────────────────────────────►

Phase 1: Strategy & Planning (sequential — needs your approval)
  [Product Strategy: 1 agent]  → YOU approve problem framing
  [Coordination: 1 agent]     → conflict check
  [Architecture: 1-2 agents]  → YOU approve plan

Phase 2: Development (parallel across platforms)
  [iOS Dev: 1-2 agents    ████████████]
  [Android Dev: 1-2 agents █████████]

Phase 3: Quality (parallel across all dimensions)
  [QA Coverage Audit: 1    ████████]
  [QA Integration: 1       ████████]
  [QA Regression: 1        ████████]
  [QA Test Plans: 1        ████████]
  [Review Correctness: 1   ████]
  [Review Security: 1      ████]
  [Review Architecture: 1  ████]
  [Review Performance: 1   ████]
  [UX Accessibility: 1     ████]
  [UX Consistency: 1       ████]

Phase 4: Release (sequential — needs your sign-off)
  [Security Audit: 1-2]    → YOU sign off
  [Documentation: 1-2]     → release notes
  [Release: 1]              → YOU submit

Phase 5: Post-Release (post-launch only)
  [Analytics: 1-2]          → health report

Max concurrent agents: ~16-18
Typical concurrent agents: 8-12
```

---

## Standard Operating Procedures (SOPs)

### SOP File Structure

All SOPs live in `docs/sops/` and follow this template:

```markdown
# [Team Name] Standard Operating Procedure

## Purpose
One sentence describing this team's mission.

## Trigger
When is this team activated? What input do they receive?

## Prerequisites
What must be true before this team starts work?

## Procedure
Numbered steps the agent must follow, in order.

## Output Format
Exact structure of what the agent produces.

## Quality Gates
What must be true for the work to be considered complete?

## Escalation
When should the agent stop and ask YOU for a decision?

## Anti-Patterns
Common mistakes this agent should avoid.

## References
Links to relevant files, patterns, and examples in the codebase.
```

### SOPs to Create (12 total)

| SOP File | Team | Key Contents |
|----------|------|-------------|
| `docs/sops/product-strategy.md` | Product Strategy | Backlog format, prioritization framework, problem statement template |
| `docs/sops/coordination.md` | Coordination | Conflict detection, status format, dependency tracking |
| `docs/sops/architecture-planning.md` | Architecture | How to explore codebase, plan template, impact analysis criteria |
| `docs/sops/ux-accessibility.md` | UX & Accessibility | WCAG AA checklist, a11y audit format, cross-platform parity checks |
| `docs/sops/ios-development.md` | iOS Dev | Swift style guide, MVC patterns, test requirements, build commands, platform/infra duties |
| `docs/sops/android-development.md` | Android Dev | Kotlin style, MVVM/Compose patterns, Gradle commands, platform/infra duties |
| `docs/sops/qa-testing.md` | QA | Enablement model, coverage thresholds, report formats, manual test plan template |
| `docs/sops/code-review.md` | Code Review | Review checklist per focus area (correctness, security, architecture, performance), verdict criteria |
| `docs/sops/devops-release.md` | DevOps/Release | CI/CD maintenance, DX monitoring, release checklist, version bumping, changelog format |
| `docs/sops/security-compliance.md` | Security | OWASP checklist, threat model template, store guidelines checklist, audit report format |
| `docs/sops/documentation.md` | Documentation | Which docs to update when, changelog format, timeline entry format |
| `docs/sops/analytics-insights.md` | Analytics | Event naming conventions, health report format, instrumentation checklist |

---

## Agent Headcount Summary

| Team | Min Agents | Max Agents | Model Tier | Scale Trigger |
|------|-----------|-----------|------------|---------------|
| Product Strategy | 1 | 1 | Opus | Always active |
| Coordination | 1 | 1 | Haiku | Always active when 2+ teams working |
| Architecture & Planning | 1 | 2 | Opus | Major feature or cross-platform work |
| UX & Accessibility | 2 | 2 | Sonnet | Active on every UI-touching PR |
| iOS Development | 1 | 3 | Sonnet | 2+ independent features in-flight |
| Android Development | 1 | 3 | Sonnet | Feature parity push or 2+ features |
| QA | 3 | 4 | Sonnet/Haiku | Release candidate testing |
| Code Review | 4 | 4 | Opus | Always 4 (one per focus area) |
| DevOps / Release | 1 | 2 | Sonnet | Active release in progress |
| Security & Compliance | 1 | 2 | Opus | Pre-submission audit |
| Documentation | 1 | 2 | Haiku | Post-release documentation sprint |
| Analytics & Insights | 0 | 2 | Sonnet | Post-launch only |

**Total: 17 (min) to 28 (max peak) agents**
**Typical active: 10-14 agents**

---

## Scaling Model

| Phase | Agent Count | Key Shift |
|-------|------------|-----------|
| **Pre-Launch** (now) | 8-10 | Single-platform focus (iOS). Architecture + QA + Review + Security. No analytics, minimal Android |
| **Launch** (v1.0 shipped) | 14-18 | Add Android dev team at full strength. Activate Analytics team. Full QA and Review |
| **Growth** (multi-city) | 18-24 | Coordination Agent becomes critical. Platform/Infra specialization activates (3rd agent per dev team). Feature pods (cross-platform agents per feature rather than per platform) |
| **Scale** (100K+ users) | 22-28+ | Dedicated Performance team (split from Review). Multiple feature pods running simultaneously. UX team scales for multi-city design variations |

---

## What You (the Human) Must Do

Agents can't do everything. Here's what only you can do:

| Task | Why it requires you |
|------|-------------------|
| **Approve plans** | Strategic product decisions |
| **Final feature prioritization** | Product Strategy agent researches; you decide |
| **Test on real devices** | Agents can't tap a phone screen |
| **Test GPS/location** | Requires physical movement or device simulation you control |
| **Test push notifications** | Requires device with notification permissions |
| **Visual QA** | "Does this look right?" is subjective |
| **Visual design** | App icon, screenshots, UI aesthetics |
| **App Store / Play Store submission** | Requires your developer account credentials |
| **Approve merges to main** | Final authority on what ships |
| **Respond to App Review rejections** | Requires account access and judgment |
| **User support / feedback** | Requires human empathy and product knowledge |

---

## Implementation Sequence

### Phase 1: Create SOP Infrastructure (First)
- Create `docs/sops/` directory
- Write all 12 SOP files following the template above
- These become the "training material" for every agent team

### Phase 2: CI/CD Foundation
- GitHub Actions workflows (ios.yml, android.yml)
- Linting configs (SwiftLint, ktlint)
- Branch protection on main
- PR template, CODEOWNERS

### Phase 3: Process Dry Run
- Pick a small feature or bug fix
- Run the full pipeline with all teams
- Identify where SOPs need adjustment
- Update SOPs based on learnings

### Phase 4: Scale Up
- Run parallel feature development across platforms
- Use full QA and review teams
- Activate Coordination Agent
- Refine SOPs after each cycle

---

## Verification

- [ ] All 12 SOP files exist in `docs/sops/` and follow the template
- [ ] CI/CD runs on every PR (build + test + lint)
- [ ] Branch protection blocks merges without CI + review
- [ ] A test feature has been run through the full pipeline end-to-end
- [ ] SOPs have been updated based on dry run learnings
- [ ] Manual test plan template produces actionable checklists
- [ ] Review agents produce structured, non-overlapping feedback
- [ ] Coordination Agent successfully detects a file conflict
- [ ] Accessibility Auditor produces actionable findings
- [ ] Model tier mapping is documented and followed
