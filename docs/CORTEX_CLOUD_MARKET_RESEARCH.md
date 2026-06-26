# Market Research: Cortex Cloud (monetization backend for the Cortex plugin)

**Date:** 2026-06-21
**Context:** The Cortex Claude Code plugin is free + open (markdown/hooks, trivially copyable).
Cortex Cloud is the **hosted backend** that makes it monetizable — device-auth login,
telemetry ingest, project-state, and a team dashboard. This research informs the PRD.

> Scope note: This is **developer infrastructure**, not a consumer SaaS. The relevant
> landscape is (a) the monetization reference — CodeRabbit's seat model, and (b) the
> CLI-auth + usage-analytics technical patterns. We deliberately did NOT research consumer
> growth/retention tooling — it doesn't apply.

## Competitors / References Found

| Name | URL | Relevance | Pricing | Takeaway for us |
|------|-----|-----------|---------|-----------------|
| CodeRabbit | coderabbit.ai/pricing | The monetization reference (AI PR review SaaS) | Free / Pro $24–30 dev/mo / Pro Plus $48 / Enterprise ~$15k/mo @500+ | Bills only devs who *open PRs*, not headcount. Seat model + feature gating. |
| Mixpanel | mixpanel.com | Event-ingest analytics pattern | Free first 1M events/mo, then usage-based | Event-volume free tier is the norm; meter on ingest volume. |
| Amplitude | amplitude.com | Cross-platform usage analytics | Usage-based | Validates "ingest events → dashboard" as a sellable shape. |
| Sentry | sentry.io | Dev-tool telemetry SaaS (errors) | Free / Team / Business by event volume | Opt-in SDK + org-scoped dashboards + event-quota tiers — our exact shape. |
| Metabase | metabase.com | Self-host vs hosted dashboard | OSS + paid cloud | Open-core works: free OSS core, paid hosting/management. |

## Market & Trends

- **AI dev-tooling is a land grab** — CodeRabbit, Greptile, Gitar, Qodo all competing on AI
  review. The *adjacent, less-crowded* niche is **build/SDLC automation telemetry** (what
  Cortex does), where there's no obvious incumbent selling "see what your team's AI built."
- **Pricing is shifting from pure seats → hybrid usage + feature gating.** The strongest
  dev-tool pricing maps tiers to technical value metrics (repos, projects, ingest volume),
  not just headcount.
- **Open-core is the dominant model** for developer infrastructure (Sentry, Metabase,
  PostHog, GitLab): free/OSS core for adoption, paid hosted backend + team features for revenue.

## User Pain Points (Opportunities)

1. **No team-wide visibility into AI-assisted builds** → our `/v1/dashboard` + project-state ingest.
2. **No way to enforce shared engineering standards across an org** → future Standards Registry (the moat, deferred to post-v1).
3. **Plugins/CLIs are unmeterable & unrevokable** → device-token + Redis revocation denylist = the gateable unit.
4. **Telemetry feels like spyware** → strict opt-in, command-names/state-metadata only, never code/PRD/secrets.

## Table-Stakes Features (Must Build — v1)

- OAuth 2.0 Device Authorization Grant login from the CLI (the "log in like `gh`" flow).
- Org/user identity with seats + roles.
- Event ingest endpoint (fire-and-forget, batched, rate-limited).
- Project-state upsert (latest `AUTO_BUILD_STATE.json` snapshot).
- Team dashboard: list projects + latest phase/score + recent activity.
- Token revocation kill-switch (cancel seat → pipe dies).

## Differentiator Features (Our Edge)

- **SDLC build telemetry**, not just code review — nobody sells "what your team's AI built, end to end."
- **Future Standards Registry** — org-defined stack/layer/auth rules the plugin pulls live at build time. Uniquely Alpha AI; worthless when copied. (Deferred to post-v1.)
- **Open-core honesty** — plugin stays free/copyable; we sell the hosted spine, not hidden prompts.

## Pricing Intelligence (for future billing — NOT in v1)

- This is a **global developer tool** → **USD pricing via Stripe** (NOT India/Razorpay/GST — that template default does not apply here).
- Competitor anchor: CodeRabbit Pro $24–30/dev/mo.
- Recommended future shape (hybrid seat + value metric):
  - **Free**: 1 org, up to 3 seats, 30-day event retention, N projects.
  - **Team**: ~$19/seat/mo — unlimited projects, 180-day retention, Standards Registry.
  - **Enterprise**: custom — SSO, audit export, on-prem option, SLA.
- Meter the value metric on **active projects / ingest volume**, gate **Standards Registry +
  SSO + retention** by tier. Bill only seats that actually run builds (mirror CodeRabbit's
  "only devs who open PRs" fairness).

## UI/UX Decisions (Research-Based)

- **Dashboard UI library**: shadcn/ui (Radix + Tailwind) — developer-audience default, clean, fast.
- **App type**: Web dashboard only (no mobile — this is a back-office team view).
- **Backend language**: Python / FastAPI.
- **Design aesthetic**: data-dense developer tool — tables, status badges, sparklines; dark mode first.
- **Competitor UI strength to borrow**: Sentry/Linear-style project list + activity feed.

## Technical Insights

- **CLI auth**: OAuth 2.0 Device Authorization Grant (RFC 8628). Public client, no secret;
  poll `/token` respecting `interval`; `slow_down` adds 5s. Validated by gh, aws sso, GitHub.
- **Ingest**: model after Sentry/Mixpanel — opt-in, batched, org-scoped, event-quota tiers.
- **Datastore**: MongoDB (single store) — append-heavy event firehose + TTL self-prune;
  small relational-ish entities (orgs/users/tokens) live as documents.
- **Privacy/compliance**: opt-in telemetry, field whitelist, no code/PRD/secrets, org isolation,
  hashed tokens. GDPR-friendly by collecting only command-names + state metadata.

## Sources
- [CodeRabbit Pricing](https://www.coderabbit.ai/pricing)
- [How to Price Developer Tools — getmonetizely](https://www.getmonetizely.com/articles/how-to-price-developer-tools-technical-feature-gating-and-code-quality-tier-strategies-for-saas-33022)
- [Authenticate CLI tools with OAuth Device Flow — WorkOS](https://workos.com/blog/cli-auth)
- [OAuth 2.0 Device Authorization Flow — GitHub Changelog](https://github.blog/changelog/2020-07-27-oauth-2-0-device-authorization-flow/)
