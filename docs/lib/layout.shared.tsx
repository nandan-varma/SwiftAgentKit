import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: 'SwiftAgentKit',
    },
    links: [
      {
        text: 'GitHub',
        url: 'https://github.com/nandan-varma/SwiftAgentKit',
        external: true,
      },
    ],
  };
}
