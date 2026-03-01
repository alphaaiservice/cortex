---
name: project-setup
description: "Auto-invoked when Claude detects project initialization, scaffolding, or boilerplate setup tasks. Provides best practices for project structure, Docker multi-stage builds, CI/CD pipeline stages, environment management, and configuration file conventions."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with alpha-forge plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Project Setup Skill

This skill is automatically activated when the task involves setting up a new project or adding standard configurations to an existing one.

## When to Use

- Creating a new project from scratch
- Adding CI/CD pipelines
- Setting up Docker configurations
- Adding linting, formatting, or testing infrastructure
- Creating standard documentation templates

## Best Practices

### Project Structure
- Keep a flat structure for small projects, nested for large ones
- Separate concerns: `src/`, `tests/`, `docs/`, `scripts/`, `config/`
- Use barrel files (index.ts) for clean imports
- Keep configuration files at the root

### Configuration Files Priority
1. `.editorconfig` — Consistent editor settings
2. Linter config — Code quality enforcement
3. Formatter config — Consistent formatting
4. `.gitignore` — Proper exclusions
5. `CLAUDE.md` — AI assistant context

### CI/CD Pipeline Stages
1. Lint → 2. Type Check → 3. Unit Tests → 4. Build → 5. Integration Tests → 6. Security Scan → 7. Deploy

### Docker Best Practices
- Use multi-stage builds
- Pin base image versions
- Don't run as root
- Use .dockerignore
- Minimize layers
- Put frequently changing steps last

### Environment Management
- Never commit .env files
- Always provide .env.example
- Document every environment variable
- Use different configs per environment
- Validate env vars at startup
