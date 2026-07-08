import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// Fork-friendly: GitHub Actions auto-sets these from repo context;
// local dev uses the defaults. See website/README.md if you fork.
const GITHUB_ORG = process.env.GITHUB_ORG || 'helpers-no';
const GITHUB_REPO = process.env.GITHUB_REPO || 'sovdev-logger';

const config: Config = {
  title: 'sovdev-logger',
  tagline: 'Multi-language structured logging with zero-effort observability',
  favicon: 'img/favicon.svg',

  future: {
    v4: true,
  },

  url: 'https://sovdev-logger.sovereignsky.no',
  baseUrl: '/',

  organizationName: GITHUB_ORG,
  projectName: GITHUB_REPO,

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  markdown: {
    mermaid: true,
    // 'detect': .md files parse as plain CommonMark (no JSX/expression
    // parsing), .mdx files get full MDX. Needed once real content started
    // migrating in from specification/ and docs/ -- legacy markdown is full
    // of bare `<placeholder>` tags and `{...}` in prose/table cells that
    // Docusaurus's actual default (format: 'mdx' for every file regardless
    // of extension) misparses as JSX/JS expressions.
    format: 'detect',
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/tree/main/website/`,
          // This site is only documentation -- docs/index.md (slug: /) is
          // meant to be the actual homepage, not live under /docs/ behind a
          // separate generic landing page. Requires removing src/pages/index.tsx
          // (Docusaurus won't allow two things claiming route "/").
          routeBasePath: '/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themes: [
    '@docusaurus/theme-mermaid',
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en'],
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
        docsRouteBasePath: '/',
        indexBlog: false,
      },
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'light',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'sovdev-logger',
      logo: {
        alt: 'sovdev-logger logo',
        src: 'img/favicon.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}`,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Docs',
              to: '/',
            },
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'GitHub',
              href: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}`,
            },
            {
              label: 'Issues',
              href: `https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/issues`,
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} sovdev-logger contributors. MIT.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'typescript', 'python', 'csharp', 'go', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
