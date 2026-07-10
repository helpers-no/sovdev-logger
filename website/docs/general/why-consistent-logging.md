---
title: Why Consistent Logging Across Systems
sidebar_label: Why Consistent Logging Across Systems
sidebar_position: 3
description: "Why every system logging the same way — not just one application doing it well — is what makes automated monitoring and incident routing possible."
---

# Why Consistent Logging Across Systems

[Why Structured Logging](./why-structured-logging.md) and [Why OTLP](./why-otlp.md) both make the case at the level of a single application: one service, one log call, one dashboard. This page is about a different benefit that only shows up at the organization level — what happens once *every* system, not just one, logs the same way.

## The case for one standard across every system

**Alerting rules become write-once, not write-per-system.** If every system's logs put severity, system identifier, and exception details in the same fields, one alert rule ("any log at Error or Fatal") works for every system that conforms — an ops team doesn't write a custom parser per integration to know when something's actually broken.

**Automated ticket routing becomes possible, not just automated alerting.** Because every log entry carries a unique system identifier by requirement, not by convention, an alert can auto-create a ticket in a system like ServiceNow and route it to the right team's queue without a human first figuring out which system is failing. The alert already knows.

**An incident that spans systems is still traceable across them.** A correlation identifier that threads through a request touching three different integrations — each maintained by a different team — lets an operator follow the one identifier across all three logs, instead of asking each team to separately check whether they saw anything.

[Loggeloven compliance](../using/loggeloven.md) documents the concrete version of this already running for Red Cross Norway — the flow from a `StructuredLogMessage` through the OpenTelemetry Collector, into alerting, and out to ServiceNow as a routed incident.

## What this costs

- **Partial adoption gives partial benefit, not proportional benefit.** One system that logs inconsistently — wrong system identifier, missing correlation ID, free-text instead of structured fields — breaks the "one rule covers everything" property for that system specifically. Someone still has to hand-build monitoring for it, same as before any of this existed.
- **The payoff requires a platform investment sovdev-logger doesn't provide by itself.** Logging consistently is necessary but not sufficient — an ops or monitoring team still has to build the fleet-wide alert rules and the ticket-routing logic once, on top of a backend like Azure Monitor or Grafana. sovdev-logger makes that investment possible; it doesn't make it automatic.
- **A shared schema needs an owner.** Without someone maintaining the field-naming standard as new systems and new fields get added, teams drift into inconsistent usage over time — quietly undermining the exact property (one rule, every system) that made the automation worth building in the first place.

## Why the tradeoff is worth it here

The cost is paid once by the organization — agreeing the standard, building the alerting and routing on top of it — and once by each team conforming to it. The payoff compounds with every system that adopts it afterward: the tenth integration to onboard gets automated alerting and ticket routing for free, because the rule and the routing logic were already built for the first one.
