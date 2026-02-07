# Gap Analysis: Agent Team Structure vs. Tier-1 Team Composition

## Documents Compared
- **Agent Plan:** `docs/plans/2026-02-06-agent-team-structure.md` — agent-powered org (12-22 agents)
- **Team Composition:** `team-composition.md` — tier-1 human org (60-75 headcount)

---

## Gap Analysis: What the Agent Plan Is Missing

### GAP 1: No Product Management Function (CRITICAL)

**Team-composition has:** 4-5 PMs who decide WHAT to build and WHY. "PMs at this level are strategic — they do not manage tasks."

**Agent plan has:** Nothing. Architecture team designs HOW, but nobody owns WHAT/WHY.

**The problem:** Without a PM-equivalent, you're making every product decision yourself with no structured analysis. You might build the wrong thing faster.

**Recommended fix — Add: Product Strategy Agent (1)**
- Analyzes user feedback, App Store reviews, competitor apps, market data
- Prioritizes features based on impact vs. effort
- Writes problem statements and success metrics for each feature
- Outputs a prioritized backlog with rationale
- SOP: `docs/sops/product-strategy.md`

**What stays with you:** Final prioritization decisions. The agent does the research and framing; you decide what ships.

---

### GAP 2: No Design/UX Function (HIGH)

**Team-composition has:** 5-6 designers including a UX Researcher ("non-negotiable at tier-1 — they are a forcing function against building the wrong thing").

**Agent plan has:** Zero. Agents can't do visual design, but they CAN do a lot of design-adjacent work.

**Recommended fix — Add: UX & Accessibility Team (2 agents)**

| Agent | What it does |
|-------|-------------|
| **Accessibility Auditor** | VoiceOver/TalkBack compliance, Dynamic Type support, color contrast ratios, touch target sizes. Runs automated checks + produces remediation list |
| **UX Consistency Agent** | Reviews UI code for consistent spacing, naming, string formatting, error state handling, microcopy tone. Cross-references iOS and Android for parity |

**What stays with you:** Visual design decisions, icon/screenshot creation, subjective "feel" assessments.

**SOP:** `docs/sops/ux-accessibility.md`

---

### GAP 3: No Data & Analytics Team (HIGH)

**Team-composition has:** 3-5 (Data Engineering Lead, Analytics Engineer, ML Engineer, Data Analyst).

**Agent plan has:** Zero. No agent tracks whether features actually work for users after shipping.

**Recommended fix — Add: Analytics & Insights Team (1-2 agents)**

| Agent | What it does |
|-------|-------------|
| **Analytics Instrumentation Agent** | Adds analytics events to new features (if Firebase/analytics SDK is integrated). Ensures consistent event naming. Verifies all key user flows have tracking |
| **Insights Agent** | Post-release: analyzes crash reports, App Store reviews, usage patterns. Produces a "health report" after each release with actionable findings |

**When to activate:** After initial App Store launch. Not needed pre-launch.

**SOP:** `docs/sops/analytics-insights.md`

---

### GAP 4: No TPM / Cross-Team Coordination Agent (HIGH)

**Team-composition says:** "Once you have 4+ engineering teams that must coordinate, the combinatorial complexity of dependencies exceeds what any single EM or PM can track."

**Agent plan has:** No coordination layer. With 8 teams and 12-22 agents, who tracks dependencies?

**Recommended fix — Add: Coordination Agent (1)**

This agent acts as a TPM — it doesn't make technical decisions, it tracks the dependency graph:
- Before any team starts work, checks if another team is modifying the same files
- Maintains a "current work" state file listing all active branches and which files they touch
- Flags conflicts early ("iOS Feature Agent and QA Unit Test Agent are both modifying SweepingRuleEngine.swift")
- Produces a daily status summary: what's in-flight, what's blocked, what's ready for review

**SOP:** `docs/sops/coordination.md`

**This is the single highest-leverage addition.** Without it, agent teams can silently conflict — one agent refactors a file while another is writing tests against the old structure.

---

### GAP 5: No Platform/Infra Specialization Within Dev Teams (MEDIUM)

**Team-composition says:** "The Platform/Infra engineer is the most under-hired role in mobile. This role is **invisible but load-bearing** — without it, build times destroy velocity."

**Agent plan has:** All dev agents are generalists (Feature Agent, Bug Fix Agent, Refactor Agent). No agent owns build system health, modularization, or developer tooling.

**Recommended fix — Add Platform/Infra specialization to each dev team:**

| Platform | Infra Agent Responsibilities |
|----------|------------------------------|
| **iOS** | XcodeGen project maintenance, build time optimization, SwiftLint rule management, shared framework extraction, DerivedData caching strategy |
| **Android** | Gradle optimization (build cache, dependency resolution), module architecture, ktlint/detekt configuration, ProGuard/R8 rules |

**Implementation:** Don't add new teams — add an infra specialization to the existing iOS and Android SOPs. When scaling to 3 agents, the third agent can be Infra-focused.

---

### GAP 6: No Performance Specialization (MEDIUM)

**Team-composition has:** Dedicated Performance & Quality engineers on each platform — "Startup time, frame rendering, memory profiling, crash-free rate, ANR elimination."

**Agent plan has:** Nothing. Performance is mentioned nowhere.

**Recommended fix — Add: Performance Reviewer to Code Review Team (4th agent)**
- Analyzes app startup flow for unnecessary work on main thread
- Reviews new code for performance anti-patterns (N+1 queries, blocking calls, large allocations in tight loops)
- Checks SQLite query plans for efficiency
- Profiles memory usage patterns in data-heavy operations (loading 37K street segments)

**SOP addition:** Add performance checks to `docs/sops/code-review.md`

---

### GAP 7: No Seniority / Model Tier Mapping (MEDIUM)

**Team-composition has:** "Seniority ratio target: 30-40% senior (L5+), 50-60% mid (L4), 0-10% junior (L3)."

**Agent plan has:** All agents are treated equally. No guidance on which Claude model to use for which team.

**Recommended mapping:**

| Agent Role | Recommended Model | Why |
|-----------|-------------------|-----|
| Architecture / Planning | **Opus** | Needs deepest reasoning, architectural judgment |
| Code Review (all 4) | **Opus** | Must catch subtle bugs, security issues |
| Security Audit | **Opus** | Requires careful analysis, can't afford false negatives |
| iOS / Android Feature Dev | **Sonnet** | Good balance of speed and quality for implementation |
| QA Unit Test Agent | **Sonnet** | Test writing needs good coverage instinct |
| QA Regression Agent | **Haiku** | Mostly running commands and comparing output |
| QA Test Plan Agent | **Sonnet** | Needs understanding of user flows |
| Documentation | **Haiku** | Structured, template-driven work |
| DevOps / CI/CD | **Sonnet** | YAML/config work, moderate complexity |
| Coordination Agent | **Haiku** | File tracking, status reporting |
| Product Strategy | **Opus** | Strategic thinking, market analysis |
| UX & Accessibility | **Sonnet** | Pattern matching, checklist execution |
| Analytics & Insights | **Sonnet** | Data analysis, report generation |

**Cost implication:** Using Opus for everything is expensive. Tier the models like you'd tier seniority — senior judgment where it matters, junior speed where it doesn't.

---

### GAP 8: No Scaling Model (LOW-MEDIUM)

**Team-composition has:** Launch → Growth → Scale phases with specific structural shifts at each stage.

**Agent plan has:** Static structure. No guidance on how the org evolves as EasyStreet grows.

**Recommended scaling model for agents:**

| Phase | Agent Count | Key Shift |
|-------|------------|-----------|
| **Pre-Launch** (now) | 6-8 | Single-platform focus (iOS). QA + Review + Architecture. No analytics |
| **Launch** (v1.0 shipped) | 12-16 | Add Android dev team. Add Analytics team. Full QA and Review |
| **Growth** (multi-city) | 16-22 | Add Coordination Agent. Platform/Infra specialization. Feature pods (cross-platform agents per feature) |
| **Scale** (100K+ users) | 20-28+ | Dedicated Performance team. Dedicated Accessibility team. Multiple feature pods running simultaneously |

---

### GAP 9: QA Model Mismatch (LOW-MEDIUM)

**Team-composition says:** "QA is shifting from a gatekeeper model to an **enablement model**. SDETs build test infrastructure and frameworks. Feature engineers write their own tests."

**Agent plan has:** QA agents *write* tests. Dev agents don't.

**Recommended shift:**
- Dev agents should write unit tests as part of their SOP (they already do, per the SOPs)
- QA Unit Test Agent should shift from "write tests" to "audit test coverage and write **missing** tests"
- QA team focus should be: test infrastructure, test frameworks, coverage analysis, gap identification
- This is more of a framing change than a structural one — update the QA SOP language

---

### GAP 10: No Cross-Platform Shared Logic Consideration (LOW)

**Team-composition discusses KMP:** "Recommended approach: shared networking, data models, and business logic via KMP; native UI."

**Agent plan has:** iOS and Android teams are fully independent.

**Relevance to EasyStreet:** Low right now. Both platforms share the same CSV data and business logic (sweeping rules, holiday calculation) but implement it independently. If the codebase grows, a **Parity Audit Agent** that compares iOS and Android implementations for behavioral differences would be valuable.

**No structural change needed yet.** Add to the Growth-phase scaling plan.

---

## What the Agent Plan Does Better Than Team-Composition

Not all gaps favor team-composition. The agent plan has structural advantages:

1. **Parallel execution** — team-composition describes a sequential human workflow. The agent plan runs 3-4 code reviewers simultaneously, 4 QA agents at once, etc. This is a structural advantage humans can't replicate without massive headcount.

2. **Zero context-switching cost** — each agent is single-purpose. Human engineers context-switch between features, reviews, meetings. Agents don't.

3. **Consistent standards via SOPs** — every agent follows the exact same SOP every time. Human teams have style drift, review quality variation, and "Friday afternoon code."

4. **Instant scaling** — need 3 more QA agents for a release? Spin them up. Human teams take months to hire.

5. **No politics** — team-composition warns about the "shadow Tech Lead" anti-pattern and EM/TL misalignment. Agents don't have ego conflicts.

6. **24/7 availability** — agents don't have meetings, PTO, or burnout.

---

## Summary: Recommended Changes

### New Teams/Agents to Add (5-6 agents)

| Addition | Agents | Priority |
|----------|--------|----------|
| **Coordination Agent** (TPM equivalent) | 1 | HIGH — prevents agent conflicts |
| **UX & Accessibility Team** | 2 | HIGH — tier-1 table stakes |
| **Product Strategy Agent** | 1 | MEDIUM — you're doing this manually now |
| **Analytics & Insights Team** | 1-2 | LOW — post-launch |

### Modifications to Existing Teams

| Change | Team | Priority |
|--------|------|----------|
| Add Performance Reviewer (4th lens) | Code Review | HIGH |
| Add model tier guidance (Opus/Sonnet/Haiku) | All teams | MEDIUM |
| Add Platform/Infra specialization | iOS Dev, Android Dev | MEDIUM |
| Shift QA from test-writer to enablement model | QA | MEDIUM |
| Add threat modeling to SOP | Security | MEDIUM |
| Add developer experience ownership | DevOps | LOW |
| Add scaling phases | Org structure | LOW |

### Revised Headcount: 16-28 agents (up from 12-22)
