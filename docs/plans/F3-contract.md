# F3 — Build contract

**Branch:** `F3/todoist` · **Written:** 2026-08-23 · **Author:** solutions architect
**Binds:** `docs/specs/SPEC.md` (F3), `CLAUDE.md`, `docs/plans/00-deltas.md` D5 · D11 · D16 · D17 · D18,
`docs/plans/F3.md`.

Two engineers implement this literally. Where this document and `F3.md` disagree, this document says so
out loud and gives the reason; where this document and `SPEC.md` disagree, `SPEC.md` wins and the
disagreement is a `Proposed spec delta:` in the PR, not a code change.

---

## 0. What was verified against the live Todoist documentation before writing this

`D5` instructs that the API surface is confirmed against the live docs before the client is written, and
that what is found is pinned in a comment beside it. This is that verification. Source for everything in
this section: **https://developer.todoist.com/api/v1/**, fetched 2026-08-23.

### 0.1 Base URL and authentication

| | |
|---|---|
| Base URL | `https://api.todoist.com/api/v1` |
| Auth header | `Authorization: Bearer <token>` |
| Where the user gets the token | Todoist → Settings → **Integrations** → Developer → API token. The docs link this as `https://app.todoist.com/app/settings/integrations`. |

Quoted from the docs: *"your application must provide an authorization header with the appropriate
`Bearer $token`. For working through the examples, you can obtain your personal API token from the
integrations settings for your account."*

**This confirms D18 is buildable exactly as ratified.** A personal API token is a first-class,
documented credential for this API; it is the same `Bearer` header an OAuth token uses, so nothing
downstream of the header knows or cares which kind it is. There is no client id, no client secret, no
callback scheme, and no token exchange.

### 0.2 Endpoints — F3.md's table is correct, and confirmed

| Purpose | Method | Path | Confirmed |
|---|---|---|---|
| Projects | GET | `/api/v1/projects` | `operationId: get_projects_api_v1_projects_get` |
| Sections | GET | `/api/v1/sections` | `operationId: get_sections_api_v1_sections_get` |
| Tasks | GET | `/api/v1/tasks` | `operationId: get_tasks_api_v1_tasks_get` |
| **Complete** | **POST** | **`/api/v1/tasks/{task_id}/close`** | `operationId: close_task_api_v1_tasks__task_id__close_post` |

`POST /tasks/{task_id}/close` is documented as: *"Closes a task. … Regular tasks are marked complete and
moved to history, along with their subtasks. Tasks with recurring due dates will be scheduled to their
next occurrence."* Path parameter `task_id` is **`type: string`**. Success is **200** with a JSON body
(the schema is empty — treat the body as opaque and do not decode it). Documented failures: 400, 401,
403, 404.

All three GET endpoints are documented as returning **active** objects only — *"Get all active user
projects"*, *"Get all active sections for the user"*, *"Get all active tasks for the user"*. Nothing
archived, completed or deleted is ever in a response, which is load-bearing for §3.

Neighbouring endpoints that exist and that this app must never name: `POST /tasks`, `POST
/tasks/{id}`, `POST /tasks/{id}/move`, `POST /tasks/{id}/reopen`, `DELETE /tasks/{id}`,
`POST /tasks/quick`, `GET /tasks/filter`, `POST /projects`, `POST /sections`, `POST /comments`,
`POST /sync`. They are listed here so that no engineer has to go and look at the documentation page —
looking is how one of them ends up in a commit.

### 0.3 Pagination — cursor, and F3.md's `{results, next_cursor}` is correct

Quoted: *"Paginated endpoints use **cursor-based pagination**. … `results`: An array containing the
requested objects. `next_cursor`: A string token for fetching the next page, or `null` if there are no
more results. … When `next_cursor` is `null`, you've reached the end of the results."*

| | |
|---|---|
| Query parameter for the page size | `limit` — **default 50, maximum 200**. A limit above 200 is a `400` with `error_tag: INVALID_ARGUMENT_VALUE`. |
| Query parameter for the next page | `cursor` — an opaque string. Docs: *"Do not attempt to decode, parse, or modify cursors — pass them as-is from the previous response."* |
| Envelope | `PaginatedList`: `{"results": [...], "next_cursor": "..."|null}`. Both keys are `required` in the schema. There is **no `has_more`** on these three endpoints; `has_more` belongs to the sync response and must not be looked for. |
| Warning the docs give | *"Do not depend on the number of results being fewer than the limit value to indicate that your query reached the end … use the absence of next instead."* And: *"Always use the same parameters (filters, sorting, etc.) when using a cursor."* |
| Consistency caveat | *"Todoist data may change while you're paginating … This can cause items to appear twice or be skipped. If consistency is critical, implement deduplication logic."* |
| Cursor lifetime | *"Don't store cursors long-term."* |

**Consequences taken in §2:** page size is `limit=200`, cursors are never persisted, the loop stops only
on a null/absent/empty `next_cursor`, and the cache upsert de-duplicates by id so a row seen on two
pages cannot produce two rows.

### 0.4 Rate limits — and the honest finding that contradicts an assumption in F3.md

`F3.md` says *"Rate limits are confirmed against the live docs at implementation time and pinned in a
comment."* Here is what the live docs actually publish, under **Request limits**:

| | Published value |
|---|---|
| Partial sync requests | **1000 per user per 15-minute period** |
| Full sync requests | **100 per user per 15-minute period** |
| Sync commands per request | 100 maximum |
| POST request body | 1 MiB |
| Total HTTP header size | 65 KiB |
| Standard request processing timeout | **15 seconds** |
| Upload processing timeout | 5 minutes |

**The finding: Todoist publishes no separate numeric ceiling for the paginated non-sync endpoints.**
The entire *Rate Limiting* subsection is written about `/sync` — *"Limits are applied differently for
full and partial syncs"* — and `GET /projects`, `GET /sections`, `GET /tasks` and `POST
/tasks/{id}/close` are not sync requests. Third-party summaries that say "1000 requests per 15 minutes"
are restating the *partial sync* number and applying it more broadly than the documentation does.

So the honest posture, and the one the client's comment must state, is: **the ceiling that applies to
our four endpoints is undocumented; assume the strictest published number (1000 per user per 15
minutes) applies, and stay far under it by design rather than by budget.** Our access pattern does:
three GETs' worth of pages on foreground and on an explicit pull-to-refresh, one POST per completed
task, and a search that filters the local cache and never touches the network. At `limit=200` a
5,000-task account costs 25 + 1 + 1 = 27 requests per full refresh.

`429` is handled from the response, not from a budget we keep ourselves — see §2.6. The docs show the
backoff metadata shape on a `401` example, and it is the same envelope for `429`:

```
Retry-After: 3
{"error_tag": "...", "error_code": 477, "error": "...", "http_code": 401,
 "error_extra": {"retry_after": 3, "event_id": "<hash>"}}
```

### 0.5 Object ids are opaque strings in v1

Quoted from *Migrating from v9*: *"IDs have been opaque strings almost everywhere since the release of
Sync API v9, but were still mostly numbers in that version. **This version officially makes them
non-number opaque strings, changing the old IDs.** … Old IDs will NOT be accepted in this new API
version for the following objects: notes / comments, items / tasks, projects, sections …"*

Confirmed in the schemas: `ItemSyncView.id`, `.project_id` are `type: string`; `.section_id` and
`.parent_id` are `string | null`. `SectionSyncView.id`, `.project_id` are `type: string`. Project ids
are `type: string`. Example ids look like `6XGgmFVcrG5RRjVr`.

**Every Todoist identifier in this codebase is a Swift `String`. Never `Int`, never `UUID`, never
"parse it and see".** A `UUID` column would silently reject every real id.

### 0.6 v9 / v2 status — D5 stands, with one correction of emphasis

The live v1 page says: *"The Todoist API v1 is a new API that unifies the Sync API v9 and the REST API
v2. … The documentation for the Sync API v9 and REST API v2 are still available for reference."*

**The correction:** the v1 documentation page does **not** itself restate a removal date, and it
describes the older docs as still online *for reference*. D5's date (2026-02-10) is corroborated
outside Todoist's reference page (Doist's migration notices and downstream trackers, e.g. the n8n
issue titled "Todoist API EOL 2026-02-10"), not on it. Nothing in F3 changes as a result: **API v1 is
the only current surface, it is what we build against, and no v9/v2 URL may appear in the tree.** The
correction is recorded so nobody later reads D5's date off the v1 page, fails to find it, and concludes
the delta is wrong.

### 0.7 Two things in `F3.md` that D18 killed and that must not be built

`F3.md` predates D18. These clauses are **void**, and an engineer who implements them fails review:

1. **F3.md "Preconditions inherited from F1" #1 — "fail the build on a blank credential."** There is no
   build-time credential any more. `TODOIST_CLIENT_ID` / `TODOIST_CLIENT_SECRET` are deleted by D18.
   **F3 adds no build-time credential check, and touches no `.xcconfig`.**
2. **F3.md's test `oauthStateMismatchRejected`.** There is no OAuth, no callback, and no `state`
   parameter. The test is struck; §7's table is the real list.

Also void: F3.md's risk bullets *"Embedded client secret"* and *"Scope of `data:read_write`"*. A
personal token carries the user's own account scope; there is nothing embedded to leak.

### 0.8 `F3.md` precondition #2 — the fenced-file conflict, named rather than resolved unilaterally

`F3.md` says F3's gate does not pass until `scripts/check-todoist-writes.sh` binds **method** to
**path**, because `POST /tasks` (create) and `GET /tasks` (read) share a path and the script compares
paths only.

**The build brief for this feature forbids modifying `scripts/`, `.githooks/` and the CI workflow**,
excepting `scripts/todoist-allowed-endpoints.txt`. The two instructions conflict, and an architect who
quietly picks one has hidden a decision the owner should make.

**The decision taken here, and why:**

- **The shell script is not modified.** The fence is explicit and repeated, and a script rewrite
  landing inside a feature branch is exactly the kind of gate-weakening-by-accident the script's own
  header warns about.
- **The method binding is implemented in Swift instead, where F3 is allowed to write**, and it is
  stronger than a grep would be. §2.2 makes the endpoint table a closed, exhaustive value; §7's
  `theOnlyPostEndpointIsClose` and `noMutatingRequestsOtherThanClose` check the method against the path
  as data and as traffic. `grep -rn '"POST"' ZenTomato/` returns exactly one line, and that line is in
  the close path.
- **The residual gap is recorded, not papered over.** A future engineer could still add `POST /tasks`
  and the shell script alone would not catch it; the Swift table test would, and it runs in `make ci`.
  Raising the script to method-awareness is proposed in the PR as **`F1b` — a retrofit on F1's script**,
  following the precedent set when F5's review proposed `F2b`. It is one file, it is F1's, and it is
  the owner's call, not F3's.

**`scripts/todoist-allowed-endpoints.txt` needs no new entry.** F1 seeded it with exactly the four
lines §0.2 confirms, method column included. F3's only change to it is replacing the paragraph headed
`STATUS AT F1: no Todoist code exists yet.` with a `STATUS AT F3:` paragraph naming
`ZenTomato/Todoist/TodoistAPI.swift` as the file this list now mirrors. **Comment lines only. If a
diff to this file changes a `GET`/`POST` line, the feature has gone wrong.**

---

## 1. Decisions this contract takes, so no engineer has to

1. **Todoist is optional to the app.** The timer screen stays the app's root. A person with no token
   runs the timer, the log and the reflection sheet exactly as F2 and F5 shipped them. Sign-in is
   reached from the plan/picker entry point, never as a gate at launch. This is a deliberate reading of
   D18 — D18 describes the paste as *"the very first screen anybody sees"* while stating a cost, not
   prescribing a location — and it also removes the worst version of D18's own worry: a bare text field
   is never the first thing in front of a reviewer.
2. **`PomodoroSession` gains the four snapshot columns. `Distraction` does not.** F3.md's T5 says both
   do. `Distraction.sessionID` equals `PomodoroSession.id` by construction (F5-contract §3.2), so the
   attachment of a tap is a join away and is already unambiguous. Two copies of one snapshot on two
   tables is two accounts of one fact that can disagree, and F5's review deleted exactly these columns
   from `Distraction` once already. Recorded in the PR as a departure from F3.md; if the owner wants
   them, it is four optional columns and no migration.
3. **`TimerState` carries the running block's attachment.** Not an in-memory field on the engine. A
   block can end while the app is closed; `synchronize()` writes its `PomodoroSession` on the next
   foreground, and an in-memory attachment would be gone by then, producing a row with four silent
   `nil`s. Durable state is the only correct answer here.
4. **Attachment is optional.** With no plan, an exhausted plan, or no Todoist at all, the four columns
   are `nil` and the screen says the block has no plan item. `SPEC.md`'s *"a pomodoro is attached to
   exactly one Todoist task (or … a project)"* describes a pomodoro that has a Todoist attachment; it
   cannot mean the timer refuses to run without one, because the timer shipped and is in use. Named in
   the PR so the owner can rule otherwise.
5. **A `401` clears the token and nothing else.** Sign-out clears the token, the whole cache, and the
   session plan. A revoked token is Todoist's act, not the user's, and throwing away a half-worked plan
   because a credential expired destroys intent for no security gain — the cache holds no secret.
6. **A successful close deletes that task's cached row.** So the picker stops offering it. This is the
   mirror catching up early; the next full refresh would do the same thing, because the API returns
   active tasks only. It is **not** a completion flag, and no column records it.
7. **No queue, no outbox, no retry-later, anywhere.** Offline ⇒ the cache is served and Complete is
   disabled with a plain sentence. D16 forbids the machinery and F3.md gives the reason: *"a queued
   completion is a write we cannot see, and the one rule here is that we can always see our writes."*
8. **Sub-tasks are flat.** `parent_id` is not mirrored (§3.4). A sub-task appears as an ordinary task
   in its section. Stated as a limitation in the PR rather than fixed by a field with no reader.

---

## 2. The API client

### 2.1 Files

```
ZenTomato/Todoist/TodoistAPI.swift          the base URL, the version, the four endpoints. Nothing else.
ZenTomato/Todoist/TodoistTransport.swift    protocol + URLSession implementation. The test seam.
ZenTomato/Todoist/TodoistClient.swift       the only place a URLRequest is built. Pagination. Errors.
ZenTomato/Todoist/TodoistError.swift        the failure vocabulary, with no credential in any case.
ZenTomato/Todoist/TodoistDTO.swift          the decoded value types. Sendable, no SwiftData.
ZenTomato/Todoist/TodoistRetryWaiting.swift the sleep seam, so no test sleeps.
```

### 2.2 `TodoistAPI` — the endpoint table, and how a URL is built so the hook can see it

This is a **design constraint, not a detail**. `scripts/check-todoist-writes.sh` finds Todoist
references by matching string literals: a full URL literal, a bare path literal beginning `/projects`,
`/sections`, `/tasks`…, or a literal inside `appending(path:)`. A URL assembled from runtime pieces
matches nothing and defeats the gate silently.

**The rules, all four mandatory:**

1. **Every path is a string literal in `TodoistAPI.swift` and nowhere else in the tree.** Exactly one
   file contains `api.todoist.com`.
2. **A path is never built by concatenating a noun onto a variable.** `"/" + resource` is forbidden.
   `"/tasks/\(taskID)/close"` is required and correct — the script normalises a `\(…)` segment to
   `{id}`, and its header says so in as many words.
3. **`Endpoint`'s memberwise initialiser is `private`.** The only `Endpoint` values that can exist are
   the four `static let`s below. A caller cannot construct a fifth at a call site, at runtime, or in a
   test.
4. **`Endpoint` carries its method.** The method is never written at a call site.

```
enum TodoistAPI {
  static let baseURL = URL(string: "https://api.todoist.com/api/v1")   // ← the one host literal

  enum Method: String, Sendable { case get = "GET", post = "POST" }    // ← the one "POST" literal

  struct Endpoint: Sendable, Equatable {
    let method: Method
    let path: String          // begins "/", may contain one \(id) segment
    private init(method:path:)
  }

  static let projects  = Endpoint(method: .get,  path: "/projects")
  static let sections  = Endpoint(method: .get,  path: "/sections")
  static let tasks     = Endpoint(method: .get,  path: "/tasks")
  static func closeTask(id: String) -> Endpoint { Endpoint(method: .post, path: "/tasks/\(id)/close") }

  /// Every endpoint this app may ever contact, for the test that mirrors the allowlist.
  static var allEndpoints: [Endpoint] { [projects, sections, tasks, closeTask(id: "{id}")] }
}
```

`allEndpoints` exists to be enumerated by `theOnlyPostEndpointIsClose` (§7). That is a reader, so it is
not preparation under D16's test.

**Pinned beside the constants, verbatim, per D5.** This comment is required, not optional:

```
// TODOIST API v1 — verified against https://developer.todoist.com/api/v1/ on 2026-08-23.
//
//   Base            https://api.todoist.com/api/v1
//   Auth            Authorization: Bearer <personal API token>   (D18)
//   Ids             opaque STRINGS. v9/v2 numeric ids are not accepted (Migrating from v9).
//   Pagination      {"results": [...], "next_cursor": String?}; cursor + limit query params;
//                   limit default 50, MAXIMUM 200; stop only when next_cursor is null.
//   Rate limits     Todoist publishes numbers for the SYNC endpoints only: 1000 partial-sync and
//                   100 full-sync requests per user per 15 minutes. NO separate published ceiling
//                   exists for the four endpoints below. We assume the strictest published number
//                   applies and stay far under it by design: a refresh on foreground and on an
//                   explicit pull, never per keystroke. Search filters the local cache.
//   Also published  15s standard request timeout; 1 MiB POST body; 65 KiB headers.
//   429 / 401       honour the Retry-After header; error_extra.retry_after carries the same number.
//   v9 / v2         superseded by v1 (D5). Their docs remain online for reference only; no v9 or
//                   v2 URL may appear anywhere in this tree.
```

### 2.3 The transport seam

```
protocol TodoistTransport: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: TodoistTransport { let session: URLSession }
```

Every test injects `StubTodoistTransport`, which returns canned `(Data, HTTPURLResponse)` pairs from a
script and **records every request it was handed**. No test constructs a `URLSessionTransport`. There
is no `URLProtocol` subclass, no `.ephemeral` real session, and no network in the test bundle.

If `URLSession` is rejected under strict concurrency, hold it as `let` on a `final class
URLSessionTransport: TodoistTransport, @unchecked Sendable` with a one-line comment naming the reason.
Do not work around it by creating a session per request.

### 2.4 `TodoistClient` — the shape

```
struct TodoistClient: Sendable {
  let transport: any TodoistTransport
  let tokens: any TokenStore
  let waiting: any TodoistRetryWaiting

  func fetchProjects() async throws -> [TodoistProjectDTO]
  func fetchSections() async throws -> [TodoistSectionDTO]
  func fetchTasks()    async throws -> [TodoistTaskDTO]
  func closeTask(id: String) async throws
}
```

`nonisolated` throughout. It never sees a `ModelContext`, a `@Model`, a view, or the main actor.

**One private request builder, and it is the only `URLRequest(` in the tree:**

```
private func makeRequest(_ endpoint: TodoistAPI.Endpoint, cursor: String?) throws -> URLRequest
```

It reads the token from `tokens`, throws `.notSignedIn` if there is none, sets exactly two headers
(`Authorization: Bearer …` and `Accept: application/json`), sets `httpMethod = endpoint.method.rawValue`,
and builds the URL with `URLComponents` so `cursor` and `limit` are percent-encoded properly. **It sets
no `httpBody`, ever** — the close endpoint takes no body, and a client with no body-writing code cannot
grow a create call by accident.

### 2.5 Pagination

One private generic page loop, used by all three GETs:

- `limit=200` on every request (§0.3 documented maximum: fewer round trips, fewer chances to be rate
  limited).
- Decode `{results, next_cursor}`. Continue while `next_cursor` is a non-empty string; stop on `null`,
  absent, or `""`. **Never** infer the end from a short page — the docs say not to.
- Pass the cursor back exactly as received; never decode, trim or validate it.
- Cursors are held in a local variable for the duration of the loop and **never persisted**.
- **Page cap: 250 pages per endpoint** (50,000 rows). A server that returns the same cursor forever
  would otherwise hang the refresh with no error. Exceeding the cap throws `.paginationDidNotTerminate`
  and the refresh fails loudly.
- Duplicates across pages are possible (documented). De-duplication happens once, in the cache upsert,
  keyed on id — not in the client.

### 2.6 Errors

```
enum TodoistError: Error, Equatable {
  case notSignedIn
  case tokenRejected                    // 401 — the token was revoked in Todoist
  case rateLimited(retryAfter: Duration?)   // 429
  case offline
  case server(status: Int)              // any other non-2xx
  case malformedResponse
  case paginationDidNotTerminate
}
```

**No case carries the token, the request, the response body, or a `URL` that could contain one. No
associated value is a `String` that came from the wire.** `LocalizedError` messages are written by
hand, and `tokenRejected`'s is *"Todoist rejected this token. It was probably revoked. Enter a new
one."* — F3.md requires the plain wording, not a generic failure.

Mapping:

| Status | Behaviour |
|---|---|
| 2xx | Decode (GET) or ignore the body (close). |
| 401 | Clear the Keychain item, throw `.tokenRejected`. Cache and plan are untouched (§1.5). |
| 429 | Read `Retry-After` (seconds). **One** retry, and only if the delay is ≤ 60 s. Otherwise throw `.rateLimited`. Never a loop. |
| `URLError.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut` | `.offline`. |
| anything else | `.server(status:)`. |

The wait is `try await waiting.wait(for: delay)`. `TodoistRetryWaiting` has one real implementation
(`ContinuousClock`) and one test double that records the requested duration and returns immediately.
**No test sleeps. `rateLimitBacksOff` asserts on the recorded duration, not on elapsed time.**

### 2.7 The token store

```
protocol TokenStore: Sendable {
  func read() throws -> String?
  func write(_ token: String) throws
  func clear() throws
}

struct KeychainTokenStore: TokenStore   // ZenTomato/Todoist/KeychainTokenStore.swift
```

- `kSecClassGenericPassword`, service `com.martingleason.ZenTomato.todoist`, account `apiToken`.
- **`kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly`** — D18, non-negotiable. Not
  synced to iCloud Keychain, not readable while locked.
- `write` is delete-then-add, so a second sign-in replaces rather than returning `errSecDuplicateItem`.
- Every `OSStatus` is checked. No `SecItemCopyMatching` result is force-cast; the `CFTypeRef` is bridged
  with a conditional cast and a `nil` result is `nil`, not a crash.
- The token is trimmed of whitespace and newlines on entry (people paste with a trailing newline) and
  rejected as empty if nothing remains.
- **Nothing in this file, or any file, prints, logs, interpolates into an error, or returns a token in a
  description.** `grep -rn 'print(\|NSLog\|os_log\|Logger' ZenTomato/Todoist/` returns nothing.

Tests use `InMemoryTokenStore`, so the simulator's real Keychain is never written by the suite. Exactly
one test exercises `KeychainTokenStore` against the real Keychain, writes a value that is not
credential-shaped, and clears it in a `defer`.

---

## 3. The cache

Three dumb mirrors. `ZenTomato/Models/CachedProject.swift`, `CachedSection.swift`, `CachedTask.swift`.

### 3.1 The exact columns, and confirmation that none is invented

| Model | Column | Todoist source | Why it is here |
|---|---|---|---|
| `CachedProject` | `id: String` | `id` | identity |
| | `name: String` | `name` | drawn in the picker |
| | `childOrder: Int` | `child_order` | Todoist's own order of projects |
| | `syncedAt: Date` | — | cache freshness only |
| `CachedSection` | `id: String` | `id` | identity |
| | `name: String` | `name` | drawn in the picker |
| | `projectID: String` | `project_id` | which project it belongs to |
| | `sectionOrder: Int` | `section_order` | Todoist's own order of sections |
| | `syncedAt: Date` | — | cache freshness only |
| `CachedTask` | `id: String` | `id` | identity |
| | `content: String` | `content` | the task's title, drawn and snapshotted |
| | `projectID: String` | `project_id` | which project it belongs to |
| | `sectionID: String?` | `section_id` | which section, `null` when loose in the project |
| | `childOrder: Int` | `child_order` | Todoist's own order of tasks |
| | `syncedAt: Date` | — | cache freshness only |

**Every column above is a verbatim copy of a documented v1 field, except `syncedAt`.** No computed
property, no method, no `@Relationship`, no local flag.

**The order columns are the conservative choice, not a liberty.** `child_order` and `section_order` are
Todoist's fields. Copying them is mirroring; *not* copying them would force the picker to invent an
order (alphabetical, or whatever SwiftData hands back), and inventing an order is precisely what D16
forbids. They are written only by a refresh and read only by a sort descriptor.

**`syncedAt` is cache freshness and nothing else.** D16 names *"a `syncedAt` used for anything but cache
freshness"* as a failure. It is read by exactly one thing: the line that says when the picker last
refreshed. It is never compared between rows, never used to decide precedence, and never used to detect
a change.

### 3.2 What is deliberately not mirrored

Named here so a reviewer's grep has a document to land on, and so that adding one is a visible argument
with this table rather than a small reasonable commit:

`description` · ~~`due`~~ · `deadline` · `duration` · `priority` · `labels` · `parent_id` ·
`checked` · `is_deleted` · `is_archived` · `is_collapsed` · `is_favorite` · `color` · `view_style` ·
`is_shared` · `order_key` · `day_order` · `completed_count` · `added_at` · `updated_at` ·
`user_id` / `creator_uid` / `added_by_uid` / `responsible_uid` · `added_by`.

**`due` left this list under D21, on 2026-08-23, and only in part.** F6 needs to know whether a
completed task was recurring, and Todoist keeps that as `is_recurring` **inside** the `due` object.
What crossed is one derived boolean — `CachedTask.isRecurring` — and nothing else: no date, no
schedule string, no time zone, no language, and nothing from which a recurrence rule could be
reconstructed. The `due` object itself is still not mirrored. This paragraph is the visible argument
with this table that the paragraph above demands.

Three of those deserve their reason spelled out:

- **`checked` / `is_deleted` / `is_archived`** — the three GETs return active objects only (§0.2), so
  these would be `false` on every row we ever store. A column that is always false looks finished and
  is not, and it is the exact shape D16 forbids: *"nil today and meaningful after sync lands."*
- **`parent_id`** — nothing reads it. The picker is project → section → task and sub-tasks appear flat
  (§1.8). A hierarchy column with no reader is a local task hierarchy waiting for one.
- **`color`** — F1's rule is that views may only name semantic roles. A Todoist colour could never be
  drawn even if it were stored.

### 3.3 Refresh is a full replace, never a merge

`ZenTomato/Todoist/TodoistCacheStore.swift`, `@MainActor final class`, holds the `ModelContext`.

```
@MainActor func refresh() async throws        // fetch all three, then replace all three
@MainActor func clear() throws                // sign-out
```

- Fetch **all three endpoints to exhaustion first**, into memory, off the main actor. Only when all
  three have succeeded does anything touch SwiftData. A refresh that fails half way leaves the previous
  cache exactly as it was — a half-replaced cache is worse than a stale one, because the picker would
  show a project whose tasks had been deleted.
- Then, in one main-actor pass: delete every `CachedProject`, `CachedSection` and `CachedTask`, insert
  the new rows with one `syncedAt` for the whole refresh, and `save()` once.
- **Full replace is what makes the "no invented state" claim true**, because there is no local row that
  can survive a refresh and therefore nothing to reconcile. It is also what de-duplicates the
  concurrent-modification case §0.3 warns about: two copies of one id collapse into one row.
- Called on foreground and on an explicit pull-to-refresh in the picker. **Never on a timer, never per
  keystroke, never on app launch before a screen asks for it.**

---

## 4. The session plan, and its fence

This is the section most likely to be got wrong, and the way it goes wrong looks reasonable at every
individual step. Read D17 in `docs/plans/00-deltas.md` in full before writing a line of this.

### 4.1 Where it lives

Two `@Model` types, no relationship between them, matching the house rule set in F5-contract §3.2.

```
// ZenTomato/Models/SessionPlan.swift  — ONE row, replaced when a new plan is made.
@Model final class SessionPlan {
  var createdAt: Date
  var currentIndex: Int          // the cursor. 0-based. May run past the last item.
}

// ZenTomato/Models/SessionPlanItem.swift — one row per planned item.
@Model final class SessionPlanItem {
  var todoistID: String          // D17: the Todoist id
  var titleSnapshot: String      // D17: the title snapshot
  var kind: PlanItemKind         // .task or .project
  var position: Int              // the order the user set
}

enum PlanItemKind: String, Codable, Sendable { case task, project }
```

**Four columns, where D17 says two. Both extra columns are named, justified, and fenced here rather
than discovered in review:**

- **`position`** is a property of *the list*, not of the task. D17 requires "an ordered list… The order
  is the user's, set when the plan is built"; an order has to be stored somewhere, and storing it on the
  item is the only place it can go without a relationship. It is never editable after the plan is built
  (§4.4) and it says nothing about the Todoist object.
- **`kind`** is required by `SPEC.md` itself: *"A pomodoro is attached to exactly one Todoist task (or,
  if no task is chosen, to a project)"*, and D17 describes a plan as *"an ordered list of Todoist tasks
  and projects"*. Todoist ids are opaque strings, so a project id and a task id are indistinguishable,
  and only a task can be closed. Without `kind` the app cannot tell which button to offer. It is a
  `String`-raw-value enum so the store dump in §8 is readable — F5's review was blocked once by a
  raw-value-less `Codable` enum that SwiftData split into marker columns.

`currentIndex` lives on the **plan**, not on the items, and that placement is the load-bearing part: it
means no item ever gains a per-item state, which is where the first forbidden field would go.

### 4.2 How the timer takes the next item

`ZenTomato/Plan/` holds the seam, and it keeps `ZenTomato/Timer/` free of any knowledge of Todoist.

```
// SessionAttachment.swift — a plain immutable value. NOT a @Model.
struct SessionAttachment: Sendable, Equatable {
  let taskID: String?
  let taskTitle: String?
  let projectID: String?
  let projectTitle: String?
}

// SessionAttaching.swift — the engine's read-shaped seam.
@MainActor protocol SessionAttaching: AnyObject {
  /// Advances the plan and returns what the next FOCUS block is attached to,
  /// or nil when there is no plan, or the plan is exhausted.
  func takeNextAttachment() -> SessionAttachment?
}

// SessionPlanStore.swift — @MainActor final class, conforms to SessionAttaching.
```

`TimerEngine` gains one optional collaborator, defaulted so every existing F2 and F5 test construction
still compiles unchanged:

```
init(context:clock:alarms:attachments: (any SessionAttaching)? = nil)
```

At `begin(...)`, and **only for `kind == .work`**, the engine calls `attachments?.takeNextAttachment()`
once and writes the four values onto `TimerState`. Breaks are never attached — a break is not a
pomodoro. `recordSession(...)` then copies the four values from `TimerState` onto the new
`PomodoroSession`. That copy is the whole of F3's change to `TimerEngine.swift`: one stored property,
one call in `begin`, four assignments in `recordSession`.

**Why the engine pulls rather than the screen pushing:** blocks begin without any UI involvement — the
break starts behind the reflection sheet (D4) and `autoStartNextBlock` starts the next pomodoro with
nobody looking. A screen that pushed the attachment would miss both.

**Why `TimerState` and not memory:** §1.3. A block can end while the app is closed, and
`synchronize()` writes its row on the next foreground from `TimerState` alone.

### 4.3 When the world moves underneath the plan

D17: *"The plan is a record of intent, and intent is not invalidated by the world moving."*

- **Resolution is at display time, never stored.** For each item, look for a `CachedTask` (or
  `CachedProject`) with that id. Found ⇒ draw the live title beside the snapshot if they differ.
  Absent ⇒ draw the **snapshot title** and, quietly beneath it, *"No longer in Todoist."*
- **A missing item is still worked.** The pomodoro still attaches to it with the snapshot title. The
  Complete button is disabled with *"This task is no longer in Todoist"* — closing a deleted id is a
  404, and a 404 is not a completion.
- **Stepping over** is one control on the plan row: it increments `SessionPlan.currentIndex` and does
  nothing else. It does not delete the item, does not mark it, and does not reorder the list.
- **Completing a task does not advance the plan** and does not touch the item. The plan advances only
  when the next focus block begins. This is the single most tempting place to add `isDone: Bool`, and
  it is forbidden.
- **"Already done" is derived, never stored.** An item reads as finished when either its id is absent
  from the refreshed cache, or a `CompletedTaskRecord` exists for that id with `completedAt >
  plan.createdAt`. Both are queries. Neither is a column.

### 4.4 Replacing a plan

D17: *"The plan is replaced when a new one is made. It is not history."* Building a new plan deletes
every `SessionPlanItem` and the `SessionPlan` row, then inserts fresh ones. There is no edit, no
reorder-after-the-fact, no append-to-current-plan, and no archive of past plans. What actually happened
is on `PomodoroSession`.

### 4.5 THE FENCE — a checkable list

Every line is a thing a reasonable engineer might add, and every one of them fails the feature. The
reviewers check this list literally.

**On `SessionPlanItem`, these columns must not exist. `wc -l` the properties: there are exactly four.**

- [ ] `content`, `notes`, `description`, `body` — a plan item is a reference, not a copy.
- [ ] `dueDate`, `deadline`, `scheduledFor` — the first field somebody adds "so the plan can sort by urgency".
- [ ] `priority`, `flag`, `importance`.
- [ ] `labels`, `tags`.
- [ ] `parentID`, `childIDs`, `subItems`, `depth`, `indentLevel` — a plan is **flat**, even when it holds a project and tasks from inside that project.
- [ ] `projectID` on a `.task` item — that is hierarchy, wearing a convenience.
- [ ] `sectionID`.
- [ ] `isDone`, `isCompleted`, `completedAt`, `checked`, `state`, `status` — §4.3, derived not stored.
- [ ] `isSkipped`, `wasStepped`, `skippedAt`.
- [ ] `estimatedPomodoros`, `pomodorosSpent`, `actualMinutes` — that is `PomodoroSession`'s job.
- [ ] `note`, `userTitle`, `customTitle`, or any editable field — D17: *"nothing editable"*.
- [ ] `colour`, `icon`, `emoji`.
- [ ] `syncedAt`, `dirty`, `pendingChange`, `localVersion`, `remoteVersion` — D16, explicitly.
- [ ] Any field that is `nil` today and becomes meaningful once sync exists — D17's own test, and the one to apply to anything not on this list.

**Structural prohibitions:**

- [ ] No `@Relationship` anywhere in F3. Not plan→item, not task→section, not section→project. Ids are copied values, as `Distraction.sessionID` already is.
- [ ] No protocol whose name or method suggests writing: no `TodoistWriting`, `TaskRepository`, `TaskStore`, `Syncing`, `Persisting`. `TaskCompletion` is a concrete `final class` with one method and no protocol, on purpose (D16).
- [ ] No method named `create`, `add`, `update`, `edit`, `move`, `comment`, `reorder`, `rename`, `delete` on any Todoist-facing type. `TodoistCacheStore.clear()` and the post-close row removal are local deletes and are named so their scope is obvious.
- [ ] No `outbox`, `pendingChanges`, `queue`, `dirty`, `conflict`, `merge`, `lastWriterWins`, `resolve` in `ZenTomato/Todoist/` or `ZenTomato/Plan/`.
- [ ] The cache is read-only to the app. Nothing outside `TodoistCacheStore.refresh()` and the post-close row removal writes a `Cached*` row. No screen, no test helper in shipping code.
- [ ] `SessionPlanItem` has no methods and no computed properties. It is a row.

**Capture-surface prohibitions:**

- [ ] No `TextField` anywhere in F3 except the credential field, which is a **`SecureField`**.
- [ ] No `+`, no "New", no "Add", no `.toolbar` item, no swipe action, no context menu that creates anything, on any picker or plan screen.
- [ ] An empty project shows exactly *"No tasks in this project."* and offers nothing.
- [ ] A search with no matches shows exactly *"No tasks match that."* and offers nothing. **This is the specific place other apps offer to create what you typed.** No "Add '<query>' to Todoist", not disabled, not greyed, not present.
- [ ] The search field's prompt is *"Search your Todoist tasks"* — a verb that reads, never one that makes.

---

## 5. Completing a task — the only write

`ZenTomato/Todoist/TaskCompletion.swift`, `@MainActor final class TaskCompletion`. Concrete, no protocol.

```
@MainActor func complete(taskID: String, titleSnapshot: String) async -> Outcome
enum Outcome: Equatable { case closed, alreadyGone, offline, tokenRejected, failed }
```

Sequence, and the order is the contract (D11: *"a completion is recorded locally when Todoist confirms
the close — never before"*):

1. `try await client.closeTask(id:)` — **exactly one** `POST /tasks/{id}/close`. No pre-flight GET, no
   verification GET afterwards.
2. On success only: insert `CompletedTaskRecord(taskID:, titleSnapshot:, completedAt:)` and `save()`.
3. On success only: delete the `CachedTask` row with that id (§1.6).
4. On `404` ⇒ `.alreadyGone`: the task was completed or deleted elsewhere. **No local record is
   written** — this app did not do it, and D11's row is a record of what this app did.
5. On any failure the UI returns the button to its uncompleted state with a sentence. Nothing is
   queued, nothing is retried later.

`CompletedTaskRecord` (`ZenTomato/Models/CompletedTaskRecord.swift`) is three columns —
`taskID: String`, `titleSnapshot: String`, `completedAt: Date` — append-only, never updated, never
deleted (not even on sign-out, §1.5: it is this app's own history and F6 exports it offline). No
`projectID`, no hierarchy, nothing that could grow into a task list.

**Where the button lives.** The end-of-block sheet, `ZenTomato/Views/BlockReflectionSheet.swift`,
alongside F5's sentence fields (D4: the sheet is over an already-running break). One button. Optimistic
in the UI, reconciled against the outcome. **Completing does not end the pomodoro and ending does not
complete the task** — they are independent and the sheet is only where both happen to live.

---

## 6. Concurrency posture — Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`

One rule inherited from F1 and unchanged: **a `ModelContext` is not `Sendable`, so everything that
touches SwiftData is `@MainActor`.** F3 adds a second half to that rule: **everything that touches the
network is `nonisolated` and never sees SwiftData.** The seam between them is a `Sendable` value type.

| Type | Isolation | Sees SwiftData | Sees the network |
|---|---|---|---|
| `TodoistAPI` | `nonisolated` (namespace of constants) | no | no |
| `TodoistTransport`, `URLSessionTransport` | `nonisolated`, `Sendable` | no | yes |
| `TodoistClient` | `nonisolated` `struct`, `Sendable` | **no** | yes |
| `TodoistProjectDTO` / `SectionDTO` / `TaskDTO` | `Sendable` `struct`s | no | decoded from it |
| `KeychainTokenStore` | `nonisolated`, `Sendable` (Keychain is thread-safe) | no | no |
| `TodoistCacheStore` | `@MainActor final class` | yes | via the client only |
| `SessionPlanStore` | `@MainActor final class` | yes | no |
| `TaskCompletion` | `@MainActor final class` | yes | via the client only |
| `TimerEngine` | `@MainActor` (unchanged) | yes | **never** |
| every view / screen model | `@MainActor` | reads only | no |

**The crossing, concretely.** `TodoistCacheStore.refresh()` is `@MainActor`. It `await`s the three
client calls — which hop off the main actor for the duration of the I/O because `TodoistClient` is
`nonisolated` — receives three arrays of `Sendable` DTOs, and only then inserts rows. **No `@Model`
instance, no `ModelContext`, and no `PersistentIdentifier` is ever captured in a task that leaves the
main actor.** If a closure needs a task id, it captures the `String`.

Other rules:

- **No `Task { }` in a view's tap handler.** Use `.task { }` / `.refreshable { }`, which SwiftUI cancels
  for you. F5's review found this exact shape and it is a lint-by-eye item here.
- **No detached tasks. No `nonisolated(unsafe)`. No `@preconcurrency import`.**
- **No `URLSession.shared`** — the transport holds its own session, so no test can accidentally reach
  the real one through a global.
- `URLRequest`, `Data` and `HTTPURLResponse` are `Sendable`; that is why the transport seam is shaped
  around them rather than around `URLSession`'s delegate API.

**How tests stub the transport with no network.** `ZenTomatoTests/Support/StubTodoistTransport.swift`:
an `actor` (or a `final class` behind a lock) holding a scripted queue of responses and an array of
recorded `URLRequest`s. Every client test constructs `TodoistClient(transport: stub, tokens:
InMemoryTokenStore(...), waiting: RecordingWaiting())`. The suite passes offline, in CI, and on a
machine with no Todoist account.

---

## 7. Verification, and what counts as evidence

`CLAUDE.md`: assertions are not evidence. The PR carries the command and its output.

```
make ci      # swiftlint --strict, the Todoist allowlist check, gitleaks, the script tests, then the suite
make clean && make generate && make build
```

### The test table — F3.md's, corrected for D18

| Test | Asserts |
|---|---|
| ~~`oauthStateMismatchRejected`~~ | **STRUCK.** There is no OAuth (§0.7). |
| `theOnlyPostEndpointIsClose` | `TodoistAPI.allEndpoints` has exactly 4 entries; exactly one has `.post`; its path is `/tasks/{id}/close`. **The method-to-path binding F3.md asked the shell script for (§0.8).** |
| `endpointTableMirrorsTheAllowlist` | every path in `allEndpoints`, normalised, appears in `scripts/todoist-allowed-endpoints.txt`, and vice versa. Reads the file from the bundle at build time — no hard-coded copy. |
| `tokenGoesToKeychainOnly` | after sign-in, no `UserDefaults` key and no file in the app container contains the token. |
| `tokenNeverAppearsInErrors` | for every `TodoistError` case, the `localizedDescription` and the `String(describing:)` contain no part of the token. |
| `paginationFollowsCursor` | 3 stubbed pages ⇒ all rows, in order, no duplicates, exactly 3 requests, cursor echoed verbatim. |
| `paginationStopsOnNullCursor` | a full page with `next_cursor: null` ⇒ exactly one request. Proves the short-page inference was not used. |
| `paginationRefusesAnEndlessCursor` | a stub returning the same cursor forever ⇒ throws `.paginationDidNotTerminate` inside the page cap. |
| `completeHitsCloseEndpoint` | exactly one recorded request; method `POST`; path ends `/tasks/<id>/close`; **no body**. |
| `noMutatingRequestsOtherThanClose` | a full stubbed session — sign in, refresh, build a plan, run a block, complete — and every recorded request is `GET` except one, which is the close. The runtime companion to the static gate. |
| `unauthorizedClearsToken` | `401` ⇒ Keychain cleared, `.tokenRejected` thrown, **cache and plan rows still present** (§1.5). |
| `rateLimitBacksOff` | `429` + `Retry-After: 3` ⇒ the recording waiter saw `.seconds(3)`, then exactly one retry. **No sleeping.** |
| `rateLimitDoesNotRetryForever` | two consecutive `429`s ⇒ throws after one retry. |
| `offlineServesCacheAndDisablesComplete` | transport throws `.offline` ⇒ picker still lists cached rows; the sheet's Complete is disabled with the plain sentence. |
| `refreshIsAllOrNothing` | tasks fetch fails after projects succeeds ⇒ every pre-existing cached row is unchanged. |
| `refreshReplacesRatherThanMerges` | a row present before and absent from the response is gone afterwards; a duplicated id across pages yields one row. |
| `projectAttachedWhenNoTaskChosen` | a `.project` plan item ⇒ session has `projectID`/`projectTitle`, `taskID == nil`. |
| `titleSnapshotTakenAtAttach` | rename the cached task after attach ⇒ the stored session and the plan item are unchanged. |
| `planItemHasFourStoredProperties` | reflection over `SessionPlanItem` ⇒ exactly `todoistID`, `titleSnapshot`, `kind`, `position`. **The fence, as a test.** |
| `planSurvivesATaskVanishingFromTodoist` | remove the cached task ⇒ the item still resolves to its snapshot title, is still attachable, and Complete is disabled. |
| `completingDoesNotAdvanceThePlan` | close succeeds ⇒ `currentIndex` unchanged. |
| `completionRecordedOnlyAfterTodoistConfirms` | close throws ⇒ zero `CompletedTaskRecord` rows; close succeeds ⇒ exactly one. |
| `alreadyGoneWritesNoRecord` | `404` ⇒ `.alreadyGone`, zero records. |
| `signOutClearsTokenCacheAndPlanButNotHistory` | after sign-out: no token, no `Cached*` rows, no plan rows, and every `CompletedTaskRecord` still present. |
| `breaksAreNeverAttached` | a short break's `PomodoroSession` has four `nil`s and the plan did not advance. |
| `noPlanMeansNoAttachment` | engine built with `attachments: nil` ⇒ existing F2/F5 behaviour, four `nil`s, no crash. |

Two regression checks must be **demonstrated failing** without their fix, and the output pasted:
delete the `kind == .work` guard in `begin` ⇒ `breaksAreNeverAttached` fails; move the
`CompletedTaskRecord` insert above the `await` ⇒ `completionRecordedOnlyAfterTodoistConfirms` fails.

### Two traps in the test bundle that will fail `make ci` if ignored

1. **`ZenTomatoTests/` is scanned by `check-todoist-writes.sh`.** A literal like
   `#expect(request.url?.path == "/api/v1/tasks/6XGgmFVcrG5RRjVr/close")` contains a hard-coded opaque
   id segment, which the script deliberately does **not** normalise — it will be reported as an
   unlisted endpoint, and correctly so. **Build every expected path from `TodoistAPI` constants. Never
   write a Todoist path literal in a test.**
2. **gitleaks scans the tree.** A fixture token must not look like a credential: Todoist personal
   tokens are 40 hex characters and that is exactly what a secret scanner matches. Use the literal
   `"not-a-real-token"`. Never 40 hex characters, in any file, including this contract.

### The device check (F3's real evidence, gated on C4)

Sign in with the real account. Confirm every project appears. Build a plan of a project plus two loose
tasks. Run a pomodoro, complete the current task from the end-of-block sheet, and confirm it is closed
in Todoist proper. Then open **the Todoist activity log for that account and confirm only a completion
appears — no other write of any kind.** A screenshot of that log is the single most important artefact
in the PR.

Then read the store off the phone, as F2 and F5 did:

```
xcrun devicectl device copy from --device <udid> \
  --domain-type appDataContainer --domain-identifier com.martingleason.ZenTomato \
  --source Library/Application\ Support --destination ./pull

sqlite3 -header -column ./pull/default.store \
  "SELECT ZTODOISTID, ZKIND, ZPOSITION, ZTITLESNAPSHOT FROM ZSESSIONPLANITEM ORDER BY ZPOSITION;"
sqlite3 ./pull/default.store ".schema ZSESSIONPLANITEM"     -- four Z-columns, no more
sqlite3 -header -column ./pull/default.store \
  "SELECT datetime(ZCOMPLETEDAT + 978307200,'unixepoch','localtime'), ZTASKID, ZTITLESNAPSHOT
     FROM ZCOMPLETEDTASKRECORD ORDER BY ZCOMPLETEDAT;"
sqlite3 -header -column ./pull/default.store \
  "SELECT ZTASKTITLE, ZPROJECTTITLE, ZWASABANDONED FROM ZPOMODOROSESSION ORDER BY ZSTARTEDAT;"
```

`+ 978307200` is not optional — Core Data stores dates as seconds since 2001, and without it every
timestamp reads as 1970 and the evidence looks broken. `ZKIND` works here because `PlanItemKind` has a
`String` raw value (§4.1); this is the query F5's review could not run.

---

## 8. The A/B seam

Two engineers, one tree, one branch, in parallel. The two ownership lists are **strictly disjoint**.
Nobody edits a file they do not own — not to fix a typo, not to add an import.

**Where the seam falls, and why there.** Not "model versus UI". It falls between **the wire and the
plan**, because that is where the two hostile questions separate:

- **Engineer A answers "does this app ever write to Todoist except one close, and is the token safe?"**
  A owns every byte that leaves the device, the credential, the mirror, and every stored row.
- **Engineer B answers "is there a local task model, and is there a capture surface?"** B owns the
  plan's behaviour, the engine seam and every screen a person touches.

Each half is one reviewer's lens end to end, with no overlap in either direction. A cannot ship a
capture surface (A writes no view). B cannot ship a second Todoist request (B writes no `URLRequest`).

**The first commit is a coordination protocol, not a task.** Engineer A's first commit contains, and
contains only:

- `TodoistAPI.swift` complete, including the pinned comment — B needs the endpoint constants to compile
  and nobody may retype a path;
- every `@Model` file, complete, exactly as declared in §3.1, §4.1 and §5 — they are pure declarations
  and staging them would guarantee a merge conflict;
- the one-line `Schema([...])` change in `AppModelContainer.swift` adding all six new models;
- `SessionAttachment.swift` and `SessionAttaching.swift` complete;
- the `attachments:` parameter on `TimerEngine.init` and the `kind == .work` call in `begin`, with the
  four assignments in `recordSession` — so B's engine work starts from a compiling seam;
- stub bodies for `TodoistClient`, `TodoistCacheStore` and `TaskCompletion` that return fixed values
  and do nothing. **No `fatalError`, no `TODO`.**

Pushed before A writes any logic. B does not start until it lands, and from then on B compiles against
it. Suggested message:

```
feat(F3-T2): the seam — the endpoint table, the six stored rows, and the attachment protocol
```

Everything A implements afterwards fills those bodies in without changing a signature. **If a signature
turns out to be wrong, A does not change it unilaterally: A says so, both engineers agree, and it
changes in one commit that names the reason.**

**Files neither engineer may touch, for any reason:**
`ZenTomato/Models/AppSettings.swift` · `ZenTomato/Distraction/DistractionTally.swift` ·
`scripts/check-todoist-writes.sh` · `scripts/check-secrets.sh` · `scripts/check-lint.sh` ·
`scripts/tests/**` · `.githooks/**` · `.github/**` · `Config/**` · `docs/specs/SPEC.md` ·
`docs/plans/00-deltas.md` · `project.yml` (F3 adds no target and no Info.plist key — no
`CFBundleURLTypes`, no new entitlement) · `ZenTomatoActivity/**` · `ZenTomato/DesignSystem/**` (F3
introduces no new token; every new view names existing semantic roles only).

Zero changed lines in each. `git diff main -- <path>` in the PR proves it.

---

## 9. Scope fence

The greppable list is in the structured response and the reviewers search it. Five clarifications a
literal grep cannot express:

- **"The only write is close"** means every `URLRequest` in the tree is built by one private function in
  `TodoistClient.swift`, its method comes from a four-valued closed table, and exactly one of those four
  is a `POST`. No body is ever set. No endpoint is ever assembled from a variable. `POST /tasks` is not
  "not called" — it *cannot be named*, because `Endpoint`'s initialiser is private and `TodoistAPI` has
  no fifth constant.
- **"No capture surface"** means no field anywhere accepts a task. F3 adds exactly one text input to the
  app and it is a `SecureField` for a credential, masked, labelled *"Todoist API token"*, sitting under
  the exact path *Todoist → Settings → Integrations → Developer → API token* and above the sentence
  *"ZenTomato never creates or changes tasks."* A masked field cannot be mistaken for task entry, which
  is the point of choosing one.
- **"The cache mirrors, the plan references, neither invents"** means §3.1's table and §4.5's fence are
  the whole of the local shape. Every column is either a verbatim v1 field or is named and defended in
  this document. There is no third category.
- **"F3 only"** means no MusicKit, no stats screen, no export, no share sheet, no watch, no
  `WCSession`, no widget beyond the one F2 shipped, no theme, no streak. Not a stub, not a `TODO`, not a
  file named for one.
- **"No preparation for bi-directional sync" (D16)** means the absence of machinery, not the presence of
  a comment promising restraint. No outbox, no dirty flag, no conflict policy, no write-shaped protocol,
  no `syncedAt` read by anything but the freshness line.

---

## 10. Risks, most likely first

1. **A new `@Model` is left out of `AppModelContainer`'s `Schema`.** Six types are being added at once.
   Every insert traps at runtime, in the app and in every test, with an error naming SwiftData rather
   than the missing line. It is one line in a file neither engineer would otherwise open. **It is in the
   seam commit, first, and it lists all six.** This was F5's number-one risk too.

2. **`SessionPlanItem` grows a fifth column.** Not by malice — by a reasonable afternoon. "The plan
   should show which ones are done." "Sort by due date." "Grey out the finished ones." Each is one
   commit and each is the local task model D16 and `CLAUDE.md` forbid. §4.5 is the checklist,
   `planItemHasFourStoredProperties` is the test, and §4.3 gives the derived answer to the two most
   likely requests.

3. **A test writes a Todoist path literal and fails `check-todoist-writes.sh` at the last minute.**
   §7's trap 1. It will look like the gate is broken; the gate is right. Build expected paths from
   `TodoistAPI`.

4. **The token reaches a log or an error.** The most likely route is not a `print` — it is
   `URLError`'s or a decoding error's default description carrying the failing `URL`, or an engineer
   adding the request to an error case "for debugging". §2.6 makes every case tokenless by construction
   and `tokenNeverAppearsInErrors` checks it. A second route: SwiftUI's `SecureField` bound to a
   `@State String` that survives in a preview snapshot. Clear the state on submit.

5. **`GET /projects` returns a polymorphic body.** The schema is `PaginatedList_AnyProjectSyncViewResponse_`
   — a union of `PersonalProjectSyncView` and `WorkspaceProjectSyncView`. Both carry `id`, `name` and
   `child_order`, which is all §3.1 mirrors, so a struct decoding only those three works for both. A
   DTO that demanded a personal-only field would fail on any account with a workspace. Do not add
   fields to the project DTO.

6. **The engine seam ripples further than four assignments.** `TimerEngine.swift` is 978 lines and F2's
   file. F3's change is: one `init` parameter, one stored `let`, one call in `begin`, four assignments
   in `recordSession`. If the diff to that file exceeds roughly a dozen lines, stop — the plan logic has
   started leaking into the timer, and the timer must not know Todoist exists.

7. **`limit=200` and a large account.** A 5,000-task account is 25 pages of tasks on every foreground.
   That is fine for the rate ceiling but it is also 5,000 SwiftData deletes and 5,000 inserts on the
   main actor inside a full replace. If the refresh visibly stalls the UI, the fix is to batch the
   delete (`context.delete(model:where:)`) and insert without an autosave between rows — **not** to
   switch to a merge, and **not** to filter server-side, because `SPEC.md` requires everything to be
   visible.

8. **The search box offers to create what you typed.** Not because anyone decides to, but because
   `ContentUnavailableView.search` and every SwiftUI tutorial put an action there. §4.5's capture list
   and the screenshot in the PR are the defence.

9. **Someone "fixes" the shell hook.** §0.8 explains why it is untouched and what is proposed instead.
   A diff to `scripts/check-todoist-writes.sh` in this branch fails review on the fence, however good
   the change is.

10. **`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is silently downgraded.** The default accessibility
    is `WhenUnlocked` (iCloud-syncable), and `SecItemAdd` succeeds either way — nothing fails, nothing
    warns. D18 names this attribute specifically. A test reads the item's attributes back and asserts
    the constant.

11. **The 429 retry becomes a loop.** One retry, capped at 60 s, and `rateLimitDoesNotRetryForever`
    locks it. An unbounded backoff in a `@MainActor` refresh is a hang, not a courtesy.

12. **The device check does not happen.** It is outstanding on F2 and F5 already. For F3 it is the
    feature's whole point: the Todoist activity-log screenshot is the only evidence that the
    non-negotiable holds against a real account, and no test in this bundle can produce it. Do not open
    the PR claiming this feature is done without it.

-----
August 23, 2026

#AI/Claude
