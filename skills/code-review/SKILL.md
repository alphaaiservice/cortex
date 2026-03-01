---
name: code-review
description: "Auto-invoked when Claude performs code review tasks. Provides structured 6-dimension review methodology (correctness, security, performance, readability, testing, architecture) with severity levels from critical to praise."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Code Review Skill

This skill ensures thorough, consistent code reviews.

## Review Dimensions

### 1. Correctness
- Does the code do what it's supposed to?
- Are edge cases handled?
- Is error handling comprehensive?

### 2. Security
- Input validation present?
- No hardcoded secrets?
- SQL injection / XSS prevention?
- Proper authentication checks?

### 3. Performance
- No N+1 queries?
- Appropriate caching?
- No unnecessary computations?
- Memory management?

### 4. Readability
- Clear naming conventions?
- Appropriate comments (why, not what)?
- Reasonable function length?
- Consistent formatting?

### 5. Testing
- New code has tests?
- Edge cases tested?
- Mocks are appropriate?

### 6. Architecture
- Follows existing patterns?
- No unnecessary coupling?
- Single responsibility?

## Severity Levels

- **🔴 Critical**: Must fix — security issues, data loss risk, crashes
- **🟠 Major**: Should fix — bugs, performance issues, missing error handling
- **🟡 Minor**: Nice to fix — code smell, naming, minor improvements
- **🟢 Nitpick**: Optional — style preferences, minor readability tweaks
- **👍 Praise**: Highlight good patterns to reinforce
