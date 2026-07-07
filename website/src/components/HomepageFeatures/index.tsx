import React from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  emoji: string;
  description: React.ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'One log call',
    emoji: '📝',
    description: (
      <>
        Write a single structured log entry and get logs, metrics, and traces
        together — no separate instrumentation calls to keep in sync.
      </>
    ),
  },
  {
    title: 'OpenTelemetry-compatible',
    emoji: '🔭',
    description: (
      <>
        Works with any OpenTelemetry-compatible backend: Azure Monitor,
        Grafana Cloud, Datadog, New Relic, Honeycomb, or self-hosted.
      </>
    ),
  },
  {
    title: 'Multi-language',
    emoji: '🌐',
    description: (
      <>
        The same log contract across every language — currently TypeScript,
        with Go, Python, C#, Rust, and PHP planned.
      </>
    ),
  },
  {
    title: 'Automatic correlation',
    emoji: '🔗',
    description: (
      <>
        Structured logs, metrics dashboards, and distributed traces are
        correlated automatically, including service dependency maps.
      </>
    ),
  },
];

function Feature({title, emoji, description}: FeatureItem) {
  return (
    <div className={clsx('col col--6 col--lg-3')}>
      <div className={styles.feature}>
        <div className={styles.featureEmoji} aria-hidden="true">
          {emoji}
        </div>
        <Heading as="h3" className={styles.featureTitle}>
          {title}
        </Heading>
        <p className={styles.featureDescription}>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): React.JSX.Element {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
