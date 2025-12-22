defmodule WargameCore.Turns.PhaseTest do
  use ExUnit.Case, async: true

  alias WargameCore.Turns.Phase

  describe "new/4" do
    test "creates phase with required fields" do
      phase = Phase.new(:movement, "Movement Phase", 1)

      assert phase.id == :movement
      assert phase.name == "Movement Phase"
      assert phase.order == 1
    end

    test "defaults to no movement allowed" do
      phase = Phase.new(:test, "Test", 0)
      refute phase.allows_movement
    end

    test "defaults to no combat allowed" do
      phase = Phase.new(:test, "Test", 0)
      refute phase.allows_combat
    end

    test "defaults to no orders allowed" do
      phase = Phase.new(:test, "Test", 0)
      refute phase.allows_orders
    end

    test "defaults to non-optional" do
      phase = Phase.new(:test, "Test", 0)
      refute phase.is_optional
    end

    test "defaults to empty description" do
      phase = Phase.new(:test, "Test", 0)
      assert phase.description == ""
    end

    test "accepts allows_movement option" do
      phase = Phase.new(:movement, "Move", 0, allows_movement: true)
      assert phase.allows_movement
    end

    test "accepts allows_combat option" do
      phase = Phase.new(:combat, "Combat", 0, allows_combat: true)
      assert phase.allows_combat
    end

    test "accepts allows_orders option" do
      phase = Phase.new(:command, "Command", 0, allows_orders: true)
      assert phase.allows_orders
    end

    test "accepts is_optional option" do
      phase = Phase.new(:supply, "Supply", 0, is_optional: true)
      assert phase.is_optional
    end

    test "accepts description option" do
      phase = Phase.new(:test, "Test", 0, description: "A test phase")
      assert phase.description == "A test phase"
    end
  end

  describe "standard_phases/0" do
    test "returns list of 6 phases" do
      phases = Phase.standard_phases()
      assert length(phases) == 6
    end

    test "phases are in correct order" do
      phases = Phase.standard_phases()
      orders = Enum.map(phases, & &1.order)
      assert orders == Enum.sort(orders)
    end

    test "includes command phase with orders allowed" do
      phases = Phase.standard_phases()
      command = Enum.find(phases, &(&1.id == :command))

      assert command != nil
      assert Phase.allows_orders?(command)
      refute Phase.allows_movement?(command)
      refute Phase.allows_combat?(command)
    end

    test "includes movement phase with movement allowed" do
      phases = Phase.standard_phases()
      movement = Enum.find(phases, &(&1.id == :movement))

      assert movement != nil
      assert Phase.allows_movement?(movement)
      refute Phase.allows_combat?(movement)
    end

    test "includes combat phase with combat allowed" do
      phases = Phase.standard_phases()
      combat = Enum.find(phases, &(&1.id == :combat))

      assert combat != nil
      assert Phase.allows_combat?(combat)
      refute Phase.allows_movement?(combat)
    end

    test "exploitation phase is optional and allows movement" do
      phases = Phase.standard_phases()
      exploitation = Enum.find(phases, &(&1.id == :exploitation))

      assert exploitation != nil
      assert Phase.optional?(exploitation)
      assert Phase.allows_movement?(exploitation)
    end

    test "supply phase is optional" do
      phases = Phase.standard_phases()
      supply = Enum.find(phases, &(&1.id == :supply))

      assert supply != nil
      assert Phase.optional?(supply)
    end

    test "end phase exists" do
      phases = Phase.standard_phases()
      end_phase = Enum.find(phases, &(&1.id == :end_phase))

      assert end_phase != nil
      refute Phase.allows_movement?(end_phase)
      refute Phase.allows_combat?(end_phase)
      refute Phase.allows_orders?(end_phase)
    end
  end

  describe "simple_phases/0" do
    test "returns list of 3 phases" do
      phases = Phase.simple_phases()
      assert length(phases) == 3
    end

    test "phases are in correct order" do
      phases = Phase.simple_phases()
      orders = Enum.map(phases, & &1.order)
      assert orders == Enum.sort(orders)
    end

    test "includes movement phase first" do
      phases = Phase.simple_phases()
      first = hd(phases)

      assert first.id == :movement
      assert Phase.allows_movement?(first)
    end

    test "includes combat phase second" do
      phases = Phase.simple_phases()
      second = Enum.at(phases, 1)

      assert second.id == :combat
      assert Phase.allows_combat?(second)
    end

    test "includes end phase last" do
      phases = Phase.simple_phases()
      last = List.last(phases)

      assert last.id == :end_phase
    end
  end

  describe "allows_movement?/1" do
    test "returns true when movement allowed" do
      phase = Phase.new(:movement, "Move", 0, allows_movement: true)
      assert Phase.allows_movement?(phase)
    end

    test "returns false when movement not allowed" do
      phase = Phase.new(:combat, "Combat", 0, allows_combat: true)
      refute Phase.allows_movement?(phase)
    end
  end

  describe "allows_combat?/1" do
    test "returns true when combat allowed" do
      phase = Phase.new(:combat, "Combat", 0, allows_combat: true)
      assert Phase.allows_combat?(phase)
    end

    test "returns false when combat not allowed" do
      phase = Phase.new(:movement, "Move", 0, allows_movement: true)
      refute Phase.allows_combat?(phase)
    end
  end

  describe "allows_orders?/1" do
    test "returns true when orders allowed" do
      phase = Phase.new(:command, "Command", 0, allows_orders: true)
      assert Phase.allows_orders?(phase)
    end

    test "returns false when orders not allowed" do
      phase = Phase.new(:movement, "Move", 0, allows_movement: true)
      refute Phase.allows_orders?(phase)
    end
  end

  describe "optional?/1" do
    test "returns true when phase is optional" do
      phase = Phase.new(:supply, "Supply", 0, is_optional: true)
      assert Phase.optional?(phase)
    end

    test "returns false when phase is required" do
      phase = Phase.new(:movement, "Move", 0)
      refute Phase.optional?(phase)
    end
  end
end
