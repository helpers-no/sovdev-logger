import React from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import useBaseUrl from '@docusaurus/useBaseUrl';

import styles from './styles.module.css';

export type BadgeItem = {
  label: string;
  tone?: 'success' | 'secondary';
  /** Path under static/, e.g. '/img/typescript.svg' — only real, verified items get a logo. */
  logo?: string;
};

function LogoChip({label, logo}: {label: string; logo: string}) {
  const logoUrl = useBaseUrl(logo);
  return (
    <div className={styles.logoChip}>
      <img src={logoUrl} alt="" className={styles.logoChipIcon} />
      <span className={styles.logoChipLabel}>{label}</span>
    </div>
  );
}

function Badge({label, tone}: {label: string; tone?: BadgeItem['tone']}) {
  return <span className={clsx('badge', `badge--${tone ?? 'secondary'}`, styles.badge)}>{label}</span>;
}

export default function HomepageBadgeRow({title, items}: {title: string; items: BadgeItem[]}): React.JSX.Element {
  return (
    <section className={styles.row}>
      <div className="container">
        <Heading as="h2" className={styles.rowTitle}>
          {title}
        </Heading>
        <div className={styles.items}>
          {items.map((item) =>
            item.logo ? (
              <LogoChip key={item.label} label={item.label} logo={item.logo} />
            ) : (
              <Badge key={item.label} label={item.label} tone={item.tone} />
            ),
          )}
        </div>
      </div>
    </section>
  );
}
