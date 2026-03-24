# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([opencode](https://opencode.ai) or [Claude Code](https://docs.anthropic.com/en/docs/claude-code)) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

> **Note:** This is a forked repository from [snarktank/ralph](https://github.com/snarktank/ralph).

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [opencode](https://opencode.ai) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Setup

### 1. Install skills

Copy the skills to your Claude config for use across all projects:

```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

Available skills after installation:
- `/prd` - Generate Product Requirements Documents
- `/ralph` - Convert PRDs to prd.json format

Skills are automatically invoked when you ask Claude to:
- "create a prd", "write prd for", "plan this feature"
- "convert this prd", "turn into ralph format", "create prd.json"

### 2. Install script and prompt

Symlink ralph into a shared scripts directory so it's available from any project:

```bash
# Create the scripts directory
mkdir -p -m 700 ~/_scripts

# Symlink ralph files (run from the ralph repo root)
ln -s $(pwd)/CLAUDE.md ~/_scripts/CLAUDE.md
ln -s $(pwd)/AGENTS.md ~/_scripts/AGENTS.md
ln -s $(pwd)/ralph.sh ~/_scripts/ralph.sh
```

### 3. Add `~/_scripts` to your PATH

Choose the section that matches your shell. If you're unsure, run `echo $SHELL` to check.

<details>
<summary><strong>fish</strong></summary>

Add this line to `~/.config/fish/config.fish`:

```fish
set -gx PATH $HOME/_scripts $PATH
```

Then reload:

```fish
source ~/.config/fish/config.fish
```

</details>

<details>
<summary><strong>zsh</strong></summary>

Add this line to `~/.zshrc`:

```bash
export PATH="$PATH:$HOME/_scripts/"
```

Then reload:

```bash
source ~/.zshrc
```

</details>

<details>
<summary><strong>bash</strong></summary>

Add this line to `~/.bashrc` (or `~/.bash_profile` on macOS if not using zsh):

```bash
export PATH="$PATH:$HOME/_scripts/"
```

Then reload:

```bash
source ~/.bashrc
```

</details>

Verify it works by running from any directory:

```bash
which ralph.sh
```

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Using opencode (default)
ralph.sh [max_iterations]

# Using Claude Code
ralph.sh --tool claude [max_iterations]

# With a specific model (opencode uses provider/model format)
ralph.sh --model "llm-router/claude-sonnet-4-6" [max_iterations]
ralph.sh --model "llm-router/claude-opus-4-6" [max_iterations]

# With a specific model (Claude Code uses model name)
ralph.sh --tool claude --model "claude-sonnet-4-6" [max_iterations]
```

Default is 10 iterations. Use `--tool opencode` or `--tool claude` to select your AI coding tool. Use `--model` to override the default model (passed as `-m` to opencode or `--model` to Claude Code).

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances (supports `--tool`, `--model`) |
| `AGENTS.md` | Prompt template for opencode |
| `CLAUDE.md` | Prompt template for Claude Code |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs (works with Opencode and Claude Code) |
| `skills/ralph/` | Skill for converting PRDs to JSON (works with Opencode and Claude Code) |
| `.claude-plugin/` | Plugin manifest for Claude Code marketplace discovery |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (opencode or Claude Code) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customizing the Prompt

After copying `AGENTS.md` (for opencode) or `CLAUDE.md` (for Claude Code) to your project, customize it for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [opencode documentation](https://opencode.ai)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
