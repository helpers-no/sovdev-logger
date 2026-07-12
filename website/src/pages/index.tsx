import React from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import HomepageHero from '@site/src/components/HomepageHero';
import HomepageValues from '@site/src/components/HomepageValues';
import HomepageBadgeRow from '@site/src/components/HomepageBadgeRow';

const LANGUAGES = [
  {label: 'TypeScript — reference implementation', tone: 'success' as const, logo: '/img/typescript.svg'},
  {label: 'Python — conformant', tone: 'success' as const, logo: '/img/python.svg'},
  {label: 'Go — planned'},
  {label: 'C# — planned'},
  {label: 'Rust — planned'},
  {label: 'PHP — planned'},
];

// UIS and Grafana Cloud are the two backends actually verified end-to-end
// today (get a logo + success tone); the rest are OTLP-compatible in
// principle but not yet verified against — see
// INVESTIGATE-external-backend-verification.md.
const BACKENDS = [
  {label: 'UIS (local) — verified', tone: 'success' as const, logo: '/img/uis-logo.svg'},
  {label: 'Grafana Cloud — verified', tone: 'success' as const, logo: '/img/grafana.svg'},
  {label: 'Azure Monitor'},
  {label: 'Datadog'},
  {label: 'New Relic'},
  {label: 'Honeycomb'},
  {label: 'Self-hosted (any OTLP-compatible collector)'},
];

export default function Home(): React.JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout description={siteConfig.tagline}>
      <HomepageHero />
      <main>
        <section className="container margin-top--lg margin-bottom--md">
          <p className="text--center" style={{maxWidth: 760, margin: '0 auto', fontSize: '1.05rem'}}>
            <strong>sovdev-logger is a specification-first, multi-language structured logging library.</strong>{' '}
            One log call gives structured logs, metrics, and distributed traces — correlated automatically —
            against any OpenTelemetry-compatible backend. TypeScript is the reference implementation; Python is
            conformant and verified against it; Go, C#, Rust, and PHP are planned.
          </p>
        </section>
        <section className="container margin-bottom--md">
          <div className="card" style={{maxWidth: 760, margin: '0 auto'}}>
            <div className="card__header text--center">
              <h2 style={{marginBottom: 0}}>Who Do You Write Logs For?</h2>
              <p style={{margin: 0, opacity: 0.75}}>
                <em>you write code for yourself — you write logs for someone else</em>
              </p>
            </div>
            <div className="card__body">
              <p>
                You write code for yourself during development. But you write logs for the operations
                engineer staring at a screen at 7 PM on Friday, trying to piece together what went wrong
                from cryptic error messages — long after everyone else has gone home. Good logging is the
                difference between a three-hour debugging session and a five-minute fix.
              </p>
              <p className="text--center" style={{marginBottom: 0}}>
                <Link to="https://github.com/helpers-no/sovdev-logger/blob/main/typescript/README.md#who-do-you-write-logs-for">
                  Read the full case →
                </Link>
              </p>
            </div>
          </div>
        </section>
        <HomepageValues />
        <HomepageBadgeRow title="Languages" items={LANGUAGES} />
        <HomepageBadgeRow title="Backends" items={BACKENDS} />
      </main>
    </Layout>
  );
}
