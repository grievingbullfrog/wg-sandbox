defmodule WargameCore.Units.UnitInstance do
  @moduledoc """
  A specific unit placed in a game - the runtime state of a unit.

  A UnitInstance references a UnitTemplate for base stats and tracks the
  unit's current state: position, strength, ammo, fuel, morale, status flags,
  and attachments.

  All functions are pure - they take a unit and return a modified unit.
  No side effects, no GenServer, no Ecto.
  """

  alias WargameCore.Units.UnitTemplate

  @max_entrenchment 3
  @experience_bonus_per_level 0.05
  @entrenchment_defense_per_level 1
  @disruption_defense_penalty 0.5
  @disruption_movement_penalty 0.5

  @type t :: %__MODULE__{
          id: String.t(),
          unit_template_id: String.t(),
          template: UnitTemplate.t(),
          name: String.t(),
          side: atom(),
          force: atom(),
          position: term() | nil,
          current_strength: non_neg_integer(),
          current_ammo: non_neg_integer(),
          current_fuel: non_neg_integer(),
          experience: non_neg_integer(),
          morale: non_neg_integer(),
          entrenchment: non_neg_integer(),
          movement_remaining: non_neg_integer(),
          has_attacked: boolean(),
          has_moved: boolean(),
          is_disrupted: boolean(),
          is_routed: boolean(),
          attachments: [UnitTemplate.t()],
          arrives_turn: non_neg_integer() | nil,
          deploy_hex: term() | nil
        }

  defstruct [
    :id,
    :unit_template_id,
    :template,
    :name,
    :side,
    :force,
    :position,
    current_strength: 0,
    current_ammo: 0,
    current_fuel: 0,
    experience: 0,
    morale: 50,
    entrenchment: 0,
    movement_remaining: 0,
    has_attacked: false,
    has_moved: false,
    is_disrupted: false,
    is_routed: false,
    attachments: [],
    arrives_turn: nil,
    deploy_hex: nil
  ]

  @doc """
  Creates a new UnitInstance from a UnitTemplate and deployment options.

  Options:
  - `:id` - Custom ID (auto-generated if not provided)
  - `:name` - Display name (required)
  - `:side` - Side atom (required)
  - `:force` - Force atom (required)
  - `:position` - Initial hex position (nil if not yet deployed)
  - `:current_strength` - Override starting strength (defaults to template max)
  - `:current_ammo` - Override starting ammo
  - `:current_fuel` - Override starting fuel
  - `:experience` - Experience level 0-5 (default 0)
  - `:morale` - Morale 0-100 (default 50)
  - `:arrives_turn` - Turn number for reinforcement arrival
  - `:deploy_hex` - Hex coordinate for deployment
  """
  @spec new(UnitTemplate.t(), map()) :: t()
  def new(%UnitTemplate{} = template, opts) when is_map(opts) do
    id = Map.get(opts, :id) || generate_id()

    %__MODULE__{
      id: id,
      unit_template_id: template.id,
      template: template,
      name: Map.fetch!(opts, :name),
      side: Map.fetch!(opts, :side),
      force: Map.fetch!(opts, :force),
      position: Map.get(opts, :position),
      current_strength: Map.get(opts, :current_strength, template.max_strength),
      current_ammo: Map.get(opts, :current_ammo, template.max_ammo),
      current_fuel: Map.get(opts, :current_fuel, template.max_fuel),
      experience: Map.get(opts, :experience, 0),
      morale: Map.get(opts, :morale, 50),
      entrenchment: 0,
      movement_remaining: template.movement_points,
      has_attacked: false,
      has_moved: false,
      is_disrupted: false,
      is_routed: false,
      attachments: [],
      arrives_turn: Map.get(opts, :arrives_turn),
      deploy_hex: Map.get(opts, :deploy_hex)
    }
  end

  @doc "Returns the strength ratio (current / max), a float between 0.0 and 1.0."
  @spec strength_ratio(t()) :: float()
  def strength_ratio(%__MODULE__{current_strength: current, template: template}) do
    current / template.max_strength
  end

  @doc "Returns true if the unit has strength > 0."
  @spec is_alive?(t()) :: boolean()
  def is_alive?(%__MODULE__{current_strength: s}), do: s > 0

  @doc """
  Returns effective soft attack value, scaled by strength ratio and experience.
  """
  @spec effective_attack_soft(t()) :: non_neg_integer()
  def effective_attack_soft(%__MODULE__{} = unit) do
    base = UnitTemplate.combat_effectiveness(unit.template, :attack_soft, strength_ratio(unit))
    apply_experience_bonus(base, unit.experience)
  end

  @doc """
  Returns effective hard attack value, scaled by strength ratio and experience.
  """
  @spec effective_attack_hard(t()) :: non_neg_integer()
  def effective_attack_hard(%__MODULE__{} = unit) do
    base = UnitTemplate.combat_effectiveness(unit.template, :attack_hard, strength_ratio(unit))
    apply_experience_bonus(base, unit.experience)
  end

  @doc """
  Returns effective defense value, scaled by strength, entrenchment, experience, and status.
  Disrupted units suffer a defense penalty. Entrenchment adds a flat bonus.
  """
  @spec effective_defense(t()) :: non_neg_integer()
  def effective_defense(%__MODULE__{} = unit) do
    base = UnitTemplate.combat_effectiveness(unit.template, :defense, strength_ratio(unit))
    base_with_exp = apply_experience_bonus(base, unit.experience)
    with_entrenchment = base_with_exp + unit.entrenchment * @entrenchment_defense_per_level

    if unit.is_disrupted do
      max(round(with_entrenchment * @disruption_defense_penalty), 1)
    else
      with_entrenchment
    end
  end

  @doc """
  Applies damage to the unit, reducing strength. May cause disruption based on morale.
  """
  @spec apply_damage(t(), non_neg_integer()) :: t()
  def apply_damage(%__MODULE__{} = unit, steps) when is_integer(steps) and steps >= 0 do
    new_strength = max(unit.current_strength - steps, 0)
    unit = %{unit | current_strength: new_strength}

    # Morale check for disruption: chance = damage_ratio * (100 - morale) / 100
    if new_strength > 0 and not unit.is_disrupted do
      damage_ratio = steps / unit.template.max_strength
      disruption_chance = damage_ratio * (100 - unit.morale) / 100

      if :rand.uniform() < disruption_chance do
        %{unit | is_disrupted: true}
      else
        unit
      end
    else
      unit
    end
  end

  @doc """
  Restores ammo and fuel to template maximums.
  """
  @spec resupply(t()) :: t()
  def resupply(%__MODULE__{} = unit) do
    %{unit | current_ammo: unit.template.max_ammo, current_fuel: unit.template.max_fuel}
  end

  @doc """
  Attempts to rally from disruption or rout.
  Routed units rally to disrupted. Disrupted units rally to normal.
  Rally always succeeds with 100 morale; lower morale has a chance of failure.
  """
  @spec rally(t()) :: t()
  def rally(%__MODULE__{is_routed: true} = unit) do
    # Routed -> disrupted (always succeeds, but doesn't clear disrupted)
    %{unit | is_routed: false}
  end

  def rally(%__MODULE__{is_disrupted: true} = unit) do
    # Rally check: succeed if morale roll passes
    rally_chance = unit.morale / 100
    if :rand.uniform() <= rally_chance do
      %{unit | is_disrupted: false}
    else
      unit
    end
  end

  def rally(%__MODULE__{} = unit), do: unit

  @doc """
  Increases entrenchment by 1, up to max (3).
  Only works for units whose template allows entrenching.
  """
  @spec entrench(t()) :: t()
  def entrench(%__MODULE__{} = unit) do
    if unit.template.can_entrench do
      %{unit | entrenchment: min(unit.entrenchment + 1, @max_entrenchment)}
    else
      unit
    end
  end

  @doc """
  Resets per-turn state: movement, attack flag, move flag.
  Disrupted units get half movement. Routed units get none.
  """
  @spec reset_turn_state(t()) :: t()
  def reset_turn_state(%__MODULE__{} = unit) do
    movement =
      cond do
        unit.is_routed -> 0
        unit.is_disrupted -> div(unit.template.movement_points, round(1 / @disruption_movement_penalty))
        true -> unit.template.movement_points
      end

    %{unit | movement_remaining: movement, has_attacked: false, has_moved: false}
  end

  @doc """
  Reduces movement_remaining by the given cost. Sets has_moved to true.
  """
  @spec spend_movement(t(), non_neg_integer()) :: t()
  def spend_movement(%__MODULE__{} = unit, cost) when is_integer(cost) and cost >= 0 do
    %{unit | movement_remaining: max(unit.movement_remaining - cost, 0), has_moved: true}
  end

  @doc "Returns true if the unit can still move this turn."
  @spec can_move?(t()) :: boolean()
  def can_move?(%__MODULE__{movement_remaining: mr, is_routed: routed}) do
    mr > 0 and not routed
  end

  @doc "Returns true if the unit can attack this turn."
  @spec can_attack?(t()) :: boolean()
  def can_attack?(%__MODULE__{has_attacked: attacked, is_disrupted: disrupted, is_routed: routed}) do
    not attacked and not disrupted and not routed
  end

  @doc "Adds a UnitTemplate as an attachment to this unit."
  @spec attach(t(), UnitTemplate.t()) :: t()
  def attach(%__MODULE__{} = unit, %UnitTemplate{} = attachment) do
    %{unit | attachments: unit.attachments ++ [attachment]}
  end

  @doc "Removes an attachment by its template ID."
  @spec detach(t(), String.t()) :: t()
  def detach(%__MODULE__{} = unit, template_id) do
    %{unit | attachments: Enum.reject(unit.attachments, &(&1.id == template_id))}
  end

  @doc """
  Returns the sum of a stat across all attachments.
  Used to add attachment bonuses to the unit's combat stats.
  """
  @spec attachment_bonus(t(), atom()) :: non_neg_integer()
  def attachment_bonus(%__MODULE__{attachments: attachments}, stat) do
    Enum.reduce(attachments, 0, fn template, acc ->
      acc + Map.get(template, stat, 0)
    end)
  end

  # Private helpers

  defp apply_experience_bonus(base, experience) do
    round(base * (1 + experience * @experience_bonus_per_level))
  end

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
end
