---
description: "Onboard a new developer to the project. Generates personalized onboarding plan, sets up dev environment, creates first tasks, and provides codebase walkthrough."
---

# Developer Onboarding Automation

You are an expert developer onboarding assistant. Your job is to onboard a new developer ($ARGUMENTS) to this project by executing a comprehensive, structured onboarding workflow.

## Phase 1: Project Discovery

1. **Read the project structure** — Scan the entire repo tree, README, CONTRIBUTING.md, package.json / pyproject.toml / Cargo.toml / go.mod, and any existing CLAUDE.md or .claude/ config.
2. **Identify the tech stack** — Languages, frameworks, databases, cloud services, CI/CD tools, package managers.
3. **Map the architecture** — Identify entry points, core modules, API layers, database models, shared utilities, and external service integrations.

## Phase 2: Environment Setup Guide

Generate a comprehensive **ONBOARDING.md** file in the project root with:

### Prerequisites
- Required software versions (Node.js, Python, Docker, etc.)
- Required accounts and access (cloud providers, package registries, etc.)
- Environment variables needed (create a `.env.example` if missing)

### Setup Steps
- **Lead with the one-command path** if the project follows the Cortex local-dev
  standard (`LOCAL_DEV.md` / `commands/references/LOCAL_DEV_STANDARD.md`):
  `git clone` → `cp .env.example .env` → `make dev` → open the app, then
  `make verify` to confirm a healthy boot. Link `LOCAL_DEV.md` rather than
  re-documenting — and if it's missing, generate it (it's the single source for
  ports, seed creds, and the Troubleshooting matrix).
- Otherwise: step-by-step commands to clone, install dependencies, configure, run locally
- Database setup / migration commands
- How to run the development server
- How to run tests
- Common troubleshooting tips (reuse the LOCAL_DEV.md Troubleshooting matrix)

### IDE Configuration
- Recommended VS Code extensions or IDE settings
- Linting / formatting setup
- Debugging configurations

## Phase 3: Codebase Walkthrough Document

Generate **ARCHITECTURE.md** covering:

- **High-level architecture diagram** (as ASCII/Mermaid)
- **Directory structure explained** — What each top-level folder does
- **Key files and entry points** — Where to start reading code
- **Data flow** — How a typical request moves through the system
- **Dependency map** — Key internal and external dependencies
- **Design patterns used** — Patterns, conventions, and coding standards
- **API endpoints** (if applicable) — Key routes/endpoints with brief descriptions

## Phase 4: First Tasks Generator

Create a **FIRST_TASKS.md** file with 5 starter tasks suitable for a new developer, categorized by difficulty:

### 🟢 Easy (Day 1-2)
1. Fix a small documentation issue or typo
2. Add a missing test for an existing function

### 🟡 Medium (Week 1)
3. Implement a small feature or enhancement
4. Refactor a specific module following project conventions

### 🔴 Challenging (Week 2)
5. Tackle a real open issue or implement a meaningful feature

Each task should include:
- Clear description
- Files to modify
- Acceptance criteria
- Helpful context / related code

## Phase 5: Team Standards Document

Generate **STANDARDS.md** documenting:

- Git branching strategy (detected from existing branches)
- Commit message conventions
- PR / code review process
- Testing requirements
- Deployment workflow
- Code style and linting rules

## Final Output

After generating all documents, provide a summary:
1. List all files created
2. Highlight any issues found (missing configs, outdated deps, etc.)
3. Suggest immediate improvements to the project's developer experience

**IMPORTANT**: Be thorough but practical. Every recommendation should be actionable. If you can't determine something, say so and suggest how to find out.
