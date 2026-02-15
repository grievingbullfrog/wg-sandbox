defmodule WargameCore.Units.UnitTemplate do
  @moduledoc """
  Pure struct representing a unit type definition.

  A UnitTemplate is the blueprint for a unit - it defines the stats, capabilities,
  and category of a unit type (e.g., "Panzer IV", "Rifle Platoon"). UnitInstances
  reference a template to get their base stats.

  This is a pure data module with no Ecto dependency - it lives in wargame_core
  and can be constructed from database records or test data equally.
  """

  @valid_categories [
    :infantry, :armor, :motorized, :artillery, :recon, :engineer,
    :anti_tank, :anti_air, :cavalry, :naval, :air
  ]

  @valid_movement_types [:foot, :wheeled, :tracked, :horse, :rail_only, :air]

  @valid_unit_sizes [
    :squad, :platoon, :company, :battalion,
    :regiment, :brigade, :division, :corps
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          nationality: String.t(),
          era: String.t(),
          category: atom(),
          unit_size: atom(),
          icon_type: String.t() | nil,
          attack_soft: non_neg_integer(),
          attack_hard: non_neg_integer(),
          defense: non_neg_integer(),
          armor: non_neg_integer(),
          movement_points: non_neg_integer(),
          movement_type: atom(),
          range: non_neg_integer(),
          spotting: pos_integer(),
          initiative: non_neg_integer(),
          max_strength: pos_integer(),
          max_ammo: non_neg_integer(),
          max_fuel: non_neg_integer(),
          can_bridge: boolean(),
          can_entrench: boolean(),
          is_organic_transport: boolean()
        }

  defstruct [
    :id,
    :name,
    :nationality,
    :era,
    :category,
    :unit_size,
    :icon_type,
    attack_soft: 0,
    attack_hard: 0,
    defense: 0,
    armor: 0,
    movement_points: 4,
    movement_type: :foot,
    range: 0,
    spotting: 1,
    initiative: 0,
    max_strength: 10,
    max_ammo: 0,
    max_fuel: 0,
    can_bridge: false,
    can_entrench: true,
    is_organic_transport: false
  ]

  @doc """
  Creates a new UnitTemplate from a map or keyword list.
  Generates an ID if not provided.
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    id = Map.get(attrs, :id) || generate_id()

    struct!(__MODULE__, Map.put(attrs, :id, id))
  end

  @doc """
  Returns the combat effectiveness of a stat scaled by the unit's current strength ratio.

  The strength ratio is `current_strength / max_strength` (0.0 to 1.0).
  Returns at least 1 for any non-zero base stat.
  """
  @spec combat_effectiveness(t(), atom(), float()) :: non_neg_integer()
  def combat_effectiveness(%__MODULE__{} = template, stat, strength_ratio)
      when is_float(strength_ratio) or is_integer(strength_ratio) do
    base = Map.get(template, stat, 0)

    if base == 0 do
      0
    else
      max(round(base * strength_ratio), 1)
    end
  end

  @doc """
  Maps the unit's category to the terrain movement cost category.

  Some unit categories (anti_tank, anti_air, cavalry) don't have their own
  terrain cost entries, so they map to a base category.
  """
  @spec terrain_category(t()) :: atom()
  def terrain_category(%__MODULE__{category: :anti_tank}), do: :infantry
  def terrain_category(%__MODULE__{category: :anti_air}), do: :infantry
  def terrain_category(%__MODULE__{category: :cavalry}), do: :infantry
  def terrain_category(%__MODULE__{category: :naval}), do: :infantry
  def terrain_category(%__MODULE__{category: :air}), do: :infantry
  def terrain_category(%__MODULE__{category: category}), do: category

  @doc """
  Returns true if this unit type is a hard target (has armor).
  Determines whether attackers use attack_hard vs attack_soft.
  """
  @spec is_hard_target?(t()) :: boolean()
  def is_hard_target?(%__MODULE__{armor: armor}), do: armor > 0

  @doc "Returns the list of valid unit categories."
  @spec valid_categories() :: [atom()]
  def valid_categories, do: @valid_categories

  @doc "Returns the list of valid movement types."
  @spec valid_movement_types() :: [atom()]
  def valid_movement_types, do: @valid_movement_types

  @doc "Returns the list of valid unit sizes."
  @spec valid_unit_sizes() :: [atom()]
  def valid_unit_sizes, do: @valid_unit_sizes

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
end
