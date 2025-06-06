# UsageRules

**UsageRules** is a development tool for Elixir projects that helps gather and consolidate usage rules from dependencies. The package provides Mix tasks to collect documentation from dependencies that have `usage-rules.md` files and combine them into a single rules file for your project.

You'll note this package itself doesn't have a usage-rules.md. Its a simple tool that likely would not benefit from having a usage-rules.md file.

`usage-rules.md` is not an existing standard, rather it is a community initiative that may evolve over time as adoption grows and feedback is gathered. We encourage experimentation and welcome input on how to make this approach more useful for the broader Elixir ecosystem.

## For Package Authors

Even if you don't want to use LLMs, its very possible that your users will, and they will often come to you with hallucinations from their LLMs and try to get your help with it. Writing a `usage-rules.md` file is a great way to stop this sort of thing 😁

We don't really know what makes great usage-rules.md files yet. Ash Framework is experimenting with quite fleshed out usage rules which seems to be working quite well. See [Ash Framework's usage-rules.md](https://github.com/ash-project/ash/blob/main/usage-rules.md) for one such large example. Perhaps for your package or framework only a few lines are necessary. We will all have to adjust over time.

One quick tip is to have an agent begin the work of writing rules for you, by pointing it at your docs and asking it to write a `usage-rules.md` file in a condensed format that would be useful for agents to work with your tool. Then, aggressively prune and edit it to your taste.

## Key Features

1. **Dependency Rules Collection**: Automatically discovers and collects usage rules from dependencies that provide `usage-rules.md` files in their package directory
2. **Rules Consolidation**: Combines multiple package rules into a single file with proper sectioning and markers
3. **Status Tracking**: Can list dependencies with usage rules and check if your consolidated file is up-to-date
4. **Selective Management**: Allows adding/removing specific packages from your rules file

## How It Works

1. The tool scans your project's dependencies (in `deps/` directory)
2. Looks for `usage-rules.md` files in each dependency
3. Consolidates these rules into a target file with special markers like `<-- package-name-start -->` and `<-- package-name-end -->`
4. Maintains sections that can be updated independently as dependencies change

This is particularly useful for projects using frameworks like Ash, Phoenix, or other packages that provide specific usage guidelines, coding patterns, or best practices that should be followed consistently across your project.

## Usage

The main task `Mix.Tasks.UsageRules.Sync` provides several modes of operation:

### Combine specific packages
```sh
mix usage_rules.sync rules.md ash phoenix
```

### Gather all dependencies with usage rules
```sh
mix usage_rules.sync rules.md --all
```

### List available packages with usage rules
```sh
mix usage_rules.sync --list
```

### Check status against a file
```sh
mix usage_rules.sync rules.md --list
```

### Remove packages from a file
```sh
mix usage_rules.sync rules.md ash --remove
```

### Use folder links for better organization
```sh
mix usage_rules.sync rules.md ash phoenix --link-to-folder rules
```

### Use @-style folder links
```sh
mix usage_rules.sync rules.md ash phoenix --link-to-folder rules --link-style at
```

### Gather all dependencies with folder links
```sh
mix usage_rules.sync rules.md --all --link-to-folder docs
```

## Advanced Features

### Folder Links (`--link-to-folder`)

The `--link-to-folder` option provides enhanced organization for managing large sets of usage rules. This feature is particularly valuable when working with Claude AI or other systems that benefit from modular file organization.

**What it does:**
- Creates individual `.md` files for each package in the specified folder
- Generates a main file with markdown links (`[package usage rules](folder/package.md)`) by default
- Can optionally use @-style links (`@folder/package.md`) with `--link-style at`
- Maintains the same section markers for easy updates and status tracking
- Works with all other options (`--all`, `--list`, `--remove`)

**Link Style Options:**
- `--link-style markdown` (default): Creates standard markdown links like `[ash usage rules](docs/ash.md)`
- `--link-style at`: Creates @-style links like `@docs/ash.md`

**Key Benefits:**

**🤖 Claude AI Integration**
- With `--link-style at`, Claude can efficiently reference specific package rules using the `@folder/file.md` syntax
- Avoids hitting Claude's context limits when working with large rule sets
- Allows Claude to selectively load only relevant rules for the current task
- Enables better conversation flow by referencing specific documentation files

**📁 Better Organization**
- Large rule sets become easier to navigate and maintain
- Individual files can be edited independently
- Cleaner Git diffs when rules change
- Modular structure scales well with project growth
- Standard markdown links work well with any markdown viewer or documentation system

**Example workflows:**
```sh
# Create organized rule files with markdown links (default)
mix usage_rules.sync rules.md ash phoenix --link-to-folder docs

# Create organized rule files with @-style links
mix usage_rules.sync rules.md ash phoenix --link-to-folder docs --link-style at

# Gather all dependencies with folder organization
mix usage_rules.sync rules.md --all --link-to-folder docs
```

**File structure created:**
```
docs/
├── ash.md           # Full Ash usage rules content
└── phoenix.md       # Full Phoenix usage rules content
rules.md             # Main file with links
```

**Main file (`rules.md`) contains (markdown style - default):**
```markdown
<-- usage-rules-start -->
<-- ash-start -->
## ash usage
[ash usage rules](docs/ash.md)
<-- ash-end -->
<-- phoenix-start -->
## phoenix usage
[phoenix usage rules](docs/phoenix.md)
<-- phoenix-end -->
<-- usage-rules-end -->
```

**Or with @-style links (`--link-style at`):**
```markdown
<-- usage-rules-start -->
<-- ash-start -->
## ash usage
@docs/ash.md
<-- ash-end -->
<-- phoenix-start -->
## phoenix usage
@docs/phoenix.md
<-- phoenix-end -->
<-- usage-rules-end -->
```

**Individual files (`docs/ash.md`) contain:**
```markdown
# Ash Framework Usage Rules

Use `list_generators` to list available generators when available...
[Full usage rules content here]
```

**Working with Claude:**
When using `--link-style at`, Claude can intelligently load specific package rules by following the `@docs/package.md` links, making your conversations more focused and efficient. The default markdown links work well with standard documentation systems and any markdown viewer.

## Installation

### With Igniter

`mix igniter.install usage_rules`.

Add the dependency manually

```elixir
def deps do
  [
    # should only ever be used as a dev dependency
    # requires igniter as a dev dependency
    {:usage_rules, "~> 0.1", only: [:dev]},
    {:igniter, "~> 0.6", only: [:dev]}
  ]
end
```
