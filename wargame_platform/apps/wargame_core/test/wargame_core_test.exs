defmodule WargameCoreTest do
  use ExUnit.Case
  doctest WargameCore

  test "greets the world" do
    assert WargameCore.hello() == :world
  end
end
