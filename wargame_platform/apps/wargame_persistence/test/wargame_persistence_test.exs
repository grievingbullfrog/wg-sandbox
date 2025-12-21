defmodule WargamePersistenceTest do
  use ExUnit.Case
  doctest WargamePersistence

  test "greets the world" do
    assert WargamePersistence.hello() == :world
  end
end
