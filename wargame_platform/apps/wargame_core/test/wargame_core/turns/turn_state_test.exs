defmodule WargameCore.Turns.TurnStateTest do
  use ExUnit.Case, async: true

  alias WargameCore.Turns.Phase
  alias WargameCore.Turns.TurnState

  # Helper to create a fresh turn state for each test
  defp create_state(opts \\ []) do
    phases = Keyword.get(opts, :phases, Phase.standard_phases())
    sides = Keyword.get(opts, :sides, [:german, :soviet])
    state_opts = Keyword.drop(opts, [:phases, :sides])
    TurnState.new(phases, sides, state_opts)
  end

  describe "new/3" do
    test "creates state with turn 1" do
      state = create_state()
      assert state.turn_number == 1
    end

    test "starts at first phase" do
      state = create_state()
      assert state.current_phase_index == 0
    end

    test "starts with first side active" do
      state = create_state(sides: [:german, :soviet])
      assert state.active_side == :german
    end

    test "sorts phases by order" do
      unordered = [
        Phase.new(:combat, "Combat", 2),
        Phase.new(:movement, "Movement", 1),
        Phase.new(:command, "Command", 0)
      ]

      state = create_state(phases: unordered)
      phase_orders = Enum.map(state.phases, & &1.order)

      assert phase_orders == [0, 1, 2]
    end

    test "defaults to unlimited turns" do
      state = create_state()
      assert state.max_turns == :unlimited
    end

    test "accepts max_turns option" do
      state = create_state(max_turns: 10)
      assert state.max_turns == 10
    end

    test "defaults to igougo player order" do
      state = create_state()
      assert state.player_order == :igougo
    end

    test "accepts player_order option" do
      state = create_state(player_order: :alternating_phase)
      assert state.player_order == :alternating_phase
    end

    test "starts with empty turn history" do
      state = create_state()
      assert state.turn_history == []
    end

    test "starts with phase not complete" do
      state = create_state()
      refute state.phase_complete
    end
  end

  describe "current_phase/1" do
    test "returns first phase at start" do
      state = create_state()
      phase = TurnState.current_phase(state)

      assert phase.order == 0
    end

    test "returns correct phase after advancing" do
      state = create_state()
      {:ok, state} = TurnState.advance_phase(state)
      phase = TurnState.current_phase(state)

      assert phase.order == 1
    end
  end

  describe "active_side/1" do
    test "returns active side" do
      state = create_state(sides: [:blue, :red])
      assert TurnState.active_side(state) == :blue
    end
  end

  describe "is_active_side?/2" do
    test "returns true for active side" do
      state = create_state(sides: [:german, :soviet])
      assert TurnState.is_active_side?(state, :german)
    end

    test "returns false for inactive side" do
      state = create_state(sides: [:german, :soviet])
      refute TurnState.is_active_side?(state, :soviet)
    end
  end

  describe "advance_phase/1 with igougo" do
    test "advances to next phase" do
      state = create_state(player_order: :igougo)
      {:ok, new_state} = TurnState.advance_phase(state)

      assert new_state.current_phase_index == 1
    end

    test "keeps same side for next phase" do
      state = create_state(sides: [:german, :soviet], player_order: :igougo)
      {:ok, new_state} = TurnState.advance_phase(state)

      assert new_state.active_side == :german
    end

    test "switches side after all phases complete" do
      phases = Phase.simple_phases()
      state = create_state(phases: phases, sides: [:german, :soviet], player_order: :igougo)

      # Advance through all 3 phases
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)

      assert state.active_side == :soviet
      assert state.current_phase_index == 0
    end

    test "advances turn after all sides complete" do
      phases = Phase.simple_phases()
      state = create_state(phases: phases, sides: [:german, :soviet], player_order: :igougo)

      # German's 3 phases
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)

      # Soviet's 3 phases
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:end_of_turn, state} = TurnState.advance_phase(state)

      assert state.turn_number == 2
      assert state.active_side == :german
    end

    test "returns end_of_game when max turns reached" do
      phases = Phase.simple_phases()

      state =
        create_state(
          phases: phases,
          sides: [:german, :soviet],
          player_order: :igougo,
          max_turns: 1
        )

      # Complete turn 1
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:end_of_game, state} = TurnState.advance_phase(state)

      assert state.turn_number == 2
    end

    test "records turn in history" do
      phases = Phase.simple_phases()
      state = create_state(phases: phases, sides: [:player], player_order: :igougo)

      # Complete turn 1
      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)
      {:end_of_turn, state} = TurnState.advance_phase(state)

      assert length(state.turn_history) == 1
      assert hd(state.turn_history).turn == 1
    end
  end

  describe "advance_phase/1 with alternating_phase" do
    test "alternates sides within same phase" do
      phases = Phase.simple_phases()

      state =
        create_state(phases: phases, sides: [:german, :soviet], player_order: :alternating_phase)

      # First player in phase 1
      assert state.active_side == :german

      {:ok, state} = TurnState.advance_phase(state)

      # Second player in phase 1
      assert state.active_side == :soviet
      assert state.current_phase_index == 0
    end

    test "advances phase after all sides act" do
      phases = Phase.simple_phases()

      state =
        create_state(phases: phases, sides: [:german, :soviet], player_order: :alternating_phase)

      {:ok, state} = TurnState.advance_phase(state)
      {:ok, state} = TurnState.advance_phase(state)

      # Should now be in phase 2 with first player
      assert state.current_phase_index == 1
      assert state.active_side == :german
    end
  end

  describe "complete_phase/1" do
    test "marks phase as complete" do
      state = create_state()
      refute state.phase_complete

      updated = TurnState.complete_phase(state)
      assert updated.phase_complete
    end
  end

  describe "skip_phase/1" do
    test "skips optional phase" do
      phases = [
        Phase.new(:movement, "Move", 0, allows_movement: true),
        Phase.new(:optional, "Optional", 1, is_optional: true),
        Phase.new(:end, "End", 2)
      ]

      state = create_state(phases: phases, sides: [:player])
      {:ok, state} = TurnState.advance_phase(state)

      # Now at optional phase
      assert TurnState.current_phase(state).id == :optional

      {:ok, state} = TurnState.skip_phase(state)
      assert TurnState.current_phase(state).id == :end
    end

    test "returns error for non-optional phase" do
      phases = [
        Phase.new(:required, "Required", 0),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases, sides: [:player])

      assert {:error, :not_optional} = TurnState.skip_phase(state)
    end
  end

  describe "can_move?/1" do
    test "returns true during movement phase" do
      phases = [
        Phase.new(:movement, "Move", 0, allows_movement: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      assert TurnState.can_move?(state)
    end

    test "returns false during non-movement phase" do
      phases = [
        Phase.new(:command, "Command", 0, allows_orders: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      refute TurnState.can_move?(state)
    end
  end

  describe "can_attack?/1" do
    test "returns true during combat phase" do
      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      assert TurnState.can_attack?(state)
    end

    test "returns false during non-combat phase" do
      phases = [
        Phase.new(:movement, "Move", 0, allows_movement: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      refute TurnState.can_attack?(state)
    end
  end

  describe "can_order?/1" do
    test "returns true during command phase" do
      phases = [
        Phase.new(:command, "Command", 0, allows_orders: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      assert TurnState.can_order?(state)
    end

    test "returns false during non-command phase" do
      phases = [
        Phase.new(:movement, "Move", 0, allows_movement: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_state(phases: phases)
      refute TurnState.can_order?(state)
    end
  end

  describe "summary/1" do
    test "returns map with current state info" do
      state = create_state(sides: [:german, :soviet], max_turns: 10)
      summary = TurnState.summary(state)

      assert summary.turn == 1
      assert summary.max_turns == 10
      assert summary.active_side == :german
      assert is_binary(summary.phase)
      assert is_atom(summary.phase_id)
      assert is_boolean(summary.can_move)
      assert is_boolean(summary.can_attack)
      assert is_boolean(summary.can_order)
    end
  end

  describe "game_over?/1" do
    test "returns false when turns unlimited" do
      state = create_state(max_turns: :unlimited)
      refute TurnState.game_over?(state)
    end

    test "returns false when under max turns" do
      state = create_state(max_turns: 10)
      refute TurnState.game_over?(state)
    end

    test "returns true when over max turns" do
      state = %{create_state(max_turns: 5) | turn_number: 6}
      assert TurnState.game_over?(state)
    end
  end
end
