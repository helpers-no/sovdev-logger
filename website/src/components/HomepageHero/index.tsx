import React from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import useBaseUrl from '@docusaurus/useBaseUrl';

import styles from './styles.module.css';

export default function HomepageHero(): React.JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  const logoUrl = useBaseUrl('/img/sovdev-logo.svg');

  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className={clsx('container', styles.heroContainer)}>
        <div className={styles.heroIllustration}>
          <img src={logoUrl} alt="sovdev-logger" className={styles.heroMark} />
        </div>
        <div className={styles.heroContent}>
          <h1 className={clsx('hero__title', styles.heroTitle)}>sovdev-logger</h1>
          <p className={clsx('hero__subtitle', styles.heroSubtitle)}>{siteConfig.tagline}</p>
          <div className={styles.heroButtons}>
            <Link className="button button--lg button--primary" to="/using/">
              Get Started
            </Link>
            <Link className="button button--lg button--outline" to="/general/">
              Why sovdev-logger
            </Link>
            <Link className="button button--lg button--outline" to="https://github.com/helpers-no/sovdev-logger">
              GitHub
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}
