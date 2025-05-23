defmodule ProjectWithRulesTest do
  use ExUnit.Case
  doctest ProjectWithRules

  test "greets the world" do
    assert ProjectWithRules.hello() == :world
  end
end
