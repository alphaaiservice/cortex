---
name: onboarding
description: "Auto-invoked when Claude detects developer onboarding tasks, environment setup questions, or codebase exploration from new team members. Provides structured onboarding checklists (Day 1 through Week 2), setup guides with copy-pasteable commands, troubleshooting FAQ templates, and architecture overview documentation."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with alpha-forge plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Developer Onboarding Skill

This skill activates when helping new developers understand and set up a project.

## When to Use

- New developer asks "how do I set up this project?"
- Questions about project architecture or conventions
- First-time contributor guidance
- Environment troubleshooting for new setups

## Onboarding Checklist

### Day 1: Environment Setup
- [ ] Clone repository
- [ ] Install dependencies
- [ ] Configure environment variables
- [ ] Run the project locally
- [ ] Run the test suite
- [ ] Set up IDE with recommended extensions

### Day 2-3: Codebase Understanding
- [ ] Read ARCHITECTURE.md or equivalent
- [ ] Understand the directory structure
- [ ] Trace a simple request end-to-end
- [ ] Review coding conventions and standards
- [ ] Understand the branching strategy
- [ ] Review CI/CD pipeline

### Week 1: First Contributions
- [ ] Fix a documentation issue or typo
- [ ] Write a test for an untested function
- [ ] Complete a small, well-defined task
- [ ] Submit first PR and go through review process
- [ ] Understand deployment process

### Week 2: Deeper Integration
- [ ] Tackle a medium-complexity feature
- [ ] Participate in a code review
- [ ] Understand monitoring and logging
- [ ] Learn the incident response process

## Documentation Templates

When generating onboarding docs, always include:
1. Prerequisites with exact versions
2. Step-by-step setup (copy-pasteable commands)
3. Common troubleshooting FAQ
4. Architecture overview with diagrams
5. Key contacts and communication channels
6. First tasks with clear acceptance criteria
