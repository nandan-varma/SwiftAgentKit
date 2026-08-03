# SwiftAgentKit Docs

The documentation site for SwiftAgentKit, built with [Fumadocs](https://fumadocs.dev)
(Next.js + Fumadocs UI + Fumadocs MDX).

## Development

```bash
npm install
npm run dev
```

Open [http://localhost:3000/docs](http://localhost:3000/docs).

## Adding a page

Add an `.mdx` file under `content/docs/`, then list it in the nearest
`meta.json`'s `"pages"` array so it appears in the sidebar. A folder with its
own `meta.json` + `index.mdx` becomes a collapsible group.

## Build

```bash
npm run build
npm run start
```

## Deploying to Vercel

This is a self-contained Next.js app rooted at `docs/` inside the
SwiftAgentKit repository (a Swift package, not a JS project) — so when
importing the repo into Vercel:

1. Go to [vercel.com/new](https://vercel.com/new) and import the
   `nandan-varma/SwiftAgentKit` GitHub repository.
2. In the project's **Root Directory** setting, set it to `docs`.
   Vercel will then auto-detect the Next.js framework and use the default
   build (`npm run build`) and output settings — no further configuration
   needed.
3. Deploy. Every push to the default branch redeploys automatically; PRs get
   preview deployments.

If you'd rather configure this from the CLI instead of the dashboard:

```bash
npm i -g vercel
cd docs
vercel link
vercel --prod
```

`vercel.json` in this directory pins the framework explicitly so a CLI-based
or dashboard "Root Directory: docs" import works without extra clicks.
