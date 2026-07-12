import React from 'react';
import Heading from '@theme/Heading';

import styles from './styles.module.css';

type ValueItem = {
  title: string;
  emoji: string;
  description: React.ReactNode;
};

// Values, not doc navigation — the hero's own buttons and the sidebar
// already cover getting to general/using/contributor. These three cards
// are why the project is built the way it is, not where to click next.
const VALUES: ValueItem[] = [
  {
    title: 'Sovereign',
    emoji: '🔓',
    description:
      'One log call keeps working the same way regardless of language or backend — a developer’s logging code isn’t hostage to a vendor or a stack choice.',
  },
  {
    title: 'Open',
    emoji: '🌐',
    description:
      'Built entirely on open standards, not a proprietary SDK or a bespoke wire format — no vendor lock-in, ever.',
  },
  {
    title: 'OpenTelemetry-native',
    emoji: '🔭',
    description:
      'Every signal — logs, metrics, traces — over the same OTLP protocol every major backend already speaks.',
  },
  {
    title: 'Consistent',
    emoji: '🧩',
    description:
      'Every system logs the same fixed schema — one alerting rule, one ticket-routing pipeline, and one dashboard work across the tenth system exactly like the first, making monitoring hundreds of systems possible instead of a bespoke integration each time.',
  },
];

function Value({title, emoji, description}: ValueItem) {
  return (
    <div className="col col--3">
      <div className={styles.value}>
        <div className={styles.valueEmoji} aria-hidden="true">
          {emoji}
        </div>
        <Heading as="h3" className={styles.valueTitle}>
          {title}
        </Heading>
        <p className={styles.valueDescription}>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageValues(): React.JSX.Element {
  return (
    <section className={styles.values}>
      <div className="container">
        <div className="row">
          {VALUES.map((props) => (
            <Value key={props.title} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
