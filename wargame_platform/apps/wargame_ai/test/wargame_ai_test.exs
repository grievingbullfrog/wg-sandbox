defmodule WargameAiTest do
  use ExUnit.Case
  doctest WargameAi

  test "greets the world" do
    assert WargameAi.hello() == :world
  end
end
