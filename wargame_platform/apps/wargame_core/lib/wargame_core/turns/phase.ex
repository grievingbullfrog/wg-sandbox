defmodule WargameCore.Turns.Phase do
  @moduledoc """
  Defines the phases within a turn.

  A turn is divided into phases that dictate what actions are allowed.
  The sequence and available phases can be configured per scenario.

  ## Standard Phases

  1. **Command Phase** - Orders, rallying, reinforcements
  2. **Movement Phase** - Unit movement execution
  3. **Combat Phase** - Attack resolution
  4. **Exploitation Phase** - Breakthrough movement (optional)
  5. **Supply Phase** - Supply status updates (optional)
  6. **End Phase** - Victory check, turn cleanup

  ## Phase Flow

  Each phase follows a pattern:
  1. Begin phase (setup, announce to players)
  2. Player actions (within phase constraints)
  3. End phase (resolve, cleanup, advance)
  """

  @type phase_id ::
          :command
          | :movement
          | :combat
          | :exploitation
          | :supply
          | :end_phase
          | atom()

  @type t :: %__MODULE__{
          id: phase_id(),
          name: String.t(),
          description: String.t(),
          allows_movement: boolean(),
          allows_combat: boolean(),
          allows_orders: boolean(),
          is_optional: boolean(),
          order: non_neg_integer()
        }

  @enforce_keys [:id, :name, :order]
  defstruct [
    :id,
    :name,
    :order,
    description: "",
    allows_movement: false,
    allows_combat: false,
    allows_orders: false,
    is_optional: false
  ]

  @doc """
  Creates a new phase.
  """
  @spec new(phase_id(), String.t(), non_neg_integer(), keyword()) :: t()
  def new(id, name, order, opts \\ []) when is_atom(id) and is_binary(name) and order >= 0 do
    %__MODULE__{
      id: id,
      name: name,
      order: order,
      description: Keyword.get(opts, :description, ""),
      allows_movement: Keyword.get(opts, :allows_movement, false),
      allows_combat: Keyword.get(opts, :allows_combat, false),
      allows_orders: Keyword.get(opts, :allows_orders, false),
      is_optional: Keyword.get(opts, :is_optional, false)
    }
  end

  @doc """
  Returns the standard wargame phases in order.

  This is the default phase sequence for most scenarios.
  """
  @spec standard_phases() :: [t()]
  def standard_phases do
    [
      new(:command, "Command Phase", 0,
        description: "Issue orders, rally units, receive reinforcements",
        allows_orders: true
      ),
      new(:movement, "Movement Phase", 1,
        description: "Execute unit movement orders",
        allows_movement: true
      ),
      new(:combat, "Combat Phase", 2,
        description: "Resolve attacks and bombardments",
        allows_combat: true
      ),
      new(:exploitation, "Exploitation Phase", 3,
        description: "Mechanized units can move after successful combat",
        allows_movement: true,
        is_optional: true
      ),
      new(:supply, "Supply Phase", 4,
        description: "Check supply status for all units",
        is_optional: true
      ),
      new(:end_phase, "End Phase", 5,
        description: "Check victory conditions, prepare for next turn"
      )
    ]
  end

  @doc """
  Returns a simplified phase sequence (movement then combat only).

  Useful for quick games or simpler scenarios.
  """
  @spec simple_phases() :: [t()]
  def simple_phases do
    [
      new(:movement, "Movement Phase", 0,
        description: "Move your units",
        allows_movement: true
      ),
      new(:combat, "Combat Phase", 1,
        description: "Attack enemy units",
        allows_combat: true
      ),
      new(:end_phase, "End Phase", 2,
        description: "Check victory conditions"
      )
    ]
  end

  @doc """
  Checks if movement is allowed in this phase.
  """
  @spec allows_movement?(t()) :: boolean()
  def allows_movement?(%__MODULE__{allows_movement: allows}), do: allows

  @doc """
  Checks if combat is allowed in this phase.
  """
  @spec allows_combat?(t()) :: boolean()
  def allows_combat?(%__MODULE__{allows_combat: allows}), do: allows

  @doc """
  Checks if orders can be issued in this phase.
  """
  @spec allows_orders?(t()) :: boolean()
  def allows_orders?(%__MODULE__{allows_orders: allows}), do: allows

  @doc """
  Checks if this phase is optional.
  """
  @spec optional?(t()) :: boolean()
  def optional?(%__MODULE__{is_optional: optional}), do: optional
end
