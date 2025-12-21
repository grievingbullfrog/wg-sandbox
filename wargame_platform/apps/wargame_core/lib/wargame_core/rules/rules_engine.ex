defmodule WargameCore.Rules.RulesEngine do
  @moduledoc """
  Behaviour defining the rules engine interface.

  The rules engine validates and executes game actions according to scenario-specific rules.
  Different scenarios can implement different rule sets while maintaining a common interface.

  ## Responsibilities

  - Validate proposed actions (can this unit move here?)
  - Execute validated actions (apply state changes)
  - Resolve combat (calculate odds, apply results)
  - Check victory conditions
  - Enforce phase restrictions

  ## Implementation Pattern

  Scenarios implement this behaviour to define their specific rules:

      defmodule MyScenario.Rules do
        @behaviour WargameCore.Rules.RulesEngine

        @impl true
        def validate_movement(game_state, unit_id, path) do
          # Scenario-specific movement validation
        end
      end

  ## Action Flow

  1. Player requests action (move, attack, etc.)
  2. Rules engine validates action
  3. If valid, rules engine executes action
  4. Game state is updated
  5. Results are broadcast to players
  """

  alias WargameCore.Hex.Coord

  @type game_state :: map()
  @type unit_id :: String.t()
  @type action_result :: {:ok, game_state()} | {:error, atom() | String.t()}
  @type validation_result :: :ok | {:error, atom() | String.t()}

  @doc """
  Validates if a unit can move along the given path.

  Returns :ok if the movement is valid, or {:error, reason} if not.
  """
  @callback validate_movement(game_state(), unit_id(), [Coord.t()]) :: validation_result()

  @doc """
  Executes a movement action, updating the game state.

  Assumes the movement has already been validated.
  """
  @callback execute_movement(game_state(), unit_id(), [Coord.t()]) :: action_result()

  @doc """
  Validates if an attack can be made.

  Checks:
  - Attacker(s) can attack in current phase
  - Target is valid enemy
  - Range/adjacency requirements
  - Ammunition/supply status
  """
  @callback validate_attack(game_state(), [unit_id()], Coord.t()) :: validation_result()

  @doc """
  Resolves an attack and returns the updated game state.

  Calculates combat odds, rolls for results, applies casualties,
  handles retreats, advances, etc.
  """
  @callback resolve_attack(game_state(), [unit_id()], Coord.t()) :: action_result()

  @doc """
  Checks if the game has ended and determines the winner.

  Returns:
  - {:ongoing, scores} - Game continues
  - {:victory, winner, reason} - Decisive victory
  - {:draw, reason} - Game ends in draw
  """
  @callback check_victory(game_state()) ::
              {:ongoing, map()}
              | {:victory, atom(), String.t()}
              | {:draw, String.t()}

  @doc """
  Validates if an action is allowed in the current phase.
  """
  @callback validate_phase_action(game_state(), atom()) :: validation_result()

  @doc """
  Returns the movement cost for a unit to enter a hex.

  Takes into account:
  - Unit type/category
  - Terrain
  - Entry direction (for edge features)
  - Weather (if applicable)
  """
  @callback movement_cost(game_state(), unit_id(), Coord.t(), Coord.t() | nil) ::
              number() | :impassable

  @doc """
  Calculates combat odds for an attack.

  Returns a tuple of {attacker_strength, defender_strength, odds_ratio, modifiers}
  """
  @callback calculate_combat_odds(game_state(), [unit_id()], Coord.t()) ::
              {:ok, map()} | {:error, atom()}

  @doc """
  Checks if a unit can see another unit/hex (line of sight).
  """
  @callback has_line_of_sight?(game_state(), unit_id(), Coord.t()) :: boolean()

  @doc """
  Returns the stacking limit for a hex.

  Stacking limits may vary by terrain and side.
  """
  @callback stacking_limit(game_state(), Coord.t(), atom()) :: pos_integer()

  @doc """
  Validates stacking after a proposed move.
  """
  @callback validate_stacking(game_state(), Coord.t(), atom()) :: validation_result()

  @doc """
  Called at the start of a turn. Handles reinforcements, supply, etc.
  """
  @callback on_turn_start(game_state(), pos_integer()) :: game_state()

  @doc """
  Called at the end of a turn. Handles cleanup, scoring, etc.
  """
  @callback on_turn_end(game_state(), pos_integer()) :: game_state()

  @doc """
  Called at the start of a phase. Handles phase-specific setup.
  """
  @callback on_phase_start(game_state(), atom()) :: game_state()

  @doc """
  Called at the end of a phase. Handles phase-specific cleanup.
  """
  @callback on_phase_end(game_state(), atom()) :: game_state()

  # Optional callbacks with default implementations
  @optional_callbacks [
    on_turn_start: 2,
    on_turn_end: 2,
    on_phase_start: 2,
    on_phase_end: 2
  ]
end
