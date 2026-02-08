# Implementation Plan: `email-to-task` CLI

> **Date:** 2026-02-07
> **Status:** Research complete, ready for implementation
> **Type:** Standalone project (separate from EasyStreet, reusable across projects)

## Context

Build a standalone, reusable CLI tool that scans a Gmail inbox, uses Claude AI to identify actionable emails and extract structured tasks, then creates Linear issues automatically. Designed as an npm package that can be imported into other projects.

**Key decisions from research:**
- Gmail API (free, OAuth 2.0, push via Pub/Sub) for email access
- Two-stage LLM pipeline: Haiku triage (~$0.001/email) then Sonnet extraction (~$0.008/email)
- Confidence-based routing with human review queue
- Local-first architecture: PII redaction + SQLite dedup on-device, only sanitized content to Claude
- Estimated cost: ~$3-7/month for typical personal use (50 emails/day)

---

## Project Structure

```
email-to-task/                    # Standalone repo, separate from EasyStreet
├── package.json                  # npm package + CLI bin entry
├── tsconfig.json
├── tsup.config.ts                # esbuild-powered dual CJS/ESM build
├── .env.example
├── src/
│   ├── index.ts                  # Public programmatic API exports
│   ├── cli.ts                    # CLI entry point (commander.js)
│   ├── config/
│   │   ├── schema.ts             # Zod config validation
│   │   ├── loader.ts             # Config file + env + CLI flag merging
│   │   └── defaults.ts           # Default values
│   ├── auth/
│   │   ├── gmail.ts              # Gmail OAuth 2.0 + PKCE flow
│   │   ├── linear.ts             # Linear API key validation
│   │   ├── claude.ts             # Claude API key validation
│   │   └── keychain.ts           # macOS Keychain via `security` CLI
│   ├── email/
│   │   ├── client.ts             # Gmail API wrapper (list, get, history)
│   │   ├── parser.ts             # MIME decoding, HTML stripping, truncation
│   │   ├── watcher.ts            # Poll-based watch mode (Phase 3)
│   │   └── types.ts              # EmailMessage interface
│   ├── privacy/
│   │   ├── redactor.ts           # Regex-based PII redaction engine
│   │   ├── patterns.ts           # Email, phone, SSN, credit card, IP patterns
│   │   └── types.ts              # RedactionResult interface
│   ├── llm/
│   │   ├── client.ts             # Anthropic SDK wrapper + retry logic
│   │   ├── schemas.ts            # Zod schemas for triage + extraction outputs
│   │   ├── triage.ts             # Stage 1: Haiku classification
│   │   └── extractor.ts          # Stage 2: Sonnet task extraction
│   ├── tasks/
│   │   ├── linear.ts             # Linear SDK wrapper (create issue, list teams)
│   │   ├── mapper.ts             # Map LLM output to Linear issue fields
│   │   └── types.ts              # Task-related interfaces
│   ├── store/
│   │   ├── db.ts                 # SQLite init + migrations (better-sqlite3)
│   │   ├── emails.ts             # Processed emails table (dedup tracking)
│   │   ├── tasks.ts              # Created tasks audit trail
│   │   └── review-queue.ts       # Medium-confidence items awaiting review
│   └── utils/
│       ├── logger.ts             # Structured logging
│       ├── errors.ts             # Custom error classes
│       └── retry.ts              # Exponential backoff helper
├── test/
│   ├── fixtures/
│   │   ├── emails/               # Sample Gmail API response payloads
│   │   └── llm-responses/        # Mock Claude responses
│   ├── unit/                     # Tests for each module
│   └── integration/              # Full pipeline tests with mocked HTTP
└── data/                         # Runtime SQLite DB (gitignored)
```

---

## Data Flow

```
1. FETCH         Gmail API → list unread inbox messages
       ↓
2. DEDUP         SQLite → skip already-processed email IDs
       ↓
3. PARSE         Decode base64url MIME → plain text (HTML fallback) → truncate to 4000 chars
       ↓
4. REDACT        Regex PII patterns → replace with [EMAIL_1], [PHONE_1], etc.
       ↓
5. TRIAGE        Claude Haiku → { isActionable, confidence, category }
       ↓
6. ROUTE         ≥0.85 → auto-create | 0.50-0.84 → review queue | <0.50 → skip
       ↓
7. EXTRACT       Claude Sonnet → { title, description, priority, labels, dueDate }
       ↓
8. CREATE        Linear SDK → issueCreate mutation → returns issue URL
       ↓
9. RECORD        SQLite → log processed email + created task for audit trail
```

---

## CLI Commands

```bash
email-to-task configure gmail     # Run Gmail OAuth flow, store tokens in Keychain
email-to-task configure linear    # Set Linear API key
email-to-task configure claude    # Set Claude API key
email-to-task configure show      # Show current config (secrets masked)

email-to-task scan                # Scan inbox, triage, extract, create tasks
email-to-task scan --dry-run      # Preview without creating Linear issues
email-to-task scan --max 20       # Limit to 20 emails
email-to-task scan --since 2026-02-01  # Only emails after this date

email-to-task review              # Interactive approval of medium-confidence items
email-to-task status              # Processing stats and connection health
email-to-task history             # Recent processed emails and created tasks
email-to-task watch --interval 300  # Poll every 5 minutes (Phase 3)
```

---

## Key Schemas

**Triage output (Haiku):**
```typescript
const TriageResultSchema = z.object({
  isActionable: z.boolean(),
  confidence: z.number().min(0).max(1),
  category: z.enum(['bug_report', 'feature_request', 'question',
                     'meeting_action', 'follow_up', 'approval_needed', 'other']),
  reasoning: z.string(),
});
```

**Task extraction output (Sonnet):**
```typescript
const TaskExtractionSchema = z.object({
  title: z.string().max(120),
  description: z.string(),
  priority: z.enum(['urgent', 'high', 'medium', 'low', 'none']),
  labels: z.array(z.string()),
  dueDate: z.string().nullable(),
  assigneeHint: z.string().nullable(),
  sourceContext: z.object({
    emailSubject: z.string(),
    senderName: z.string(),
    receivedDate: z.string(),
  }),
});
```

---

## Authentication

| Service | Method | Storage |
|---------|--------|---------|
| Gmail | OAuth 2.0 + PKCE (localhost redirect) | macOS Keychain |
| Linear | Personal API key | macOS Keychain |
| Claude | API key | macOS Keychain |

Fallback: environment variables (`GMAIL_OAUTH_TOKEN`, `LINEAR_API_KEY`, `ANTHROPIC_API_KEY`) when Keychain unavailable.

---

## SQLite Schema

```sql
CREATE TABLE processed_emails (
  email_id      TEXT PRIMARY KEY,
  thread_id     TEXT NOT NULL,
  subject       TEXT,
  sender        TEXT,
  received_at   TEXT NOT NULL,
  processed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  triage_result TEXT,              -- JSON of TriageResult
  confidence    REAL,
  action_taken  TEXT NOT NULL,     -- 'created' | 'queued' | 'skipped'
  task_id       TEXT               -- Linear issue ID if created
);

CREATE TABLE created_tasks (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email_id      TEXT NOT NULL REFERENCES processed_emails(email_id),
  linear_id     TEXT NOT NULL,
  linear_url    TEXT,
  title         TEXT NOT NULL,
  priority      TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  auto_created  INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE review_queue (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email_id      TEXT NOT NULL REFERENCES processed_emails(email_id),
  extraction    TEXT NOT NULL,     -- JSON of TaskExtraction
  confidence    REAL NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'approved' | 'rejected'
  reviewed_at   TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Database location: `~/.email-to-task/data.db`

---

## Dependencies

**Runtime:**
| Package | Purpose |
|---------|---------|
| `google-auth-library` | Gmail OAuth 2.0 (lighter than full `googleapis`) |
| `@google-cloud/local-auth` | Local OAuth flow with PKCE |
| `@anthropic-ai/sdk` | Claude API client |
| `@linear/sdk` | Linear GraphQL client |
| `better-sqlite3` | Local SQLite |
| `zod` | Schema validation + structured output contracts |
| `commander` | CLI framework |
| `ora` | Terminal spinners |
| `chalk` | Terminal colors |
| `inquirer` | Interactive prompts (review command) |

**Dev:**
| Package | Purpose |
|---------|---------|
| `tsup` | Build (esbuild) |
| `typescript` | Type checking |
| `vitest` | Tests |
| `msw` | HTTP mocking |

---

## Build Phases

### Phase 1: MVP (~3-4 hours)
Build the core scan pipeline end-to-end.

**Create these files:**
1. Project scaffold: `package.json`, `tsconfig.json`, `tsup.config.ts`, `.env.example`
2. Config system: `src/config/schema.ts`, `defaults.ts`, `loader.ts`
3. Auth: `src/auth/keychain.ts`, `gmail.ts`, `linear.ts`, `claude.ts`
4. Email: `src/email/client.ts`, `parser.ts`, `types.ts`
5. Privacy: `src/privacy/redactor.ts`, `patterns.ts`, `types.ts`
6. LLM: `src/llm/client.ts`, `schemas.ts`, `triage.ts`, `extractor.ts`
7. Tasks: `src/tasks/linear.ts`, `mapper.ts`, `types.ts`
8. Store: `src/store/db.ts`, `emails.ts`
9. CLI: `src/cli.ts` (scan + configure commands)
10. Exports: `src/index.ts`

**What works after Phase 1:**
```bash
email-to-task configure gmail && email-to-task configure linear && email-to-task configure claude
email-to-task scan --max 10        # Process 10 emails → Linear issues
email-to-task scan --dry-run       # Preview mode
```

### Phase 2: Review Queue + Polish (~2-3 hours)
Add human-in-the-loop and observability.

**Add:**
- `src/store/review-queue.ts`, `tasks.ts` — review queue + audit trail
- `email-to-task review` — interactive approval with inquirer
- `email-to-task status` — processing stats
- `email-to-task history` — recent activity log
- Unit tests for all core modules
- Integration test for full pipeline (mocked HTTP)
- Error handling, retry logic, graceful degradation

### Phase 3: Watch Mode + npm Packaging (~2 hours)
Enable continuous monitoring and library distribution.

**Add:**
- `src/email/watcher.ts` — poll-based watch mode
- `email-to-task watch --interval 300`
- Thread-aware dedup (comment on existing task vs creating duplicate)
- npm package exports (dual CJS/ESM via tsup)
- Programmatic API documentation
- README with setup guide

---

## Programmatic API (for reuse in other projects)

```typescript
import { EmailToTaskPipeline } from 'email-to-task';

const pipeline = new EmailToTaskPipeline({
  gmail: { clientId: '...', clientSecret: '...' },
  linear: { teamId: '...' },
  llm: { /* defaults */ },
});

const results = await pipeline.scan({ maxResults: 10 });
// → [{ email, action: 'created'|'queued'|'skipped', task?: LinearIssue }]
```

Individual modules also exported for selective use:
```typescript
import { GmailClient, redact, TriageEngine, ExtractionEngine, LinearTaskCreator } from 'email-to-task';
```

---

## Verification Plan

After each phase, verify:

1. **Phase 1 verification:**
   - `email-to-task configure gmail` completes OAuth flow and stores token
   - `email-to-task configure linear` validates API key
   - `email-to-task scan --dry-run --max 5` fetches emails, runs triage + extraction, prints results without creating issues
   - `email-to-task scan --max 3` creates real Linear issues
   - Check `~/.email-to-task/data.db` has entries in `processed_emails`
   - Re-run `scan` and confirm already-processed emails are skipped (dedup works)

2. **Phase 2 verification:**
   - `vitest run` — all unit tests pass
   - `email-to-task review` shows pending items, approve/reject works
   - `email-to-task status` shows correct counts
   - Pipeline integration test passes with mocked APIs

3. **Phase 3 verification:**
   - `email-to-task watch` runs continuously, picks up new emails
   - `npm pack` produces a valid tarball
   - Import as library in a test script: `import { EmailToTaskPipeline } from './dist'`
   - Thread dedup: send reply to an email that already created a task, confirm it doesn't create a duplicate

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Gmail OAuth setup complexity | Step-by-step CLI wizard + README guide |
| LLM hallucinating task fields | Zod validation rejects invalid schemas; confidence routing |
| PII leaking past regex | Defense in depth: truncate bodies, redact known patterns, log warnings |
| `better-sqlite3` native build issues | Document Node.js version req; consider `sql.js` (WASM) as fallback |
| Rate limits (Gmail: 250 units/sec) | Sequential processing, exponential backoff on 429 |

---

## Research Sources (Feb 2026)

This plan was informed by deep research across 4 areas conducted by an agent team:

**Email Access APIs:** Gmail API docs, Microsoft Graph API, IMAP RFCs, JMAP adoption, Nylas/EmailEngine middleware, MCP server ecosystem (44+ Gmail MCP servers)

**AI/LLM Parsing:** Anthropic structured outputs (GA), `.parse()` + Pydantic/Zod, two-stage pipeline pattern (Haiku triage + Sonnet extraction), prompt engineering patterns, cost optimization via prompt caching and batch API

**Task Management & Automation:** Linear/Todoist/Asana/Notion API comparison, n8n/Temporal/Inngest/LangGraph orchestration frameworks, MCP servers for Linear and Todoist, Claude Agent SDK multi-agent patterns

**Privacy & Architecture:** GDPR/EDPB 2025 LLM guidance, CCPA 2026 ADMT regulations, OAuth 2.1/RFC 9700, PII redaction approaches (Presidio, regex), local-first vs cloud vs hybrid architecture, Superhuman/Shortwave/Spark product analysis
