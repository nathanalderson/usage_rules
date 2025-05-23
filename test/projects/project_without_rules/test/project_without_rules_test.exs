defmodule ProjectWithoutRulesTest do
  use ExUnit.Case
  doctest ProjectWithoutRules

  test "greets the world" do
    assert ProjectWithoutRules.hello() == :world
  end
end
