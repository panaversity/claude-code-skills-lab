# Usage Patterns

Real-world examples for common scenarios.

## Pattern A: Implementing React Feature

Building a form component with hooks:

```bash
python3 scripts/fetch-docs.py --library-id /reactjs/react.dev \
  --topic "form handling useState" \
  --content-type examples,api-ref
```

## Pattern B: Debugging Prisma Error

Error: `PrismaClientKnownRequestError: Unique constraint failed`

```bash
python3 scripts/fetch-docs.py --library-id /prisma/docs \
  --topic "unique constraint error" \
  --content-type troubleshooting,examples
```

## Pattern C: Setting Up Next.js Auth

Adding authentication to Next.js app:

```bash
python3 scripts/fetch-docs.py --library-id /vercel/next.js \
  --topic "authentication middleware" \
  --content-type setup,examples
```

## Pattern D: Upgrading Tailwind

Migrating from Tailwind v3 to v4:

```bash
python3 scripts/fetch-docs.py --library tailwind \
  --topic "upgrade v3 v4" \
  --content-type migration
```

## Pattern E: Best Practices Query

Should I use server components?

```bash
python3 scripts/fetch-docs.py --library-id /vercel/next.js \
  --topic "server components" \
  --content-type patterns,concepts
```

## Pattern F: Library Integration

Connecting Prisma with Next.js API routes:

```bash
python3 scripts/fetch-docs.py --library-id /prisma/docs \
  --topic "next.js integration api routes" \
  --content-type examples,setup
```

## Pattern G: Installing Framework

Setting up Tailwind in new project:

```bash
python3 scripts/fetch-docs.py --library-id /tailwindlabs/tailwindcss.com \
  --topic "installation next.js" \
  --content-type setup
```

## Pattern H: API Reference Lookup

Quick lookup for function parameters:

```bash
python3 scripts/fetch-docs.py --library-id /reactjs/react.dev \
  --topic "useEffect" \
  --content-type api-ref
```

## Content Type Quick Reference

| Content Type | Use For |
|--------------|---------|
| `examples` | Code samples, syntax patterns |
| `api-ref` | Function signatures, parameters |
| `setup` | Installation, configuration |
| `concepts` | Understanding how/why |
| `troubleshooting` | Debugging, error fixes |
| `migration` | Version upgrades, breaking changes |
| `patterns` | Best practices, recommendations |
| `all` | Full exploration (no filtering) |
