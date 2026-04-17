---
name: A General-Purpose Async Loading Component for React Query
version: 1
description: >-
  One way to centralise loading, error, and retry UI for React Query without
  leaking query state into every component.
match: >-
  React components that render async data, pages or views with loading/error
  states, and any component that calls useQuery or useMutation
matchCriteria:
  globs:
    - "src/renderer/**/*.tsx"
  contentMatch:
    - "useQuery"
    - "useMutation"
categories:
  - 'frontend:async-handling'
  - 'frontend:error-handling'
visibility: public
registryId: a-general-purpose-async-loading-component-for-react-query
registryVersion: 1
---
Most React Query codebases end up with the same three-way conditional scattered across dozens of components:

```tsx
if (query.isLoading) return <Spinner />;
if (query.isError) return <Error />;
return <Component data={query.data} />;
```

It works, but it doesn't scale well. Loading and error UIs become inconsistent. Retry logic gets wired up differently in every file. Background refetch states go unhandled. And when a view depends on multiple queries, the state coordination compounds.

One approach I like is to extract this into a general-purpose component that accepts any React Query result object and handles the state machine for you.

## Overview

- **`AsyncContent`** — handles a single query with configurable loading, error, and refetching UI
- **`AsyncGroup`** — handles multiple queries that must all resolve before rendering
- Both accept the raw `UseQueryResult` from React Query — no wrappers or adapters needed
- Render-prop children give callers full control over the success case with proper type narrowing
- The full source and interactive demo are on [GitHub](https://github.com/torbensko/async-loading-component)

## AsyncContent

The simplest usage is zero-config. Pass a query and a render function:

```tsx
const userQuery = useQuery({ queryKey: ["user"], queryFn: fetchUser });

<AsyncContent query={userQuery}>
  {(user) => <UserCard user={user} />}
</AsyncContent>;
```

The component shows a default spinner during initial load, a default error UI with retry on failure, and calls `children(data)` once data is available. The `data` parameter is guaranteed non-undefined — no `!` assertions needed.

### Custom loading state

Pass any `ReactNode` as `loadingFallback`. The component doesn't need to know whether it's a skeleton, a shimmer, or a branded spinner — that's the caller's decision:

```tsx
<AsyncContent
  query={userQuery}
  loadingFallback={<UserCardSkeleton />}
  placeholderHeight={120}
>
  {(user) => <UserCard user={user} />}
</AsyncContent>
```

`placeholderHeight` sets a `min-height` on the loading placeholder to prevent layout shift.

### Error handling with retry

The default error UI shows the error message and a retry button wired to `refetch()`. For custom error UI, pass `errorFallback`:

```tsx
<AsyncContent
  query={postsQuery}
  errorFallback={(error, retry) => (
    <div className="error-banner">
      <p>{error.message}</p>
      <button onClick={retry}>Try again</button>
    </div>
  )}
>
  {(posts) => <PostList posts={posts} />}
</AsyncContent>
```

The retry callback is always provided. This is a deliberate choice — baking retry into the component means it can't be forgotten, which is easy to do when every component handles errors independently.

### Background refetch indicator

React Query v5 distinguishes between `isPending` (no data yet) and `isFetching` (request in flight). When data is already on screen and a background refetch runs, AsyncContent overlays a small spinner in the top-right corner by default.

This is configurable:

```tsx
// Default: small spinner in top-right corner
<AsyncContent query={query}>
  {(data) => <View data={data} />}
</AsyncContent>

// Custom indicator
<AsyncContent query={query} refetchingIndicator={<SyncBadge />}>
  {(data) => <View data={data} />}
</AsyncContent>

// Disabled
<AsyncContent query={query} refetchingIndicator={false}>
  {(data) => <View data={data} />}
</AsyncContent>
```

The custom indicator is rendered inside a `position: relative` wrapper, so you can absolutely position it wherever you like.

### Dependent queries

When a query has `enabled: false`, it's in a `isPending` state but not fetching. AsyncContent detects this (`isPending && !isFetching`) and renders nothing, which avoids showing an infinite spinner for queries that haven't fired yet:

```tsx
const postsQuery = useQuery({
  queryKey: ["posts", userId],
  queryFn: () => fetchPostsByUser(userId),
  enabled: userId !== null,
});

// Renders nothing until userId is set and the query fires
<AsyncContent query={postsQuery}>
  {(posts) => <PostList posts={posts} />}
</AsyncContent>;
```

## AsyncGroup

When a view depends on multiple queries, AsyncGroup waits for all of them to resolve before calling the render function. The children receive a typed readonly tuple:

```tsx
const usersQuery = useQuery({ queryKey: ["users"], queryFn: fetchUsers });
const statsQuery = useQuery({ queryKey: ["stats"], queryFn: fetchStats });

<AsyncGroup queries={[usersQuery, statsQuery] as const}>
  {([users, stats]) => <Dashboard users={users} stats={stats} />}
</AsyncGroup>;
```

The `as const` on the queries array gives you full tuple type inference in the callback — `users` is typed as `User[]`, `stats` as `Stats`, etc.

If any query fails, the error UI is shown. The retry callback only refetches the queries that actually failed, not the ones that succeeded:

```tsx
const retryFailed = () => {
  queries.filter((q) => q.isError).forEach((q) => q.refetch());
};
```

This avoids unnecessary network requests and prevents UI flicker on already-loaded data.

## The state machine

Both components follow the same decision tree:

1. **Idle** (`isPending && !isFetching`) — query hasn't fired → render nothing
2. **Loading** (`isPending && isFetching`) — initial load → show `loadingFallback`
3. **Error** (`isError`) — show `errorFallback` or default error with retry
4. **Data undefined** — safety guard → render nothing
5. **Success + fetching** — background refetch → show children with refetch indicator
6. **Success** — show children

This is deliberate. The original version used React Query's `isLoading`, which maps to `isPending && isFetching` — first load only. That's usually correct for the loading state, but the component also needs to distinguish between "hasn't fired yet" and "is fetching for the first time", which requires checking both flags independently.

## Implementation

The core `AsyncContent` component:

```tsx
type AsyncContentProps<TData, TError = unknown> = {
  query: UseQueryResult<TData, TError>;
  children: (data: TData) => React.ReactNode;
  loadingFallback?: React.ReactNode;
  placeholderHeight?: number | string;
  refetchingIndicator?: React.ReactNode | false;
  errorFallback?: (error: TError, retry: () => void) => React.ReactNode;
};

export function AsyncContent<TData, TError = unknown>({
  query,
  children,
  loadingFallback,
  placeholderHeight,
  refetchingIndicator,
  errorFallback,
}: AsyncContentProps<TData, TError>) {
  const { isPending, isFetching, isError, error, data, refetch } = query;

  // Query hasn't fired yet (e.g. enabled: false) — show nothing.
  if (isPending && !isFetching) return null;

  // Initial load — no data yet.
  if (isPending) {
    return (
      <Placeholder height={placeholderHeight}>
        {loadingFallback ?? <DefaultSpinner />}
      </Placeholder>
    );
  }

  if (isError) {
    if (errorFallback) return <>{errorFallback(error as TError, refetch)}</>;
    return <DefaultError error={error} onRetry={refetch} />;
  }

  if (data === undefined) return null;

  const content = children(data);

  if (isFetching && refetchingIndicator !== false) {
    return (
      <RefetchingWrapper
        indicator={refetchingIndicator ?? <DefaultRefetchingIndicator />}
      >
        {content}
      </RefetchingWrapper>
    );
  }

  return <>{content}</>;
}
```

And `AsyncGroup` for multiple queries:

```tsx
type ResolvedData<TQueries extends readonly UseQueryResult<any, any>[]> = {
  readonly [K in keyof TQueries]: TQueries[K] extends UseQueryResult<
    infer D,
    any
  >
    ? D
    : never;
};

type AsyncGroupProps<TQueries extends readonly UseQueryResult<any, any>[]> = {
  queries: TQueries;
  children: (data: ResolvedData<TQueries>) => React.ReactNode;
  loadingFallback?: React.ReactNode;
  placeholderHeight?: number | string;
  refetchingIndicator?: React.ReactNode | false;
  errorFallback?: (error: unknown, retryFailed: () => void) => React.ReactNode;
};

export function AsyncGroup<
  TQueries extends readonly UseQueryResult<any, any>[],
>(props: AsyncGroupProps<TQueries>) {
  const {
    queries,
    children,
    loadingFallback,
    placeholderHeight,
    refetchingIndicator,
    errorFallback,
  } = props;

  const anyPendingIdle = queries.some((q) => q.isPending && !q.isFetching);
  const anyLoading = queries.some((q) => q.isPending && q.isFetching);
  const errorQuery = queries.find((q) => q.isError);
  const anyFetching = queries.some((q) => q.isFetching);

  if (anyPendingIdle) return null;

  if (anyLoading) {
    return (
      <Placeholder height={placeholderHeight}>
        {loadingFallback ?? <DefaultSpinner />}
      </Placeholder>
    );
  }

  if (errorQuery) {
    const retryFailed = () => {
      queries.filter((q) => q.isError).forEach((q) => q.refetch());
    };
    if (errorFallback)
      return <>{errorFallback(errorQuery.error, retryFailed)}</>;
    return <DefaultError error={errorQuery.error} onRetry={retryFailed} />;
  }

  const allData = queries.map((q) => q.data);
  if (allData.some((d) => d === undefined)) return null;

  const content = children(allData as ResolvedData<TQueries>);

  if (anyFetching && refetchingIndicator !== false) {
    return (
      <RefetchingWrapper
        indicator={refetchingIndicator ?? <DefaultRefetchingIndicator />}
      >
        {content}
      </RefetchingWrapper>
    );
  }

  return <>{content}</>;
}
```

The shared primitives (`Placeholder`, `DefaultSpinner`, `DefaultError`, `RefetchingWrapper`) are intentionally simple — see the full source on GitHub.

## Try it

The [full source](https://github.com/torbensko/async-loading-component) is on GitHub. The demo includes per-endpoint controls for adjusting simulated delay and triggering errors, so you can see each state transition in action.

For more on building components alongside interactive demos, see [Demo Driven Development](/blog/demo-driven-development). For the API mocking approach used in the demo, see [API Mocking Pattern for React and Storybook](/blog/api-mocking-pattern).
