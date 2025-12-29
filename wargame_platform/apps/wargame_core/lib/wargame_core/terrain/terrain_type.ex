defmodule WargameCore.Terrain.TerrainType do
  @moduledoc """
  Terrain type definitions and their effects on movement and combat.

  Each terrain type has:
  - Movement costs per unit category
  - Defense modifiers for combat
  - Line of sight properties
  - Special attributes (concealment, fortifiable, etc.)
  """

  @type unit_category ::
          :infantry
          | :armor
          | :motorized
          | :artillery
          | :recon
          | :engineer
          | :leader
          | :fighter
          | :bomber
          | :transport_air

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          movement_costs: %{unit_category() => number() | :impassable},
          defense_modifier: integer(),
          blocks_los: boolean(),
          concealment: boolean(),
          fortifiable: boolean(),
          color: integer()
        }

  @enforce_keys [:id, :name]
  defstruct [
    :id,
    :name,
    movement_costs: %{},
    defense_modifier: 0,
    blocks_los: false,
    concealment: false,
    fortifiable: true,
    color: 0x808080
  ]

  @doc """
  Returns the default movement cost for a terrain type and unit category.
  Returns :impassable if the unit cannot enter the terrain.
  """
  @spec movement_cost(t(), unit_category()) :: number() | :impassable
  def movement_cost(%__MODULE__{movement_costs: costs}, category) do
    Map.get(costs, category, default_movement_cost(category))
  end

  defp default_movement_cost(_category), do: 1

  @doc """
  Returns all predefined terrain types.
  """
  @spec all() :: [t()]
  def all do
    [
      clear(),
      forest_pine(),
      forest_deciduous(),
      marsh(),
      orchard(),
      light_urban(),
      heavy_urban(),
      industrial(),
      desert(),
      semi_arid(),
      tundra(),
      arctic(),
      freshwater_lake(),
      frozen_lake(),
      ocean(),
      frozen_ocean()
    ]
  end

  @doc """
  Returns a terrain type by its ID.
  """
  @spec get(atom()) :: t() | nil
  def get(id) do
    Enum.find(all(), fn t -> t.id == id end)
  end

  # Terrain type definitions

  def clear do
    %__MODULE__{
      id: :clear,
      name: "Clear",
      movement_costs: %{
        infantry: 1,
        armor: 1,
        motorized: 1,
        artillery: 1,
        recon: 1,
        engineer: 1
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: true,
      color: 0x90EE90
    }
  end

  def forest_pine do
    %__MODULE__{
      id: :forest_pine,
      name: "Pine Forest",
      movement_costs: %{
        infantry: 2,
        armor: 3,
        motorized: 4,
        artillery: 3,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 2,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x228B22
    }
  end

  def forest_deciduous do
    %__MODULE__{
      id: :forest_deciduous,
      name: "Deciduous Forest",
      movement_costs: %{
        infantry: 2,
        armor: 3,
        motorized: 3,
        artillery: 3,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 2,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x32CD32
    }
  end

  def desert do
    %__MODULE__{
      id: :desert,
      name: "Desert",
      movement_costs: %{
        infantry: 1,
        armor: 1,
        motorized: 1,
        artillery: 1,
        recon: 1,
        engineer: 1
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: true,
      color: 0xF4A460
    }
  end

  def marsh do
    %__MODULE__{
      id: :marsh,
      name: "Marsh",
      movement_costs: %{
        infantry: 2,
        armor: 3,
        motorized: 4,
        artillery: 3,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 1,
      blocks_los: false,
      concealment: true,
      fortifiable: false,
      color: 0x6B8E23
    }
  end

  def freshwater_lake do
    %__MODULE__{
      id: :freshwater_lake,
      name: "Freshwater Lake",
      movement_costs: %{
        infantry: :impassable,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: :impassable,
        engineer: :impassable
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0x4169E1
    }
  end

  def ocean do
    %__MODULE__{
      id: :ocean,
      name: "Ocean",
      movement_costs: %{
        infantry: :impassable,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: :impassable,
        engineer: :impassable
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0x000080
    }
  end

  def light_urban do
    %__MODULE__{
      id: :light_urban,
      name: "Light Urban",
      movement_costs: %{
        infantry: 1,
        armor: 2,
        motorized: 1,
        artillery: 2,
        recon: 1,
        engineer: 1
      },
      defense_modifier: 2,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0xA9A9A9
    }
  end

  def heavy_urban do
    %__MODULE__{
      id: :heavy_urban,
      name: "Heavy Urban",
      movement_costs: %{
        infantry: 2,
        armor: 3,
        motorized: 2,
        artillery: 3,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 3,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x696969
    }
  end

  def orchard do
    %__MODULE__{
      id: :orchard,
      name: "Orchard",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 1,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x9ACD32
    }
  end

  def semi_arid do
    %__MODULE__{
      id: :semi_arid,
      name: "Semi-Arid",
      movement_costs: %{
        infantry: 1,
        armor: 1,
        motorized: 1,
        artillery: 1,
        recon: 1,
        engineer: 1
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: true,
      color: 0xC2B280
    }
  end

  def tundra do
    %__MODULE__{
      id: :tundra,
      name: "Tundra",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: true,
      color: 0x8B8682
    }
  end

  def arctic do
    %__MODULE__{
      id: :arctic,
      name: "Arctic",
      movement_costs: %{
        infantry: 3,
        armor: 3,
        motorized: 3,
        artillery: 3,
        recon: 3,
        engineer: 3
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0xE8E8E8
    }
  end

  def frozen_lake do
    %__MODULE__{
      id: :frozen_lake,
      name: "Frozen Lake",
      movement_costs: %{
        infantry: 1,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 1,
        engineer: 1
      },
      defense_modifier: -1,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0xB0E0E6
    }
  end

  def frozen_ocean do
    %__MODULE__{
      id: :frozen_ocean,
      name: "Frozen Ocean",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 2
      },
      defense_modifier: -1,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0xADD8E6
    }
  end

  def industrial do
    %__MODULE__{
      id: :industrial,
      name: "Industrial",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 2,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x505050
    }
  end
end
