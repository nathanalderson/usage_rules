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
