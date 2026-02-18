# backlog

A command-line “backlog manipulator” that pulls issues from trackers (Jira/GitHub), packs them into reviewable local files, lets you describe batch edits in natural language (via your choice of agent), then applies changes deterministically back to the source system.

> Design goal: **LLM proposes a patch, not the truth.** The tool stays in control with schema validation, diffs, preconditions, and idempotent applies.

---

## What it does

- **Pull** issues from Jira/GitHub into a local snapshot (reproducible exports)
- **Filter** by query (JQL, GitHub search) and batch downloads
- **Pack** many issues into a single editable file (markdown/plaintext), stripping noisy metadata
- **Edit with natural language**: generate a structured change set (`changes.json`) using an agent
- **Plan**: produce a deterministic diff of what will change
- **Apply**: execute changes safely (dry-run, preconditions, audit log)

---

## Why this approach

Working in batches inside one file:
- saves tokens and time (one agent call instead of hundreds)
- enables higher-level transforms (clustering, deduping, taxonomy cleanup)
- creates a reviewable artifact you can check into git

Deterministic apply:
- the agent outputs a **patch file** (`changes.json`) validated against a strict schema
- the CLI applies only allowed operations, with **preconditions** (fail fast if remote changed)
- every run produces an **audit log** you can re-run or inspect

---

## Quick start

### Prerequisites

- `gh` (GitHub CLI) for GitHub integration
- `acli` (Atlassian CLI) for Jira integration
- An agent you can call from the shell (examples: `copilot`, `claude`, `codex`)

## Typical workflow

### 1) Pull issues into a snapshot
Jira
backlog pull jira \
  --jql "project = ABC AND statusCategory != Done ORDER BY updated DESC" \
  --out ./snapshots/abc-001

GitHub
backlog pull github \
  --repo org/repo \
  --query "is:issue is:open label:bug" \
  --out ./snapshots/repo-001


This creates a reproducible snapshot directory (example structure):

snapshots/abc-001/
  issues.ndjson
  manifest.json
  sources.json
  raw/               # optional: raw API payloads
  attachments/       # optional

### 2) Pack issues into one file for review/edit
backlog pack ./snapshots/abc-001 --format md > backlog.md


You can commit backlog.md to a branch and review changes like normal code.

### 3) Generate a patch from natural language (agent-backed)
backlog edit backlog.md \
  --instruction "Standardize titles to verb-first. Merge obvious duplicates. Add label 'tech-debt' when refactor is mentioned." \
  --agent claude \
  --out changes.json


The agent produces only a structured patch (changes.json), not arbitrary rewritten text.

### 4) Review the plan (deterministic diff)
backlog plan changes.json


Outputs:

a per-issue diff (title/body/labels/etc.)

warnings (missing labels, risky edits, conflicts)

a summary (counts of ops)

### 5) Apply changes safely

Dry run:

backlog apply changes.json --dry-run


Apply:

backlog apply changes.json


Every apply writes an audit log:

runs/2026-02-18T09-12-33Z/
  applied.jsonl
  errors.jsonl
  summary.json

Agents

Agents are pluggable. backlog treats them as a function:

Input: packed text + allowed operations + constraints
Output: changes.json validated against the schema

Example agent selectors:

--agent copilot

--agent claude

--agent codex

You can add adapters for any CLI-capable agent.

Patch format (changes.json)

changes.json is a list of operations referencing stable identifiers (Jira key / GitHub issue number):

Example:

{
  "version": "1",
  "source": { "kind": "jira", "snapshot": "snapshots/abc-001" },
  "ops": [
    {
      "id": "op-001",
      "target": { "key": "ABC-123" },
      "preconditions": { "remoteUpdatedAt": "2026-02-18T08:21:10Z" },
      "type": "update_title",
      "value": "Fix checkout retry logic"
    },
    {
      "id": "op-002",
      "target": { "key": "ABC-124" },
      "type": "add_labels",
      "value": ["tech-debt", "backend"]
    }
  ]
}

