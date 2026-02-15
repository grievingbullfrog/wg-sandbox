defmodule WargameCore.Scenario.ActionProfile do
  @moduledoc """
  Pure struct representing an action profile for a scenario.

  An action profile defines:
  - What action choices a unit has each turn (move & fire, fire only, hold, etc.)
  - The phase sequence for the turn
  - Which rules module governs resolution

  This is era-pluggable: WW2, Civil War, Napoleonic, etc. each define different
  action options and phase sequences.
  """

  alias WargameCore.Turns.Phase

  @type action_option :: %{
          id: atom() | String.t(),
          move: boolean(),
          fire: boolean(),
          melee: boolean(),
          move_penalty: float() | nil,
          entrench: boolean() | nil
        }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          era: String.t(),
          action_options: [action_option()],
          phase_sequence: [Phase.t()],
          rules_module: module() | String.t()
        }

  defstruct [
    :id,
    :name,
    :era,
    :rules_module,
    action_options: [],
    phase_sequence: []
  ]

  @doc """
  Creates a new ActionProfile from a map of attributes.

  Accepts raw data (e.g. from DB seed) and normalizes action_options
  and phase_sequence into proper structs.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    action_options = normalize_action_options(Map.get(attrs, :action_options, []))
    phase_sequence = normalize_phase_sequence(Map.get(attrs, :phase_sequence, []))

    %__MODULE__{
      id: Map.get(attrs, :id),
      name: Map.fetch!(attrs, :name),
      era: Map.fetch!(attrs, :era),
      action_options: action_options,
      phase_sequence: phase_sequence,
      rules_module: Map.fetch!(attrs, :rules_module)
    }
  end

  @doc """
  Creates the default WW2 Standard action profile.
  """
  @spec ww2_standard() :: t()
  def ww2_standard do
    new(%{
      name: "WW2 Standard",
      era: "ww2",
      action_options: [
        %{id: :move_and_fire, move: true, fire: true, melee: false, move_penalty: 0.5},
        %{id: :fire_only, move: false, fire: true, melee: false},
        %{id: :move_only, move: true, fire: false, melee: false},
        %{id: :hold, move: false, fire: false, melee: false, entrench: true},
        %{id: :assault, move: true, fire: true, melee: true, move_penalty: 0.5}
      ],
      phase_sequence: Phase.standard_phases(),
      rules_module: WargameCore.Rules.StandardRules
    })
  end

  @doc """
  Returns the list of available action choices for a unit in the given phase.

  During movement phase, actions that allow movement are relevant.
  During combat phase, actions that allow fire are relevant.
  """
  @spec available_actions(t(), Phase.t()) :: [action_option()]
  def available_actions(%__MODULE__{action_options: options}, %Phase{} = phase) do
    Enum.filter(options, fn action ->
      cond do
        phase.allows_movement and phase.allows_combat ->
          # Exploitation-like phase: both movement and combat
          action.move || action.fire
        phase.allows_movement ->
          action.move || (!action.move && !action.fire && !action.melee)
        phase.allows_combat ->
          action.fire || action.melee || (!action.move && !action.fire && !action.melee)
        phase.allows_orders ->
          # Command phase: all actions available for selection
          true
        true ->
          # Non-action phases (supply, end): no actions
          false
      end
    end)
  end

  @doc """
  Returns true if the given action option allows movement.
  """
  @spec action_allows_movement?(action_option()) :: boolean()
  def action_allows_movement?(%{move: move}), do: move == true
  def action_allows_movement?(_), do: false

  @doc """
  Returns true if the given action option allows fire/ranged combat.
  """
  @spec action_allows_fire?(action_option()) :: boolean()
  def action_allows_fire?(%{fire: fire}), do: fire == true
  def action_allows_fire?(_), do: false

  @doc """
  Returns true if the given action option allows melee combat.
  """
  @spec action_allows_melee?(action_option()) :: boolean()
  def action_allows_melee?(%{melee: melee}), do: melee == true
  def action_allows_melee?(_), do: false

  @doc """
  Returns the movement penalty multiplier for the given action option.

  For example, move_and_fire has a 0.5 penalty (half movement).
  Actions without a penalty return 1.0 (full movement).
  """
  @spec movement_penalty_for(action_option()) :: float()
  def movement_penalty_for(%{move_penalty: penalty}) when is_number(penalty), do: penalty
  def movement_penalty_for(_), do: 1.0

  @doc """
  Returns true if the action allows the unit to entrench.
  """
  @spec action_allows_entrench?(action_option()) :: boolean()
  def action_allows_entrench?(%{entrench: true}), do: true
  def action_allows_entrench?(_), do: false

  @doc """
  Looks up an action option by its id.
  Returns nil if not found.
  """
  @spec get_action(t(), atom() | String.t()) :: action_option() | nil
  def get_action(%__MODULE__{action_options: options}, action_id) do
    Enum.find(options, fn action -> action.id == action_id end)
  end

  @doc """
  Returns the phases from the profile's sequence, sorted by order.
  """
  @spec phases(t()) :: [Phase.t()]
  def phases(%__MODULE__{phase_sequence: phases}), do: phases

  # --- Private helpers ---

  defp normalize_action_options(options) when is_list(options) do
    Enum.map(options, &normalize_action_option/1)
  end

  defp normalize_action_options(_), do: []

  defp normalize_action_option(%{} = action) do
    %{
      id: normalize_id(Map.get(action, :id) || Map.get(action, "id")),
      move: Map.get(action, :move, Map.get(action, "move", false)),
      fire: Map.get(action, :fire, Map.get(action, "fire", false)),
      melee: Map.get(action, :melee, Map.get(action, "melee", false)),
      move_penalty: Map.get(action, :move_penalty, Map.get(action, "move_penalty")),
      entrench: Map.get(action, :entrench, Map.get(action, "entrench"))
    }
  end

  defp normalize_phase_sequence(phases) when is_list(phases) do
    phases
    |> Enum.with_index()
    |> Enum.map(fn {phase, idx} -> normalize_phase(phase, idx) end)
    |> Enum.sort_by(& &1.order)
  end

  defp normalize_phase_sequence(_), do: []

  defp normalize_phase(%Phase{} = phase, _idx), do: phase

  defp normalize_phase(%{} = phase_data, idx) do
    id = normalize_id(Map.get(phase_data, :id) || Map.get(phase_data, "id"))
    name = Map.get(phase_data, :name, Map.get(phase_data, "name", "Phase #{idx}"))

    Phase.new(id, name, idx,
      allows_movement: Map.get(phase_data, :allows_movement, Map.get(phase_data, "allows_movement", false)),
      allows_combat: Map.get(phase_data, :allows_combat, Map.get(phase_data, "allows_combat", false)),
      allows_orders: Map.get(phase_data, :allows_orders, Map.get(phase_data, "allows_orders", false)),
      is_optional: Map.get(phase_data, :is_optional, Map.get(phase_data, "is_optional", false))
    )
  end

  defp normalize_id(id) when is_atom(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_atom(id)
  defp normalize_id(_), do: :unknown
end
