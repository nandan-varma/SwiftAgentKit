import { RootProvider } from 'fumadocs-ui/provider/next';
import type { ReactNode } from 'react';
import type { Metadata } from 'next';
import './global.css';

export const metadata: Metadata = {
  title: {
    template: '%s | SwiftAgentKit',
    default: 'SwiftAgentKit',
  },
  description:
    'A Swift-native SDK for building autonomous AI agents that call language models and execute tools, with first-class support for OpenAI, Anthropic, and Apple on-device Foundation Models.',
};

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider>{children}</RootProvider>
      </body>
    </html>
  );
}
