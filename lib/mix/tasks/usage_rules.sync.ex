defmodule Mix.Tasks.UsageRules.Sync.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc do
    "Combine the package rules for the provided packages into the provided file, or list/gather all dependencies."
  end

  @spec example() :: String.t()
  def example do
    "mix usage_rules.sync CLAUDE.md --all --link-to-folder deps"
  end

  @spec long_doc() :: String.t()
  def long_doc do
    """
    #{short_doc()}

    ## Options

    * `--all` - Gather usage rules from all dependencies that have them
    * `--list` - List all dependencies with usage rules. If a file is provided, shows status (present, missing, stale)
    * `--remove` - Remove specified packages from the target file instead of adding them
    * `--link-to-folder <folder>` - Save usage rules for each package in separate files within the specified folder and create links to them
    * `--link-style <style>` - Style of links to create when using --link-to-folder (markdown|at). Defaults to 'markdown'
    * `--builtins <builtins>` - Include built-in usage rules (comma-separated: elixir,otp)
    * `--builtins-link` - Make built-in usage rules honor the --link-to-folder option (default: false, builtins are inlined)

    ## Examples

    Combine specific packages:
    ```sh
    #{example()}
    ```

    Gather all dependencies with usage rules:
    ```sh
    mix usage_rules.sync CLAUDE.md --all
    ```

    List all dependencies with usage rules:
    ```sh
    mix usage_rules.sync --list
    ```

    Check status of dependencies against a specific file:
    ```sh
    mix usage_rules.sync CLAUDE.md --list
    ```

    Remove specific packages from a file:
    ```sh
    mix usage_rules.sync CLAUDE.md ash phoenix --remove
    ```

    Save usage rules to individual files in a folder with markdown links:
    ```sh
    mix usage_rules.sync CLAUDE.md ash phoenix --link-to-folder rules
    ```

    Save usage rules with @-style links:
    ```sh
    mix usage_rules.sync CLAUDE.md ash phoenix --link-to-folder rules --link-style at
    ```

    Link directly to deps files without copying:
    ```sh
    mix usage_rules.sync CLAUDE.md ash phoenix --link-to-folder deps
    ```

    Combine all dependencies with folder links:
    ```sh
    mix usage_rules.sync CLAUDE.md --all --link-to-folder docs
    ```

    Check status of packages using folder links:
    ```sh
    mix usage_rules.sync CLAUDE.md --list --link-to-folder rules
    ```

    Remove packages and their folder files:
    ```sh
    mix usage_rules.sync CLAUDE.md ash phoenix --remove --link-to-folder rules
    ```

    Include built-in Elixir and OTP usage rules:
    ```sh
    mix usage_rules.sync CLAUDE.md --all --link-to-folder deps --builtins elixir,otp
    ```
    Include built-in usage rules with links to folder:
    ```sh
    mix usage_rules.sync CLAUDE.md --all --link-to-folder docs --builtins elixir,otp --builtins-link
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.UsageRules.Sync do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :usage_rules,
        example: __MODULE__.Docs.example(),
        positional: [
          file: [optional: true],
          packages: [rest: true, optional: true]
        ],
        schema: [
          all: :boolean,
          list: :boolean,
          remove: :boolean,
          link_to_folder: :string,
          link_style: :string,
          builtins: :string,
          builtins_link: :boolean
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter =
        if is_nil(igniter.parent) do
          igniter
          |> Igniter.assign(:prompt_on_git_changes?, false)
          |> Igniter.assign(:quiet_on_no_changes?, true)
        else
          igniter
        end

      # Add all usage-rules.md files from deps directory to igniter
      igniter = Igniter.include_glob(igniter, "deps/*/usage-rules.md")

      top_level_deps =
        Mix.Project.get().project()[:deps] |> Enum.map(&elem(&1, 0))

      # Get all deps from both Mix.Project.deps_paths and Igniter rewrite sources
      mix_deps =
        Mix.Project.deps_paths()
        |> Enum.filter(fn {dep, _path} ->
          dep in top_level_deps
        end)
        |> Enum.map(fn {dep, path} ->
          {dep, Path.relative_to_cwd(path)}
        end)

      igniter_deps = get_deps_from_igniter(igniter)
      all_deps = (mix_deps ++ igniter_deps) |> Enum.uniq()

      all_option = igniter.args.options[:all]
      list_option = igniter.args.options[:list]
      remove_option = igniter.args.options[:remove]
      link_to_folder = igniter.args.options[:link_to_folder]
      link_style = igniter.args.options[:link_style] || "markdown"
      provided_packages = igniter.args.positional.packages
      builtins = parse_builtins(igniter.args.options[:builtins])
      builtins_link = igniter.args.options[:builtins_link]

      cond do
        # If --builtins contains invalid values, add error
        igniter.args.options[:builtins] &&
            parse_invalid_builtins(igniter.args.options[:builtins]) != [] ->
          invalid = parse_invalid_builtins(igniter.args.options[:builtins])

          Igniter.add_issue(
            igniter,
            "Invalid builtins: #{Enum.join(invalid, ", ")}. Valid options are: elixir, otp"
          )

        # If --link-style is used with invalid value, add error
        link_style && link_style not in ["markdown", "at"] ->
          Igniter.add_issue(igniter, "--link-style must be either 'markdown' or 'at'")

        # If --link-style is used without --link-to-folder, add error
        igniter.args.options[:link_style] && !link_to_folder ->
          Igniter.add_issue(igniter, "--link-style can only be used with --link-to-folder")

        # If --remove is used with --all or --list, add error
        remove_option && (all_option || list_option) ->
          Igniter.add_issue(igniter, "Cannot use --remove with --all or --list options")

        # If --remove is used without a file, add error
        remove_option && is_nil(igniter.args.positional[:file]) ->
          Igniter.add_issue(igniter, "--remove option requires a file to remove from")

        # If --remove is used without packages, add error
        remove_option && Enum.empty?(provided_packages) ->
          Igniter.add_issue(igniter, "--remove option requires packages to remove")

        # If --list or --all is given and packages list is not empty, add error
        (all_option || list_option) && !Enum.empty?(provided_packages) ->
          Igniter.add_issue(igniter, "Cannot specify packages when using --all or --list options")

        # If --all is used without a file, add error
        all_option && is_nil(igniter.args.positional[:file]) ->
          Igniter.add_issue(igniter, "--all option requires a file to write to")

        # If --link-to-folder is used without a file, add error
        link_to_folder && is_nil(igniter.args.positional[:file]) ->
          Igniter.add_issue(igniter, "--link-to-folder option requires a file to write to")

        # If no packages are given and neither --list nor --all nor --remove is set, add error
        Enum.empty?(provided_packages) && !all_option && !list_option && !remove_option ->
          add_usage_error(igniter)

        # Handle --remove option
        remove_option ->
          handle_remove_packages(igniter, provided_packages, link_to_folder)

        # Handle --all option
        all_option ->
          handle_all_option(
            igniter,
            all_deps,
            link_to_folder,
            link_style,
            builtins,
            builtins_link
          )

        # Handle --list option
        list_option ->
          handle_list_option(igniter, all_deps, link_to_folder)

        # Handle specific packages
        true ->
          handle_specific_packages(
            igniter,
            all_deps,
            provided_packages,
            link_to_folder,
            link_style,
            builtins,
            builtins_link
          )
      end
    end

    defp parse_builtins(nil), do: []

    defp parse_builtins(builtins_string) do
      builtins_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn builtin ->
        builtin in ["elixir", "otp"]
      end)
    end

    defp parse_invalid_builtins(nil), do: []

    defp parse_invalid_builtins(builtins_string) do
      builtins_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn builtin ->
        builtin in ["", "elixir", "otp"]
      end)
    end

    defp get_builtin_contents(builtins) do
      builtins
      |> Enum.map(fn builtin ->
        builtin_path = Path.join([:code.priv_dir(:usage_rules), "builtins", "#{builtin}.md"])
        content = File.read!(builtin_path)

        {String.to_atom(builtin),
         "<!-- #{builtin}-start -->\n" <>
           "## #{builtin} usage\n" <>
           content <>
           "\n<!-- #{builtin}-end -->"}
      end)
    end

    defp get_deps_from_igniter(igniter) do
      if igniter.assigns[:test_mode?] do
        igniter.rewrite.sources
        |> Enum.filter(fn {path, _source} ->
          String.match?(path, ~r|^deps/[^/]+/usage-rules\.md$|)
        end)
        |> Enum.map(fn {path, _source} ->
          # Extract package name from deps/package_name/usage-rules.md
          package_name =
            path
            |> String.split("/")
            |> Enum.at(1)
            |> String.to_atom()

          # Extract package path from deps/package_name/usage-rules.md
          package_path = Path.dirname(path)

          {package_name, package_path}
        end)
        |> Enum.uniq()
      else
        []
      end
    end

    defp add_usage_error(igniter) do
      Igniter.add_issue(igniter, """
      Usage:
        mix usage_rules.sync CLAUDE.md --all --link-to-folder deps
          Standard usage: gather all dependencies and link directly to deps files

        mix usage_rules.sync <file> <packages...>
          Combine specific packages' usage rules into the target file

        mix usage_rules.sync <file> --all
          Gather usage rules from all dependencies into the target file

        mix usage_rules.sync [file] --list
          List packages with usage rules (optionally check status against file)

        mix usage_rules.sync <file> <packages...> --remove
          Remove specific packages from the target file

        mix usage_rules.sync <file> <packages...> --link-to-folder <folder>
          Save usage rules for each package in separate files within the specified folder and create links to them

        mix usage_rules.sync <file> --list --link-to-folder <folder>
          List packages with usage rules and check status against folder links

        mix usage_rules.sync <file> <packages...> --remove --link-to-folder <folder>
          Remove specific packages from the target file and delete their folder files
      """)
    end

    defp handle_all_option(igniter, all_deps, link_to_folder, link_style, builtins, builtins_link) do
      all_packages_with_rules = get_packages_with_usage_rules(igniter, all_deps)

      igniter
      |> Igniter.add_notice(
        "Found #{length(all_packages_with_rules)} dependencies with usage rules"
      )
      |> then(fn igniter ->
        Enum.reduce(all_packages_with_rules, igniter, fn {name, _path}, acc ->
          Igniter.add_notice(acc, "Including usage rules for: #{name}")
        end)
      end)
      |> maybe_add_builtin_notices(builtins)
      |> generate_usage_rules_file(
        all_packages_with_rules,
        link_to_folder,
        link_style,
        builtins,
        builtins_link
      )
    end

    defp maybe_add_builtin_notices(igniter, []), do: igniter

    defp maybe_add_builtin_notices(igniter, builtins) do
      Enum.reduce(builtins, igniter, fn builtin, acc ->
        Igniter.add_notice(acc, "Including built-in usage rules for: #{builtin}")
      end)
    end

    defp handle_list_option(igniter, all_deps, link_to_folder) do
      packages_with_rules = get_packages_with_usage_rules(igniter, all_deps)

      if Enum.empty?(packages_with_rules) do
        Igniter.add_notice(igniter, "No packages found with usage-rules.md files")
      else
        file_path = igniter.args.positional[:file]

        if file_path do
          list_packages_with_file_comparison(
            igniter,
            packages_with_rules,
            file_path,
            link_to_folder
          )
        else
          list_packages_without_comparison(igniter, packages_with_rules)
        end
      end
    end

    defp handle_specific_packages(
           igniter,
           all_deps,
           provided_packages,
           link_to_folder,
           link_style,
           builtins,
           builtins_link
         ) do
      packages =
        all_deps
        |> Enum.filter(fn {name, _path} ->
          to_string(name) in provided_packages
        end)
        |> Enum.flat_map(fn {name, path} ->
          usage_rules_path = Path.join(path, "usage-rules.md")

          if Igniter.exists?(igniter, usage_rules_path) do
            [{name, path}]
          else
            []
          end
        end)

      igniter
      |> maybe_add_builtin_notices(builtins)
      |> generate_usage_rules_file(packages, link_to_folder, link_style, builtins, builtins_link)
    end

    defp handle_remove_packages(igniter, provided_packages, link_to_folder) do
      file_path = igniter.args.positional[:file]

      if Igniter.exists?(igniter, file_path) do
        remove_packages_from_file(igniter, file_path, provided_packages, link_to_folder)
      else
        Igniter.add_issue(igniter, "File #{file_path} does not exist")
      end
    end

    defp get_packages_with_usage_rules(igniter, all_deps) do
      all_deps
      |> Enum.filter(fn {_name, path} ->
        usage_rules_path = Path.join(path, "usage-rules.md")
        Igniter.exists?(igniter, usage_rules_path)
      end)
    end

    defp list_packages_with_file_comparison(
           igniter,
           packages_with_rules,
           file_path,
           link_to_folder
         ) do
      current_file_content = read_current_file_content(igniter, file_path)

      Enum.reduce(packages_with_rules, igniter, fn {name, path}, acc ->
        usage_rules_path = Path.join(path, "usage-rules.md")

        package_rules_content =
          case Rewrite.source(acc.rewrite, usage_rules_path) do
            {:ok, source} -> Rewrite.Source.get(source, :content)
            {:error, _} -> File.read!(usage_rules_path)
          end

        status =
          get_package_status_in_file(
            acc,
            name,
            package_rules_content,
            current_file_content,
            link_to_folder
          )

        Igniter.add_notice(acc, "#{name}: #{colorize_status(status)}")
      end)
    end

    defp list_packages_without_comparison(igniter, packages_with_rules) do
      Enum.reduce(packages_with_rules, igniter, fn {name, _path}, acc ->
        Igniter.add_notice(acc, "#{name}: #{IO.ANSI.green()}has usage rules#{IO.ANSI.reset()}")
      end)
    end

    defp read_current_file_content(igniter, file_path) do
      if Igniter.exists?(igniter, file_path) do
        case Rewrite.source(igniter.rewrite, file_path) do
          {:ok, source} ->
            Rewrite.Source.get(source, :content)

          {:error, _} ->
            case File.read(file_path) do
              {:ok, content} -> content
              {:error, _} -> ""
            end
        end
      else
        ""
      end
    end

    defp generate_usage_rules_file(
           igniter,
           packages,
           link_to_folder,
           link_style,
           builtins,
           builtins_link
         ) do
      if link_to_folder do
        generate_usage_rules_with_folder_links(
          igniter,
          packages,
          link_to_folder,
          link_style,
          builtins,
          builtins_link
        )
      else
        generate_usage_rules_inline(igniter, packages, builtins)
      end
    end

    defp generate_usage_rules_inline(igniter, packages, builtins) do
      package_contents =
        packages
        |> Enum.map(fn {name, path} ->
          usage_rules_path = Path.join(path, "usage-rules.md")

          content =
            case Rewrite.source(igniter.rewrite, usage_rules_path) do
              {:ok, source} -> Rewrite.Source.get(source, :content)
              {:error, _} -> File.read!(usage_rules_path)
            end

          {name,
           "<!-- #{name}-start -->\n" <>
             "## #{name} usage\n" <>
             content <>
             "\n<!-- #{name}-end -->"}
        end)

      builtin_contents = get_builtin_contents(builtins)

      all_contents = package_contents ++ builtin_contents
      all_rules_content = Enum.map_join(all_contents, "\n", &elem(&1, 1))

      full_contents_for_new_file =
        "<!-- usage-rules-start -->\n" <>
          all_rules_content <>
          "\n<!-- usage-rules-end -->"

      Igniter.create_or_update_file(
        igniter,
        igniter.args.positional[:file],
        full_contents_for_new_file,
        fn source ->
          current_contents = Rewrite.Source.get(source, :content)

          new_content =
            case String.split(current_contents, [
                   "<!-- usage-rules-start -->\n",
                   "\n<!-- usage-rules-end -->"
                 ]) do
              [prelude, current_packages_contents, postlude] ->
                Enum.reduce(all_contents, current_packages_contents, fn {name, package_content},
                                                                        acc ->
                  case String.split(acc, [
                         "<!-- #{name}-start -->\n",
                         "\n<!-- #{name}-end -->"
                       ]) do
                    [prelude, _, postlude] ->
                      prelude <> package_content <> postlude

                    _ ->
                      acc <> "\n" <> package_content
                  end
                end)
                |> then(fn content ->
                  prelude <>
                    "<!-- usage-rules-start -->\n" <>
                    content <>
                    "\n<!-- usage-rules-end -->" <>
                    postlude
                end)

              _ ->
                current_contents <>
                  "\n<!-- usage-rules-start -->\n" <>
                  all_rules_content <>
                  "\n<!-- usage-rules-end -->\n"
            end

          Rewrite.Source.update(source, :content, new_content)
        end
      )
    end

    defp generate_usage_rules_with_folder_links(
           igniter,
           packages,
           folder_name,
           link_style,
           builtins,
           builtins_link
         ) do
      # Create individual files for each package in the folder (unless folder is "deps")
      igniter =
        if folder_name == "deps" do
          igniter
        else
          # Create builtin files in the target folder only if builtins_link is true
          igniter =
            if builtins_link do
              Enum.reduce(builtins, igniter, fn builtin, acc ->
                builtin_source_path =
                  Path.join([:code.priv_dir(:usage_rules), "builtins", "#{builtin}.md"])

                builtin_file_path = Path.join(folder_name, "#{builtin}.md")
                content = File.read!(builtin_source_path)

                Igniter.create_or_update_file(
                  acc,
                  builtin_file_path,
                  content,
                  fn source ->
                    Rewrite.Source.update(source, :content, content)
                  end
                )
              end)
            else
              igniter
            end

          Enum.reduce(packages, igniter, fn {name, path}, acc ->
            usage_rules_path = Path.join(path, "usage-rules.md")

            content =
              case Rewrite.source(acc.rewrite, usage_rules_path) do
                {:ok, source} -> Rewrite.Source.get(source, :content)
                {:error, _} -> File.read!(usage_rules_path)
              end

            package_file_path = Path.join(folder_name, "#{name}.md")

            Igniter.create_or_update_file(
              acc,
              package_file_path,
              content,
              fn source ->
                Rewrite.Source.update(source, :content, content)
              end
            )
          end)
        end

      # Then, create the main file with links
      package_contents =
        packages
        |> Enum.map(fn {name, _path} ->
          link_content =
            case {link_style, folder_name} do
              {"at", "deps"} -> "@deps/#{name}/usage-rules.md"
              {"at", _} -> "@#{folder_name}/#{name}.md"
              {_, "deps"} -> "[#{name} usage rules](deps/#{name}/usage-rules.md)"
              _ -> "[#{name} usage rules](#{folder_name}/#{name}.md)"
            end

          {name,
           "<!-- #{name}-start -->\n" <>
             "## #{name} usage\n" <>
             link_content <>
             "\n<!-- #{name}-end -->"}
        end)

      builtin_contents =
        if builtins_link do
          # If builtins_link is true, create links
          builtins
          |> Enum.map(fn builtin ->
            link_content =
              case {link_style, folder_name} do
                {"at", "deps"} ->
                  "@deps/usage_rules/priv/builtins/#{builtin}.md"

                {"at", _} ->
                  "@#{folder_name}/#{builtin}.md"

                {_, "deps"} ->
                  "[#{builtin} usage rules](deps/usage_rules/priv/builtins/#{builtin}.md)"

                _ ->
                  "[#{builtin} usage rules](#{folder_name}/#{builtin}.md)"
              end

            {String.to_atom(builtin),
             "<!-- #{builtin}-start -->\n" <>
               "## #{builtin} usage\n" <>
               link_content <>
               "\n<!-- #{builtin}-end -->"}
          end)
        else
          # If builtins_link is false (default), inline the content
          get_builtin_contents(builtins)
        end

      all_contents = package_contents ++ builtin_contents
      all_rules_content = Enum.map_join(all_contents, "\n", &elem(&1, 1))

      full_contents_for_new_file =
        "<!-- usage-rules-start -->\n" <>
          all_rules_content <>
          "\n<!-- usage-rules-end -->"

      Igniter.create_or_update_file(
        igniter,
        igniter.args.positional[:file],
        full_contents_for_new_file,
        fn source ->
          current_contents = Rewrite.Source.get(source, :content)

          new_content =
            case String.split(current_contents, [
                   "<!-- usage-rules-start -->\n",
                   "\n<!-- usage-rules-end -->"
                 ]) do
              [prelude, current_packages_contents, postlude] ->
                Enum.reduce(all_contents, current_packages_contents, fn {name, package_content},
                                                                        acc ->
                  case String.split(acc, [
                         "<!-- #{name}-start -->\n",
                         "\n<!-- #{name}-end -->"
                       ]) do
                    [prelude, _, postlude] ->
                      prelude <> package_content <> postlude

                    _ ->
                      acc <> "\n" <> package_content
                  end
                end)
                |> then(fn content ->
                  prelude <>
                    "<!-- usage-rules-start -->\n" <>
                    content <>
                    "\n<!-- usage-rules-end -->" <>
                    postlude
                end)

              _ ->
                current_contents <>
                  "\n<!-- usage-rules-start -->\n" <>
                  all_rules_content <>
                  "\n<!-- usage-rules-end -->\n"
            end

          Rewrite.Source.update(source, :content, new_content)
        end
      )
    end

    defp remove_packages_from_file(igniter, file_path, packages_to_remove, link_to_folder) do
      # If using link-to-folder, also remove the individual package files
      igniter =
        if link_to_folder do
          Enum.reduce(packages_to_remove, igniter, fn package_name, acc ->
            package_file_path = Path.join(link_to_folder, "#{package_name}.md")

            if Igniter.exists?(acc, package_file_path) do
              Igniter.rm(acc, package_file_path)
            else
              acc
            end
          end)
        else
          igniter
        end

      Igniter.update_file(igniter, file_path, fn source ->
        current_contents = Rewrite.Source.get(source, :content)

        new_content =
          Enum.reduce(packages_to_remove, current_contents, fn package_name, acc ->
            remove_package_from_content(acc, package_name)
          end)
          |> clean_empty_package_rules_section()

        Rewrite.Source.update(source, :content, new_content)
      end)
    end

    defp remove_package_from_content(content, package_name) do
      package_start_marker = "<!-- #{package_name}-start -->\n"
      package_end_marker = "\n<!-- #{package_name}-end -->"

      case String.split(content, [package_start_marker, package_end_marker]) do
        [prelude, _package_content, postlude] ->
          # Remove the package section completely, handling newlines properly
          cleaned_prelude = String.trim_trailing(prelude)
          cleaned_postlude = String.trim_leading(postlude)

          if cleaned_postlude == "" do
            cleaned_prelude
          else
            cleaned_prelude <> "\n" <> cleaned_postlude
          end

        _ ->
          # Package not found, return content unchanged
          content
      end
    end

    defp clean_empty_package_rules_section(content) do
      # Handle both cases: empty section and section with only whitespace
      case String.split(content, "<!-- usage-rules-start -->") do
        [prelude, remainder] ->
          case String.split(remainder, "<!-- usage-rules-end -->") do
            [package_section, postlude] ->
              # Check if package section is empty or only contains whitespace
              if String.trim(package_section) == "" do
                # Remove the entire usage-rules section if empty
                cleaned_prelude = String.trim_trailing(prelude)
                cleaned_postlude = String.trim_leading(postlude)

                if cleaned_postlude == "" do
                  cleaned_prelude
                else
                  cleaned_prelude <> "\n\n" <> cleaned_postlude
                end
              else
                # Keep the usage-rules section
                prelude <>
                  "<!-- usage-rules-start -->" <>
                  package_section <> "<!-- usage-rules-end -->" <> postlude
              end

            _ ->
              # No end marker found
              content
          end

        _ ->
          # No usage-rules section found
          content
      end
    end

    defp get_package_status_in_file(
           igniter,
           name,
           package_rules_content,
           file_content,
           link_to_folder
         ) do
      package_start_marker = "<!-- #{name}-start -->"
      package_end_marker = "<!-- #{name}-end -->"

      case String.split(file_content, [package_start_marker, package_end_marker]) do
        [_, current_package_content, _] ->
          # Package is present in file, check if content matches
          expected_content =
            if link_to_folder do
              "\n## #{name} usage\n@#{link_to_folder}/#{name}.md\n"
            else
              "\n## #{name} usage\n" <> package_rules_content <> "\n"
            end

          if String.trim(current_package_content) == String.trim(expected_content) do
            # If using link-to-folder, also check the linked file exists and matches
            if link_to_folder do
              check_linked_file_status(igniter, name, package_rules_content, link_to_folder)
            else
              "present"
            end
          else
            "stale"
          end

        _ ->
          # Package not found in file
          "missing"
      end
    end

    defp check_linked_file_status(igniter, name, expected_content, link_to_folder) do
      linked_file_path = Path.join(link_to_folder, "#{name}.md")

      if Igniter.exists?(igniter, linked_file_path) do
        actual_content =
          case Rewrite.source(igniter.rewrite, linked_file_path) do
            {:ok, source} ->
              Rewrite.Source.get(source, :content)

            {:error, _} ->
              if File.exists?(linked_file_path) do
                File.read!(linked_file_path)
              else
                ""
              end
          end

        if String.trim(actual_content) == String.trim(expected_content) do
          "present"
        else
          "stale"
        end
      else
        "stale"
      end
    end

    defp colorize_status("present"), do: "#{IO.ANSI.green()}present#{IO.ANSI.reset()}"
    defp colorize_status("stale"), do: "#{IO.ANSI.yellow()}stale#{IO.ANSI.reset()}"
    defp colorize_status("missing"), do: "#{IO.ANSI.red()}missing#{IO.ANSI.reset()}"
  end
else
  defmodule Mix.Tasks.UsageRules.Sync do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'usage_rules.sync' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
