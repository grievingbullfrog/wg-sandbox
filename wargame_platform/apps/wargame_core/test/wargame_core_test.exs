defmodule WargameCoreTest do
  use ExUnit.Case, async: true

  doctest WargameCore
  doctest WargameCore.Hex.Coord
  doctest WargameCore.Hex.Grid
end
