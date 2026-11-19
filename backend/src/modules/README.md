# Modules Directory

This directory is designed for feature-based modular architecture. Each domain or feature will reside in its own self-contained module folder as development progresses.

## Recommended Module Structure

When adding a new module (for example, `auth` or `cycles`), structure it as follows:

```
src/modules/<module-name>/
├── <module-name>.routes.ts      # Express route definitions
├── <module-name>.controller.ts  # HTTP request and response handlers
├── <module-name>.service.ts     # Business logic & database operations
├── <module-name>.schema.ts      # Zod validation schemas
└── <module-name>.types.ts       # TypeScript interfaces & types
```

## Guidelines
- Keep business logic in services, separated from controllers and Express request/response objects.
- Validate request inputs using Zod schemas before passing data to services.
- Mount module routes in `src/app.ts` under `/api/<module-name>`.

