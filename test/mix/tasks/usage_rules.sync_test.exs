defmodule Mix.Tasks.UsageRules.SyncTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "specific packages" do
    test "combines usage rules from specified packages into target file" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash framework rules",
          "deps/phoenix/usage-rules.md" => "Phoenix web framework rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["rules.md", "ash", "phoenix"])
      |> assert_creates("rules.md")
    end

    test "ignores packages without usage-rules.md files" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash framework rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["rules.md", "ash", "phoenix"])
      |> assert_creates("rules.md")
    end

    test "requires packages when no options given" do
      igniter = 
        test_project()
        |> Igniter.compose_task("usage_rules.sync", [])
      
      case apply_igniter(igniter) do
        {:error, [error_message]} ->
          assert String.contains?(error_message, "Usage:")
          assert String.contains?(error_message, "mix usage_rules.sync <file> <packages...>")
        result ->
          flunk("Expected error, got: #{inspect(result)}")
      end
    end
  end

  describe "--all option" do
    test "includes all dependencies with usage-rules.md files" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash framework rules",
          "deps/phoenix/usage-rules.md" => "Phoenix web framework rules",
          "deps/ecto/usage-rules.md" => "Ecto database rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["rules.md", "--all"])
      |> assert_has_notice("Found 3 dependencies with usage rules")
      |> assert_has_notice("Including usage rules for: ash")
      |> assert_has_notice("Including usage rules for: ecto")
      |> assert_has_notice("Including usage rules for: phoenix")
      |> assert_creates("rules.md")
    end

    test "requires file when using --all option" do
      igniter = 
        test_project()
        |> Igniter.compose_task("usage_rules.sync", ["--all"])
      
      case apply_igniter(igniter) do
        {:error, [error_message]} ->
          assert String.contains?(error_message, "--all option requires a file to write to")
        result ->
          flunk("Expected error, got: #{inspect(result)}")
      end
    end

    test "cannot specify packages with --all option" do
      igniter = 
        test_project()
        |> Igniter.compose_task("usage_rules.sync", ["rules.md", "ash", "--all"])
      
      case apply_igniter(igniter) do
        {:error, [error_message]} ->
          assert String.contains?(error_message, "Cannot specify packages when using --all or --list options")
        result ->
          flunk("Expected error, got: #{inspect(result)}")
      end
    end
  end

  describe "--list option" do
    test "lists all dependencies with usage rules without file comparison" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash framework rules",
          "deps/phoenix/usage-rules.md" => "Phoenix web framework rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["--list"])
      |> assert_has_notice("ash: \e[32mhas usage rules\e[0m")
      |> assert_has_notice("phoenix: \e[32mhas usage rules\e[0m")
    end

    test "shows message when no packages have usage rules" do
      test_project()
      |> Igniter.compose_task("usage_rules.sync", ["--list"])
      |> assert_has_notice("No packages found with usage-rules.md files")
    end

    test "cannot specify packages with --list option" do
      igniter = 
        test_project()
        |> Igniter.compose_task("usage_rules.sync", ["rules.md", "ash", "--list"])
      
      case apply_igniter(igniter) do
        {:error, [error_message]} ->
          assert String.contains?(error_message, "Cannot specify packages when using --all or --list options")
        result ->
          flunk("Expected error, got: #{inspect(result)}")
      end
    end
  end

  describe "file operations" do
    test "creates new file when file doesn't exist" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash framework rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["new_rules.md", "ash"])
      |> assert_creates("new_rules.md")
    end

    test "handles empty usage-rules.md files" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => ""
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["rules.md", "ash"])
      |> assert_creates("rules.md")
    end

    test "handles package names with special characters" do
      test_project(
        files: %{
          "deps/special-pkg/usage-rules.md" => "Special package rules"
        }
      )
      |> Igniter.compose_task("usage_rules.sync", ["rules.md", "special-pkg"])
      |> assert_creates("rules.md")
    end
  end
end