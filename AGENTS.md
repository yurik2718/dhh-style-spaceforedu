# Homologation App

Rails 8 application for international students seeking document-equivalence (homologación) recognition in Spain. Students submit requests, upload documents, and chat with a super admin who shepherds the case through Spanish bureaucracy.

- `spaceforedu.com` — marketing/landing site (separate repo)
- `app.spaceforedu.com` — this Rails app

## Git rules for AI agents

**Never run `git commit`. Only the human owner commits.** Edit files, run `git status` / `git diff` / `git log`, and `git add` only when explicitly asked. Leave finished work in the working tree and report the diff.

## TDD — IRON RULE

**NOT A SINGLE LINE OF CODE WITHOUT QUALITY TESTS FIRST. NON-NEGOTIABLE.**

Every behavior change goes through Red → Green → Refactor. There is no other way to write code in this project.

**The cycle, every time:**

1. **Red** — write one minimal test that describes the desired contract. Run it. It must fail. Show the failing test to the user before writing any implementation.
2. **Green** — write the simplest implementation that turns that one test green. No extra code. No anticipation of the next test. No "while I'm here" cleanups.
3. **Refactor** — clean up with the green test bar held throughout. Run tests after every change. If nothing needs cleaning, skip this step.

**Hard rules — these are violations of doctrine:**

- **No implementation without a failing test in front of it.** Writing the model method first and then "adding tests to cover it" is test-after, not TDD. It is forbidden.
- **One test per iteration.** Never write 5 tests up front and then 5 implementations. Red → Green → Refactor → next test. The discipline only works one cycle at a time.
- **Tests describe observable behavior, not implementation details.** A test that asserts "after `confirm_payment!`, `pipeline_stage` equals `pago_recibido`" is a contract. A test that asserts "the YAML hash has 8 keys" is internal trivia. Write the first kind, never the second.
- **Tests must be high-quality, not just present.** A test is high-quality when: (a) it would fail if the behavior broke, (b) its name describes the behavior in plain language, (c) the arrange/act/assert structure is obvious at a glance, (d) it does not duplicate another test's coverage. A test that passes regardless of the implementation is not a test — it is theatre. Delete it.
- **Minimum viable implementation in the Green step.** If the test says "advance from `documentos` returns `traduccion`", `def advance = "traduccion"` is correct on that step. Generalization comes from the next test, not from imagined needs.
- **Bug fix = failing test first.** Reproduce the bug as a red test, then fix. A bug fix without a regression test is not done.
- **Refactor never changes behavior.** If you need to change behavior, that's a new Red test. The same suite must pass before and after refactoring, byte-for-byte.
- **Do not skip TDD because something is "trivial".** Renames are trivial; getters are trivial; constants are trivial. The discipline is the point. Slipping on small things is how the dam breaks.

**Pause points — agent must stop and show the user:**

- After Red: show the failing test and its output, *before* writing implementation.
- After Green: show the diff and the green test run.
- After Refactor: show the diff and the green test run.

The user approves each step. The agent does not chain Red → Green → next Red without the user seeing the green in between.

**Coverage requirements:**

- Every model method that changes state — model test.
- Every controller action — controller test (status, redirect/render, side effects).
- Every Pundit policy method — policy test.
- Every Turbo Stream broadcast — system test that watches the DOM update.
- Every background job — job test that asserts the work was performed.

If a piece of behavior cannot be tested, that is a design problem — fix the design, not the test.

## MVP Scope

Ship and validate the core homologation flow with real students before adding anything else.

**The flow, in order:**

1. Student registers, completes profile, accepts privacy policy
2. Student creates a `HomologationRequest`, fills in details, uploads documents
3. Super admin reviews, changes status, leaves internal notes
4. Student and admin exchange messages in the request's conversation
5. Admin records a Stripe invoice; student pays; admin confirms payment

**Hard rules until step 5 works end-to-end with real users:**

- No new models, tables, or domain concepts without explicit instruction
- No third-party integrations beyond Stripe and Telegram (no OAuth, analytics, S3)
- No Redis, no Sidekiq — Solid Queue is the only background system
- A thin slice that works beats a wide surface that doesn't

**Roles:** `super_admin`, `staff`, `student`. `staff` was added deliberately post-MVP (2026-07) so the business owner can delegate case handling without being the only person who can work a case — see the Roles section below for the exact permission split. Don't add a *fourth* role without explicit instruction; the same "thin slice" discipline applies here as everywhere else.

**Out of scope:** teachers, coordinators, lessons, study plans, multi-tenancy, organizations, public API, mobile app.

## Tech Stack

- **Rails 8.1** — full-stack, server-rendered (no API mode, no React, no Inertia)
- **Hotwire** — Turbo Drive + Frames + Streams + Stimulus
- **Tailwind CSS 4 + Daisy UI 5** — UI built from Daisy component classes (a deliberate choice on top of omakase Tailwind)
- **Propshaft** + **import maps** — no Sprockets, no webpack/Vite/esbuild
- **SQLite** — primary database; **Solid Queue** (jobs), **Solid Cable** (broadcasts), **Solid Cache** (cache); no Redis
- **Litestream** — continuous SQLite replication to off-box storage; the only backup mechanism. A single-node Docker host means a lost disk is a lost app — the replica is the recovery story.
- **Active Storage** — uploads on local disk, served through controllers
- **Authentication** — Rails 8 `bin/rails generate authentication` (no Devise, no OAuth)
- **Authorization** — Pundit, three roles: `super_admin`, `staff`, `student`
- **Pagination** — Pagy
- **Payments** — Stripe (`stripe` gem; admin records invoices, student pays, signed webhook confirms)
- **Notifications** — in-app Turbo Streams + email (Action Mailer; SMTP in production, `letter_opener` in development) + Telegram Bot API (raw HTTP)
- **i18n** — `es` (default), `en`, `ru`; translation keys in English; `rails-i18n` for locale data
- **Secrets** — Rails encrypted credentials (`config/credentials/<env>.yml.enc`), keyed per environment. No secrets in ENV in dev or prod beyond `RAILS_MASTER_KEY`.
- **Deployment** — Kamal + Thruster, single-node Docker
- **Safety nets** — `strong_migrations` (block dangerous migrations), `rack-attack` (auth + webhook rate limits), `bullet` (dev N+1), `bundler-audit` + `brakeman` (CI)
- **Testing** — Minitest + Capybara + Selenium + Rails fixtures + `webmock` for Stripe/Telegram

## Commands

```bash
bin/setup    # install gems, create DB, migrate, seed
bin/dev      # Puma + Tailwind watcher + hotwire-spark hot reload
bin/ci       # rubocop → bundler-audit → importmap audit → brakeman → tests → system tests
```

Run `bin/ci` before every commit. CI is wired through `config/ci.rb` (`ActiveSupport::ContinuousIntegration`).

```bash
bin/rails test test/path/file_test.rb
bin/rails test:system
bin/rails db:migrate
bin/rails db:seed         # creates super_admin admin@example.com (see db/seeds.rb)
bin/rails db:reset
```

Outbound mail in development opens in the browser via `letter_opener`.

## Architecture

### Authentication

Rails 8 built-in auth generator. Tables: `users`, `sessions`. `has_secure_password` on `User`. Login uses `email_address` (not `email`). Password reset via Action Mailer + signed token.

### Current attributes

`Current.session` is set per request by the `Authentication` concern; `Current.user` is delegated through it. Reach for `Current.user` in models that genuinely need actor context (audit columns, broadcasts). Don't pass `current_user` through five layers of method signatures.

### Roles

Single `role` string column on `users`, enforced by a DB check constraint.

| Role          | Root path             | Purpose                                                                 |
|---------------|------------------------|--------------------------------------------------------------------------|
| `super_admin` | `/admin/pipeline`      | Everything `staff` can, plus: confirms payments, moves the kanban, invites staff |
| `staff`       | `/admin/pipeline`      | Case handling — reviews requests, chats, changes status, requests documents, reads the pipeline (view-only). Delegated by `super_admin` via `Admin::StaffMembersController`. |
| `student`     | `/requests`            | Submits requests, uploads documents, chats with admin                    |

`authorize @record` in every controller action. `policy_scope` in every index. Prefer `user&.case_staff?` (super_admin or staff) over checking `super_admin?` directly — most views/policies want "is this a case handler," not "is this specifically the owner." Use `manage_pipeline?` (super_admin-only) instead of `manage_case?` only for payment confirmation and kanban movement — everything else case-related is `manage_case?`. No role checks in views beyond that — call `policy(@record).action?`.

`User.case_staff` returns every kept `super_admin` + `staff` user — the fan-out target for case-handling notifications (new submission, new chat message, stale-case digest). `User.super_admin` stays a singleton (first super_admin) and is reserved for owner-only concerns: Stripe payment notifications and the production error-report fallback address. Don't route financial or system-ops notifications through `case_staff` — that boundary is deliberate, matching what `staff` is and isn't authorized to act on.

### Domain models

**User** — all roles in one table.
- `role` enforced by check constraint (`super_admin`, `staff`, or `student`)
- `discarded_at` for soft delete (always query through `.kept`)
- Encrypted PII (Active Record encryption): `phone`, `whatsapp`, `guardian_phone`, `guardian_whatsapp`
- Minor support: `is_minor`, `guardian_name`, `guardian_email`
- Telegram opt-in: `telegram_chat_id`, `telegram_link_token`, `notification_telegram`
- GDPR: `deletion_requested_at` flags a pending erasure; the row is kept, PII is nullified or re-encrypted, `discarded_at` is set.

**HomologationRequest** — core model. Two parallel lifecycles:

1. **Status** (visible to student) — request lifecycle:
   ```
   draft → submitted → in_review ⇄ awaiting_reply → awaiting_payment
          → payment_confirmed → in_progress → resolved | closed
   ```
2. **Pipeline** (viewable by `case_staff?`, moved by `super_admin` only) — physical processing of documents *after payment*. See `### Pipeline` below.

The DB check constraint enforces the *set* of valid statuses. The model's `transition_to!(new_status, changed_by:)` is the only sanctioned write path for `status`. Never `update(status: ...)` directly. Today the method validates the set; transition edges are policed by callers — when reverse edges become a real concern, the edge map moves into `transition_to!`. Audit columns `status_changed_by` / `status_changed_at` are written by the same method; `payment_confirmed_by` / `payment_confirmed_at` are written by `confirm_payment!`.

`confirm_payment!(confirmed_by:)` does three things atomically: sets payment audit columns, transitions status to `payment_confirmed`, and seeds `pipeline_stage` with `PipelineFlow::STARTING_STAGE` ("pago_recibido"). Pipeline never starts without a confirmed payment.

Soft delete via `discarded_at`. Always query through `.kept`.

Three Active Storage attachments:
- `application_file` — `has_one_attached`, the official application PDF
- `originals` — `has_many_attached`, original certificates/diplomas
- `documents` — `has_many_attached`, supporting paperwork

`document_checklist` is a JSON column (text + `serialize :document_checklist, coder: JSON`) — boolean flags keyed by short codes from `config/pipeline.yml#checklist_keys`. View access through `request.checklist_done?(key)`, never `dig` from a template.

**Conversation** — one per `HomologationRequest`. `last_message_at` for ordering. `student_last_read_at` and `admin_last_read_at` columns drive unread counts (no join table).

**Message** — `belongs_to :conversation`, `belongs_to :user`, `has_many_attached :attachments`. Broadcasts via `after_create_commit`.

**Notification** — in-app, polymorphic on `notifiable` (`notifiable_type` / `notifiable_id`; today: `HomologationRequest`, `Message`). Broadcasts via Turbo Streams on create. Delivered async to email and Telegram via `NotificationDeliveryJob`. `read_at` and `emailed_at` track delivery.

### Pipeline

Pipeline is the case handlers' **physical processing workflow** over a request *after payment is confirmed*. It is **not** `status` — `status` is the request's visible lifecycle to the student; `pipeline_stage` is the internal map of where the paperwork is. `staff` sees the kanban and stage of every request but cannot move it or confirm payment — that stays `super_admin`-only (see Roles above).

Stages live in `config/pipeline.yml`, grouped by `display`:

| `display: kanban` (linear path) | `display: horizontal` (final group) |
|---|---|
| `pago_recibido` → `documentos` → `traduccion` → `tasas_volantes` → `redsara` | `cotejo_ministerio` / `cotejo_delegacion` → `completado` |

After `redsara` the path branches by `user.country`: countries listed in `config/pipeline.yml#cotejo.ministerio_countries` go to `cotejo_ministerio`; everyone else routes to `cotejo.default` (`cotejo_delegacion`). Both cotejo branches converge on `completado`.

`PipelineFlow` is the single source of truth for stage traversal. It reads `config/pipeline.yml` once per process (`PipelineFlow.reload!` for tests) and exposes:
- `next_stage(current, country:)` / `previous_stage(current, country:)` — branching is hidden from callers
- `kanban_stages` / `horizontal_stages` / `all_stages` — derived from YAML, not hard-coded in views or controllers
- `cotejo_for(country)` — branch resolver

Two write methods on `HomologationRequest`, both stamping `pipeline_changed_at` / `pipeline_changed_by`:
- `advance_pipeline!(changed_by:)` — moves to the next stage; raises `InvalidTransition` past `completado`. Bound to the `→` button on the kanban card.
- `retreat_pipeline!(changed_by:, reason:)` — moves back one stage. **`reason` is required** (`ArgumentError` on blank). The retreat is appended to `pipeline_notes` as `[ts] email old_stage → new_stage: reason` so the audit trail is permanent. Bound to a separate "↩ откат" button that opens a form requiring the reason — never a one-click action.

Each pipeline transition is its own resource:
```ruby
namespace :admin do
  resource :pipeline, only: :show
  resources :homologation_requests, only: [], module: :homologation_requests do
    resource :pipeline_advance, only: :create
    resource :pipeline_retreat, only: :create
  end
end
```

Drag-and-drop is deliberately not implemented. If kanban-buttons stop being enough after real usage, drag is added as a second iteration: explicit edge map in `advance_pipeline!`, server-side validation of the drop, optimistic UI rollback on error, system test with real `drag_to`.

Authorization: `PipelinePolicy#show?` (viewing the kanban) is `case_staff?` — `super_admin` or `staff`. `HomologationRequestPolicy#manage_pipeline?` (advancing/retreating a stage, confirming payment) is `super_admin?` only. Index controller uses `policy_scope` so `verify_policy_scoped` is satisfied.

### Real-time

No polling. No custom WebSocket code. Turbo Streams + Action Cable + Solid Cable.

```erb
<%= turbo_stream_from @conversation %>
<div id="messages"><%= render @messages %></div>
```

```ruby
class Message < ApplicationRecord
  after_create_commit -> { broadcast_append_to conversation }
end
```

### Background jobs

```
NotificationDeliveryJob   # email + Telegram fan-out
```

Solid Queue runs in-process; surfaced via Mission Control in production.

### File uploads

Local disk via Active Storage. All downloads go through a controller that calls `authorize` before serving the blob. Never expose `rails_blob_url` or `rails_blob_path` to authenticated users — those URLs leak access.

### Stripe

The `stripe` gem talks to Stripe directly. The webhook endpoint verifies the signature with `Stripe::Webhook.construct_event` against the secret in credentials; an unsigned, malformed, or replayed payload is dropped before any database write. Webhook handlers are idempotent — keyed on the event id — so retries are safe. `webmock` stubs Stripe in tests; the network is never hit.

### i18n

Locale priority: `current_user.locale` → `Accept-Language` → `:es`. All visible text via `t()`, all dates via `l()`. Translation keys are in English.

```ruby
redirect_to @request, notice: t("flash.request_submitted")
l @request.created_at, format: :long
```

### Deployment

Kamal deploys a single Docker image. Thruster fronts Puma for asset caching, compression, and X-Sendfile. SQLite, Solid Queue, Solid Cable, Solid Cache, and Active Storage all live on the same disk. Litestream replicates the SQLite files continuously off-box; the replica is the disaster-recovery story.

## Coding Patterns

### ERB + Daisy UI

Daisy classes directly in ERB. Extract a partial when something repeats — no view components, no presenters, no decorators. Logic belongs in models and controllers; views read like the page they render.

Helpers are reserved for view-only formatting that takes a value and returns a string (an icon name, a date band). Anything that needs the database, the current user, or a method chain longer than two stops belongs on the model. View-only data *about* a record (the CSS class for a status, a humanized label) lives on the model so views stay declarative.

### UI Guidelines — visual system

The DaisyUI theme is **`corporate`** (set in `app/views/layouts/application.html.erb` via `data-theme`). Clean blue primary, sharp `0.25rem` radii, no default shadows. The look is "official document service" — banking/government-adjacent, not playful.

**Hierarchy.** One H1 per page (`text-2xl font-bold`). One subtitle level — `text-sm uppercase tracking-wide opacity-60`. Never mix three weights/sizes for headings on the same screen. If you want emphasis, use color (`text-primary`, `text-error`), not another size.

**Cards.** `bg-base-100 border border-base-300`. **No shadows.** If everything has shadow, shadow conveys nothing. Use `card` for the container; `card-body` for padding. Don't reach for `card-title` — write a normal `<header>` with `text-sm uppercase` label so cards stay consistent.

**Borders, not shadows.** Separation between elements is a `border` (1px), `divide-y`, or `divide-x`. Reserve shadow for ephemeral overlays only (modals, dropdowns).

**Spacing scale (memorize this).**
- Page sections: `gap-6`
- Within a card section: `space-y-3`
- Form fields in a row: `gap-2`
- Inline meta (badge + label): `gap-3`
- Between rows in a list: `divide-y` (no `gap`)

**Density.** Admin pages favor density. Use `btn-sm`, `select-sm`, `input-sm` by default. `btn` (default size) only for primary page actions. No `btn-lg` outside marketing.

**Color tokens.** Use DaisyUI semantic tokens only: `bg-base-100`/`200`/`300`, `text-base-content`, `border-base-300`, `primary`/`success`/`warning`/`error`/`info`. **Never** raw Tailwind colors like `bg-blue-500`, `text-gray-700`, `border-slate-200`. For muted text use `opacity-60`, never two opacities stacked (parent `opacity-70` + child `opacity-60` compounds to 0.42 — invisible).

**One accent per card.** If status is `success`, the badge is `badge-success` — buttons stay `btn-primary` or `btn-ghost`. Don't paint three semantic colors in one card.

**Badges.** `badge` (default size) for counts and inline labels. `badge-lg` only for the **primary status indicator** of a page or card — one per card max. `badge-sm` only for tight inline counts inside dense lists.

**Buttons.** `btn-primary` for the **one** main action. `btn` (no modifier) for secondary. `btn-ghost btn-sm` for tertiary nav-like actions. Destructive — `btn-error` (only on confirmed destructive operations, never on "Cancel"). Never `btn-success` for "Save" — primary is for save.

**Icons.** Heroicons inline-SVG, `h-4 w-4` or `h-5 w-5`. Stroke width `1.5` or `2`, never mixed within a page. Don't add icons to text buttons unless the icon clarifies the action (▶ "Advance" is OK; 💾 "Save" is noise).

**Hover and transitions.** `hover:bg-base-200 transition` on rows; `hover:border-primary` on selectable cards. **Don't** add hover to non-interactive surfaces — hover on a static card lies about affordance. Transitions are `transition` (~150ms), no longer.

**Forms.**
- `input input-bordered`, `select select-bordered`, `textarea textarea-bordered` — always with `-bordered`.
- Use Tailwind `flex gap-2 items-end` for input + submit, never DaisyUI `join` (it stretches all children to max height, breaking buttons next to textareas).
- Validation errors: `text-error text-sm` under the field.

**Layout.**
- Page-level layout uses Tailwind utilities (`grid`, `flex`, `gap-*`).
- DaisyUI layout helpers (`hero`, `drawer`, `join`) are forbidden in app pages — they constrain composition for marketing patterns we don't have.
- **Heights**: avoid `h-[calc(100vh-...)]`. Use the flex chain `html.h-full → body.flex flex-col → main.flex-1 min-h-0 → container.h-full flex flex-col` and let children take `flex-1`.

**DaisyUI components — the safe set.**
Use freely: `btn`, `badge`, `card`, `input`, `select`, `textarea`, `checkbox`, `progress`, `avatar`, `modal`, `divider`, `dropdown`, `menu`, `navbar`, `stats`, `table`.
**Avoid (fragile in DaisyUI 5):** `tabs` (broken with radio inputs in some configs — prefer stacked sections), `chat` (inflexible — wrap in plain Tailwind for our chat needs), `join` (kills cross-axis sizing), `hero`, `drawer`.

**When in doubt, simplify.**
- Remove a card border before adding one.
- Remove a heading level before adding one.
- Remove an icon before adding one.
- Two visible-state indicators on the same row = one too many. Pick one.

**Page header:**
```erb
<%= render "shared/page_header", title: t("nav.requests") %>
```

**Card:**
```erb
<div class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <header class="flex items-center justify-between">
      <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60"><%= t("requests.sections.summary") %></h3>
      <span class="badge <%= @request.status_badge_class %>"><%= t("requests.status.#{@request.status}") %></span>
    </header>
    <p class="mt-2 text-base-content/70 text-sm"><%= l @request.created_at, format: :short %></p>
    <div class="card-actions justify-end mt-3">
      <%= link_to t("actions.view"), @request, class: "btn btn-primary btn-sm" %>
    </div>
  </div>
</div>
```

**Table:**
```erb
<div class="overflow-x-auto rounded-box border border-base-300">
  <table class="table">
    <thead>
      <tr>
        <th><%= t("requests.subject") %></th>
        <th><%= t("requests.status_label") %></th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <%= render @requests %>
    </tbody>
  </table>
</div>
```

**Status badge** — CSS class lives on the model:
```erb
<span class="badge <%= @request.status_badge_class %>">
  <%= t("requests.status.#{@request.status}") %>
</span>
```

### Forms

Standard `form_with`. Server-side validation. On failure: `render :new, status: :unprocessable_entity`.

```erb
<%= form_with model: @request do |f| %>
  <%= f.text_field :subject, class: "input input-bordered w-full" %>
  <%= f.submit t("actions.save"), class: "btn btn-primary" %>
<% end %>
```

### Mutations

`button_to` for state changes. Never `fetch()`, never `axios`.

```erb
<%= button_to t("actions.submit"), submit_request_path(@request),
      method: :patch, class: "btn btn-primary" %>
```

### Turbo frames

Always use `dom_id` for frame ids — never hand-roll strings.

```erb
<%= turbo_frame_tag dom_id(@request, :status) do %>
  <span class="badge"><%= t("requests.status.#{@request.status}") %></span>
<% end %>
```

### Turbo stream responses

```ruby
def create
  @message = @conversation.messages.create!(message_params)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to @conversation }
  end
end
```

### Turbo morphing

In the application layout:

```erb
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

### CRUD routing

When an action doesn't map to CRUD, introduce a new resource — not a custom action.

```ruby
# Bad
resources :requests do
  post :confirm_payment
  post :archive
end

# Good
resources :requests do
  resource :payment_confirmation, only: %i[create]
  resource :archival,             only: %i[create destroy]
end
```

### Controllers

Thin. Pundit on every action. `.kept` on every query. Pagy on every index that can grow.

```ruby
def show
  @request = HomologationRequest.kept.find(params[:id])
  authorize @request
end

def index
  scope = policy_scope(HomologationRequest).kept.includes(:user).order(updated_at: :desc)
  @pagy, @requests = pagy(scope)
end
```

### DB constraints

Rails validations can be bypassed. DB constraints cannot. Every migration ships with the right `null:`, indexes, foreign keys, and check constraints. `strong_migrations` blocks anything dangerous in CI.

```ruby
add_column :users, :email_address, :string, null: false
add_index  :users, :email_address, unique: true
add_foreign_key :homologation_requests, :users
add_check_constraint :homologation_requests,
  "status IN ('draft','submitted','in_review','awaiting_reply','awaiting_payment','payment_confirmed','in_progress','resolved','closed')",
  name: "valid_status"
```

### Soft delete

```ruby
scope :kept, -> { where(discarded_at: nil) }
```

Never hard-delete records that have downstream history (users, requests, messages, payments). GDPR deletion = nullify or re-encrypt PII, set `discarded_at`, keep the row.

### Rate limiting

`Rack::Attack` throttles login, password reset, registration, and the Stripe webhook endpoint. Rules live in `config/initializers/rack_attack.rb`. Every new authentication-adjacent endpoint gets a throttle.

## Code Style

### Invocation order

Order private methods top-to-bottom by how they are called.

```ruby
def submit!
  validate_documents
  transition_to_submitted
end

private
  def validate_documents; end
  def transition_to_submitted; end
```

### Visibility modifiers

No newline under `private`. Indent methods beneath it.

```ruby
private
  def normalize_phone(number)
    number.gsub(/\D/, "")
  end
```

Exception: modules where everything is private — `private` at top, blank line, no indent.

```ruby
module User::Notifications
  private

  def notify_by_email(message) = ...
  def notify_by_telegram(message) = ...
end
```

### Bang methods

Use `!` only when (a) a non-bang counterpart exists, or (b) the method is a stricter version of a Rails idiom that follows the convention itself (`update!`, `save!`, `find_by!`). Don't decorate methods with `!` for emphasis.

### Concerns

Break large models into concerns under `app/models/<model>/`. One concern, one behavior — `HomologationRequest::StatusNotifications`, not `HomologationRequest::Helpers`. Wire them in with `include` at the top of the model.

### Async jobs

Jobs are shallow and delegate to the model. `_later` enqueues, `_now` runs synchronously.

```ruby
module HomologationRequest::StatusNotifications
  extend ActiveSupport::Concern

  included do
    after_update_commit :deliver_status_notification_later, if: :status_previously_changed?
  end

  def deliver_status_notification_later = NotificationDeliveryJob.perform_later(self)

  def deliver_status_notification_now
    NotificationMailer.status_changed(self).deliver_now
    TelegramNotifier.notify(self) if user.notification_telegram?
  end
end

class NotificationDeliveryJob < ApplicationJob
  def perform(request) = request.deliver_status_notification_now
end
```

## Testing

The TDD discipline is defined at the top of this document under **TDD — IRON RULE**. That section is the contract; what follows here is the toolchain.

Concrete patterns, conventions, and common pitfalls are documented in **[`doc/testing.md`](doc/testing.md)**. Read it before writing any test involving file uploads, ActiveStorage, or Turbo Stream responses.

- Minitest for unit, controller, integration, and mailer tests
- Capybara + Selenium for system tests covering the 5 MVP flow steps
- Rails fixtures (YAML) — no FactoryBot, no Faker
- `webmock` stubs Stripe and Telegram in tests; never hit the network
- Tests run in parallel by default; fixtures are written to be parallel-safe
- `bin/rails test` for unit/controller; `bin/rails test:system` for system; `bin/ci` runs everything

## Banned

- **Writing implementation code without a failing test in front of it** — see TDD — IRON RULE at the top
- **Test-after** (writing tests for code that already exists) — that is not TDD, it is theatre
- **Skipping the user-visible Red → Green → Refactor pause points** — the agent must show the failing test, then the green diff, then the refactor (if any), waiting for user acknowledgment between phases
- `fetch()` / `axios` — use Turbo + `button_to` / `form_with`
- `render json:` outside the Stripe webhook controller — no API mode; respond with HTML or `turbo_stream`
- `window.location` — use `redirect_to` or Turbo
- Hardcoded strings in views — use `t()`
- Hardcoded URLs in views — use route helpers (`@request`, `request_path`)
- Role checks in views without Pundit — use `policy(@record).action?`
- Skipping `authorize` or `policy_scope` in any controller action
- ViewComponent / Phlex — use ERB partials
- Service objects, presenters, decorators, query objects, form objects — put it on the model
- FactoryBot / Faker — use Rails fixtures
- `update_column` / `update_columns` / `update_all` / `delete_all` — bypasses callbacks, validations, and soft delete
- Hard-deleting `User`, `HomologationRequest`, `Message`, or payment rows
- Writing `status` directly — go through `transition_to!`
- Writing `pipeline_stage` directly — go through `advance_pipeline!` / `retreat_pipeline!`. `confirm_payment!` is the only other writer (it seeds the pipeline)
- One-click pipeline retreat — `retreat_pipeline!` requires a non-blank `reason`; the UI must collect it through a form, not pass a hardcoded string
- Hard-coded pipeline stage lists in controllers or views — read from `PipelineFlow` (`kanban_stages`, `horizontal_stages`, `all_stages`)
- `dig`-ing into `document_checklist` from a template — call `request.checklist_done?(key)`
- New `app/javascript/` files for behavior expressible as a Stimulus controller
- Secrets in ENV beyond `RAILS_MASTER_KEY` — use Rails encrypted credentials
