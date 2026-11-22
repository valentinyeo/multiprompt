import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://multiprompt.dev',
  integrations: [
    starlight({
      title: 'multiprompt',
      description: 'Run, monitor, and prompt multiple AI agents from one lightweight Windows workspace.',
      logo: {
        src: './src/assets/logo.svg',
        alt: 'multiprompt',
      },
      social: [
        {
          icon: 'x.com',
          label: 'X',
          href: 'https://x.com/valentinyeo',
        },
      ],
      customCss: ['./src/styles/custom.css'],
      sidebar: [
        {
          label: 'Start',
          items: [
            { label: 'Overview', slug: 'docs' },
            { label: 'Download and install', slug: 'docs/install' },
            { label: 'Getting Started', slug: 'docs/getting-started' },
            { label: 'Keyboard Shortcuts', slug: 'docs/keyboard-shortcuts' },
          ],
        },
        {
          label: 'Core Behavior',
          items: [
            { label: 'Sessions & Workspaces', slug: 'docs/sessions-workspaces' },
            { label: 'Activity Indicators', slug: 'docs/activity-indicators' },
            { label: 'Browser Pane & multiprompt-browser', slug: 'docs/browser-pane-zsb' },
          ],
        },
        {
          label: 'Engineering',
          items: [
            { label: 'Architecture', slug: 'docs/architecture' },
            { label: 'Troubleshooting', slug: 'docs/troubleshooting' },
          ],
        },
      ],
    }),
  ],
});
