# React + TypeScript conventions

Stack-specific rules for React/TS projects. Edit to taste; these are defaults.

## Toolchain
- Language: TypeScript, `strict` on. No implicit `any`.
- Build/dev: Vite.
- Package manager: pnpm.
- Formatter: Prettier.
- Linter: ESLint (typescript-eslint, react-hooks rules).
- Test runner: Vitest + React Testing Library.
- Commands: `pnpm dev` / `pnpm test` / `pnpm build` / `pnpm lint`.

## Idioms to follow
- Function components + hooks only. No class components.
- Type props with explicit interfaces; prefer discriminated unions over optional-flag soup.
- Composition over inheritance/config props. Small components, lifted state only as far as needed.
- Co-locate component, its test, and styles. Test behavior via RTL (query by role/text), not implementation.
- Data fetching: a dedicated layer/hook (e.g. React Query). Keep fetching out of view components.
- Derive state; don't duplicate it. `useMemo`/`useCallback` only when there's a measured reason.
- Keys are stable IDs, never array index.

## Things to avoid
- Prop-drilling more than ~2 levels. Reach for context or a store instead.
- `useEffect` for things that aren't synchronizing with an external system (no effect-as-event-handler).
- `any`, non-null `!` assertions, and `// @ts-ignore`. Fix the type.
- Inline anonymous handlers in hot lists when it causes real re-render cost.
- Barrel `index.ts` files that re-export everything (hurts tree-shaking + import clarity).

## Project layout (typical)
- `src/components/`: presentational + feature components (component + test co-located)
- `src/hooks/`: reusable hooks
- `src/lib/` or `src/api/`: data layer, clients
- `src/store/`: global state (if any)
- `src/routes/` or `src/pages/`: route entries
