defmodule UsageRulesTest do
  use ExUnit.Case
  doctest UsageRules

  test "greets the world" do
    assert UsageRules.hello() == :world
  end
end
