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
      hill(),
      mountain(),
      desert(),
      farmland(),
      pasture(),
      swamp(),
      marsh(),
      lake(),
      river(),
      ocean(),
      urban(),
      village(),
      ruins(),
      road(),
      railroad(),
      fortification(),
      minefield()
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

  def hill do
    %__MODULE__{
      id: :hill,
      name: "Hill",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 2
      },
      defense_modifier: 1,
      blocks_los: false,
      concealment: false,
      fortifiable: true,
      color: 0xA0522D
    }
  end

  def mountain do
    %__MODULE__{
      id: :mountain,
      name: "Mountain",
      movement_costs: %{
        infantry: 3,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: 4,
        engineer: 3
      },
      defense_modifier: 3,
      blocks_los: true,
      concealment: false,
      fortifiable: true,
      color: 0x808080
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

  def farmland do
    %__MODULE__{
      id: :farmland,
      name: "Farmland",
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
      concealment: true,
      fortifiable: true,
      color: 0xDAA520
    }
  end

  def pasture do
    %__MODULE__{
      id: :pasture,
      name: "Pasture",
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
      color: 0x98FB98
    }
  end

  def swamp do
    %__MODULE__{
      id: :swamp,
      name: "Swamp",
      movement_costs: %{
        infantry: 3,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: 4,
        engineer: 3
      },
      defense_modifier: 1,
      blocks_los: false,
      concealment: true,
      fortifiable: false,
      color: 0x556B2F
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

  def lake do
    %__MODULE__{
      id: :lake,
      name: "Lake",
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

  def river do
    %__MODULE__{
      id: :river,
      name: "River",
      movement_costs: %{
        infantry: :impassable,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: :impassable,
        engineer: 4
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0x1E90FF
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

  def urban do
    %__MODULE__{
      id: :urban,
      name: "Urban",
      movement_costs: %{
        infantry: 1,
        armor: 2,
        motorized: 1,
        artillery: 2,
        recon: 1,
        engineer: 1
      },
      defense_modifier: 3,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x696969
    }
  end

  def village do
    %__MODULE__{
      id: :village,
      name: "Village",
      movement_costs: %{
        infantry: 1,
        armor: 1,
        motorized: 1,
        artillery: 1,
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

  def ruins do
    %__MODULE__{
      id: :ruins,
      name: "Ruins",
      movement_costs: %{
        infantry: 2,
        armor: 2,
        motorized: 2,
        artillery: 2,
        recon: 2,
        engineer: 1
      },
      defense_modifier: 2,
      blocks_los: true,
      concealment: true,
      fortifiable: true,
      color: 0x8B4513
    }
  end

  def road do
    %__MODULE__{
      id: :road,
      name: "Road",
      movement_costs: %{
        infantry: 0.5,
        armor: 0.5,
        motorized: 0.5,
        artillery: 0.5,
        recon: 0.5,
        engineer: 0.5
      },
      defense_modifier: -1,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0xD2B48C
    }
  end

  def railroad do
    %__MODULE__{
      id: :railroad,
      name: "Railroad",
      movement_costs: %{
        infantry: 1,
        armor: 1,
        motorized: 1,
        artillery: 1,
        recon: 1,
        engineer: 1
      },
      defense_modifier: -1,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0x4A4A4A
    }
  end

  def fortification do
    %__MODULE__{
      id: :fortification,
      name: "Fortification",
      movement_costs: %{
        infantry: 1,
        armor: :impassable,
        motorized: :impassable,
        artillery: :impassable,
        recon: 2,
        engineer: 1
      },
      defense_modifier: 4,
      blocks_los: false,
      concealment: true,
      fortifiable: true,
      color: 0x654321
    }
  end

  def minefield do
    %__MODULE__{
      id: :minefield,
      name: "Minefield",
      movement_costs: %{
        infantry: 3,
        armor: 4,
        motorized: 4,
        artillery: 4,
        recon: 3,
        engineer: 2
      },
      defense_modifier: 0,
      blocks_los: false,
      concealment: false,
      fortifiable: false,
      color: 0xFF6347
    }
  end
end
