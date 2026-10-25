# dbt Docs → Snowflake Semantic Views

Reuse your dbt Markdown descriptions as `COMMENT` properties in Snowflake Semantic Views, so business definitions are authored once and visible to semantic-aware AI tools (e.g. Cortex Analyst).

> **Write documentation once. Reuse dbt's resolved metadata. Publish the context where it matters.**

## Contents

- [The problem](#the-problem)
- [How it works](#how-it-works)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Optional: shared documentation ownership](#optional-shared-documentation-ownership)
- [Optional: sync with GitHub Actions](#optional-sync-with-github-actions)
- [Promoting through CI/CD](#promoting-through-cicd)
- [Limitations and caveats](#limitations-and-caveats)
- [References](#references)

## The problem

dbt lets you maintain docs centrally in Markdown and reference them from YAML:

```yaml
description: '{{ doc("total_revenue") }}'
```

With `persist_docs` enabled, dbt persists relation and column comments on supported Snowflake tables and views. The official `persist_docs` docs do not document automatic propagation to **Semantic View** dimensions, facts, or metrics. In the integration this was built against, YAML descriptions resolved in dbt metadata but were **not** written into Semantic View `COMMENT` properties.

A Semantic View is its own metadata layer. Without descriptions there, an LLM asked *"What was our total revenue last month?"* has only a metric name to go on: it can't tell whether cancellations, taxes, or adjustments are included.

Duplicating the descriptions by hand inside the Semantic View SQL creates a second source of truth that drifts. This repo avoids that.

## How it works

dbt resolves `doc()` references in YAML during parsing and exposes the result through the `graph` Jinja context. A small macro reads the resolved description from `graph.nodes` and emits it as a SQL string literal.

```
Markdown {% docs %}
   → YAML doc()
   → dbt manifest / graph.nodes
   → get_semantic_description() macro
   → Semantic View COMMENT
   → context for semantic-aware AI tools
```

Markdown stays the single authored source.

Why not call `doc()` directly inside the Semantic View SQL? In the package context used here it raised an *unknown Jinja function* error. Resolving it in YAML first and reading the graph metadata avoids that. This is an integration-specific workaround, not a claim about every dbt version.

## Repository layout

```
.
├── dbt-project/                       # example dbt project
│   ├── dbt_project.yml
│   ├── docs/markdown/booking_metrics.md
│   ├── macros/get_semantic_description.sql
│   └── models/semantic/
│       ├── semantic.yml               # doc() references per column
│       └── booking_semantic_view.sql  # calls the macro in COMMENT clauses
└── documentation-repo/                # optional: analyst-owned docs repo
    ├── CODEOWNERS
    ├── docs/markdown/booking_metrics.md
    └── .github/workflows/sync-docs.yml
```

## Quick start

### 1. Define documentation blocks

`dbt-project/docs/markdown/booking_metrics.md`

```jinja
{% docs total_bookings %}
Total number of confirmed bookings during the reporting period.
{% enddocs %}

{% docs total_revenue %}
Revenue from confirmed bookings, excluding cancelled transactions.
{% enddocs %}
```

### 2. Reference the blocks in YAML

`dbt-project/models/semantic/semantic.yml`

```yaml
version: 2

models:
  - name: booking_semantic_view
    description: Booking performance metrics
    columns:
      - name: total_bookings
        description: '{{ doc("total_bookings") }}'
      - name: total_revenue
        description: '{{ doc("total_revenue") }}'
```

The column names here are the keys the macro looks up in the next steps.

### 3. Add the macro

`dbt-project/macros/get_semantic_description.sql`

```jinja
{% macro get_semantic_description(model_name, column_name) %}
    {% set ns = namespace(description='') %}
    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'model' and node.name == model_name %}
            {% if column_name in node.columns %}
                {% set ns.description = node.columns[column_name].description %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return("'" ~ (ns.description | default('', true) | trim | replace("'", "''")) ~ "'") }}
{% endmacro %}
```

What it does:

- Searches model nodes for the requested model and column and returns the resolved description as a SQL string literal.
- Uses `namespace()` because a plain `set` inside a Jinja `for` loop doesn't persist outside it.
- Escapes apostrophes by doubling them (`'` → `''`).
- Returns an empty string for undocumented columns.
- Assumes model names are unique. In multi-package projects, match on `unique_id` or `package_name` too.

### 4. Call it in the Semantic View

`dbt-project/models/semantic/booking_semantic_view.sql` (excerpt)

```sql
METRICS (
    bookings.total_bookings AS SUM(bookings.booking_count)
        COMMENT = {{ get_semantic_description('booking_semantic_view', 'total_bookings') }},
    bookings.total_revenue AS SUM(bookings.revenue)
        COMMENT = {{ get_semantic_description('booking_semantic_view', 'total_revenue') }}
)
```

This compiles to ordinary Snowflake comments:

```sql
bookings.total_revenue AS SUM(bookings.revenue)
    COMMENT = 'Revenue from confirmed bookings, excluding cancelled transactions.'
```

> The model file in this repo is a **sketch**. Table refs, columns, and the `materialized='semantic_view'` config are placeholders; adapt them to your Semantic View package and schema. The macro works the same wherever a `COMMENT` literal is needed.

### 5. Validate before deploying

```bash
dbt parse
dbt compile --select booking_semantic_view
```

Then:

1. Inspect `target/manifest.json` for resolved descriptions.
2. Inspect `target/compiled/.../booking_semantic_view.sql` for populated `COMMENT` clauses.
3. Deploy with your usual materialization command (e.g. `dbt run --select booking_semantic_view`) only after compilation succeeds.

Compilation does **not** prove Snowflake will accept the DDL.

## Optional: shared documentation ownership

Data engineers own SQL and models; analysts often own business definitions. Both should be able to contribute descriptions without every analyst needing access to the whole dbt project.

`CODEOWNERS` can require review of `docs/` changes, but it **does not restrict read access** to folders or branches. For stricter separation, keep a dedicated documentation repository as the authoritative source, and let the dbt repo receive synchronized copies under `docs/`.

```
documentation-repo/            dbt-project/
  docs/markdown/                 models/
    bookings.md                  macros/
    revenue.md                   docs/        ← synced copy
  .github/workflows/             tests/
    sync-docs.yml                dbt_project.yml
```

Workflow: analysts branch, edit Markdown, open a PR, and merge into the docs repo's `main`. A one-way sync then updates the dbt `dev` branch. One-way sync avoids two repos editing the same files.

## Optional: sync with GitHub Actions

The default `GITHUB_TOKEN` can read the docs repo but can't write to a different private repo. Use a **GitHub App** installed on the destination repo with *Contents: write*; it issues short-lived installation tokens during the run.

### Setup

1. Create a GitHub App and install it on the dbt repository with **Contents: write**.
2. In the docs repo, add:
   - repository **variable** `APP_ID` (or `APP_CLIENT_ID` if you switch to the Client ID input)
   - repository **secret** `APP_PRIVATE_KEY`
3. Edit `owner`, `repositories`, and `repository` in `documentation-repo/.github/workflows/sync-docs.yml`.

The installation token is generated per run and never stored.

### What the workflow does

Triggers on pushes to `main` that touch `docs/**` (or manually), checks out both repos, copies `source/docs/` into `target/docs/`, commits as `docs-sync-bot`, and pushes to `dev`. See [`sync-docs.yml`](documentation-repo/.github/workflows/sync-docs.yml).

### Behaviour worth knowing

- `cp -a` adds and updates files; it does **not delete** files removed from the source.
- It never touches `models/` or `macros/`.
- A normal (non-force) push fails if `dev` advanced concurrently. That's deliberate and safer than overwriting history.
- Contents-write is **repository-wide**, not limited to `docs/`. Protect workflow files and the App private key. For stricter governance, open a sync **PR** instead of pushing directly.

## Promoting through CI/CD

```
documentation main → dbt dev → validated QA → reviewed production PR
   → dbt deployment → Snowflake Semantic View comments
```

- Merging Markdown to the production branch does **not** by itself update Snowflake. The production job must compile and execute the Semantic View definitions.
- Whole-branch dev → QA promotion can carry unrelated SQL changes, so validation and release controls matter.

## Limitations and caveats

- Comments don't guarantee accurate AI answers. They help when the consuming application reads them.
- Behaviour was observed with one dbt version / Semantic View package combination. Validate against yours, since Jinja contexts and package behaviour differ.
- The `doc()`-in-SQL error is integration-specific.
- Macro lookups by model name assume uniqueness.

## References

- [dbt `persist_docs`](https://docs.getdbt.com/reference/resource-configs/persist_docs)
- [dbt `doc()`](https://docs.getdbt.com/reference/dbt-jinja-functions/doc)
- [dbt `graph`](https://docs.getdbt.com/reference/dbt-jinja-functions/graph)
- [Snowflake `CREATE SEMANTIC VIEW`](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Snowflake Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [GitHub Apps](https://docs.github.com/en/apps)
- [GitHub Actions](https://docs.github.com/en/actions)
