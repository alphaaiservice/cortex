---
name: deployment
description: "Auto-invoked when Claude handles deployment tasks, CI/CD configuration, or release management. Provides pre-deployment checklists, deployment strategy selection (rolling, blue-green, canary), environment promotion flow, rollback procedures, and post-deploy monitoring guidance."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with alpha-forge plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Deployment Skill

Best practices for safe, reliable deployments.

## Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Build succeeds
- [ ] No lint errors
- [ ] Security scan clean
- [ ] Environment variables configured
- [ ] Database migrations ready
- [ ] Rollback plan documented
- [ ] Team notified

## Deployment Strategies

### Rolling Update (Default)
- Gradually replace instances
- Zero downtime
- Easy rollback

### Blue-Green
- Two identical environments
- Switch traffic after verification
- Instant rollback

### Canary
- Deploy to small subset first
- Monitor for errors
- Gradual traffic shift

## Environment Promotion
```
Local → Dev → Staging → Production
  ↓       ↓       ↓          ↓
 Manual  Auto    Auto     Manual+Approval
```

## Rollback Procedures
1. Identify the issue
2. Decide: hotfix vs rollback
3. Execute rollback command
4. Verify health checks
5. Communicate to stakeholders
6. Post-mortem

## Monitoring Post-Deploy
- Error rates (should not increase)
- Response times (should not degrade)
- CPU/Memory usage
- User-facing health checks
- Key business metrics
