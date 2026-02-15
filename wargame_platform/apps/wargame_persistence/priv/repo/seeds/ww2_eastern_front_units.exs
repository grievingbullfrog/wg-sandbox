alias WargamePersistence.Repo
alias WargamePersistence.Schemas.{UnitTemplate, Leader}

# =============================================================================
# WW2 Eastern Front Unit Templates
# =============================================================================
#
# Stats are inspired by Panzer General / Campaign Series values.
# attack_soft / attack_hard / defense / armor are 0-99 scale.
# movement_points represent hexes per turn at standard scale.
# max_strength is the number of strength steps (Panzer General style, 1-15).
#
# Category key:
#   infantry, armor, motorized, artillery, recon, engineer,
#   anti_tank, anti_air, cavalry
#
# Movement types: foot, wheeled, tracked, horse

defmodule WW2Seeds do
  def upsert_template!(attrs) do
    case Repo.get_by(UnitTemplate, name: attrs.name, nationality: attrs.nationality) do
      nil ->
        %UnitTemplate{}
        |> UnitTemplate.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
    end
  end

  def upsert_leader!(attrs) do
    case Repo.get_by(Leader, name: attrs.name, nationality: attrs.nationality) do
      nil ->
        %Leader{}
        |> Leader.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
    end
  end
end

# =============================================================================
# GERMAN UNITS
# =============================================================================

german_templates = [
  %{
    name: "Infantry Platoon",
    nationality: "german",
    era: "ww2",
    category: "infantry",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 1, "defense" => 5, "armor" => 0,
      "movement_points" => 4, "movement_type" => "foot",
      "range" => 0, "spotting" => 2, "initiative" => 3,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "Panzergrenadier Platoon",
    nationality: "german",
    era: "ww2",
    category: "motorized",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 8, "attack_hard" => 3, "defense" => 6, "armor" => 1,
      "movement_points" => 6, "movement_type" => "wheeled",
      "range" => 0, "spotting" => 2, "initiative" => 4,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 6,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => true
    }
  },
  %{
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 12, "defense" => 10, "armor" => 5,
      "movement_points" => 8, "movement_type" => "tracked",
      "range" => 1, "spotting" => 3, "initiative" => 5,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 8,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "Panzer V Panther",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 5, "attack_hard" => 18, "defense" => 14, "armor" => 9,
      "movement_points" => 7, "movement_type" => "tracked",
      "range" => 2, "spotting" => 3, "initiative" => 6,
      "max_strength" => 10, "max_ammo" => 5, "max_fuel" => 6,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "Tiger I",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 22, "defense" => 16, "armor" => 12,
      "movement_points" => 6, "movement_type" => "tracked",
      "range" => 2, "spotting" => 3, "initiative" => 5,
      "max_strength" => 10, "max_ammo" => 4, "max_fuel" => 5,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "StuG III",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 5, "attack_hard" => 14, "defense" => 10, "armor" => 6,
      "movement_points" => 7, "movement_type" => "tracked",
      "range" => 1, "spotting" => 2, "initiative" => 4,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 7,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "88mm AT Gun",
    nationality: "german",
    era: "ww2",
    category: "anti_tank",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 3, "attack_hard" => 20, "defense" => 4, "armor" => 0,
      "movement_points" => 2, "movement_type" => "foot",
      "range" => 3, "spotting" => 3, "initiative" => 3,
      "max_strength" => 5, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "105mm Howitzer",
    nationality: "german",
    era: "ww2",
    category: "artillery",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 12, "attack_hard" => 4, "defense" => 2, "armor" => 0,
      "movement_points" => 2, "movement_type" => "foot",
      "range" => 5, "spotting" => 1, "initiative" => 2,
      "max_strength" => 5, "max_ammo" => 8, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "Recon Halftrack",
    nationality: "german",
    era: "ww2",
    category: "recon",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 3, "attack_hard" => 2, "defense" => 3, "armor" => 1,
      "movement_points" => 10, "movement_type" => "wheeled",
      "range" => 0, "spotting" => 5, "initiative" => 7,
      "max_strength" => 5, "max_ammo" => 4, "max_fuel" => 8,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "Pioneer Platoon",
    nationality: "german",
    era: "ww2",
    category: "engineer",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 7, "attack_hard" => 2, "defense" => 5, "armor" => 0,
      "movement_points" => 4, "movement_type" => "foot",
      "range" => 0, "spotting" => 2, "initiative" => 3,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => true, "can_entrench" => true, "is_organic_transport" => false
    }
  }
]

# =============================================================================
# SOVIET UNITS
# =============================================================================

soviet_templates = [
  %{
    name: "Rifle Platoon",
    nationality: "soviet",
    era: "ww2",
    category: "infantry",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 5, "attack_hard" => 1, "defense" => 4, "armor" => 0,
      "movement_points" => 4, "movement_type" => "foot",
      "range" => 0, "spotting" => 2, "initiative" => 2,
      "max_strength" => 10, "max_ammo" => 5, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "Guards Rifle Platoon",
    nationality: "soviet",
    era: "ww2",
    category: "infantry",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 7, "attack_hard" => 2, "defense" => 6, "armor" => 0,
      "movement_points" => 4, "movement_type" => "foot",
      "range" => 0, "spotting" => 2, "initiative" => 4,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "T-34/76",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 10, "defense" => 8, "armor" => 5,
      "movement_points" => 8, "movement_type" => "tracked",
      "range" => 1, "spotting" => 2, "initiative" => 4,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 8,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "T-34/85",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 14, "defense" => 10, "armor" => 6,
      "movement_points" => 8, "movement_type" => "tracked",
      "range" => 1, "spotting" => 3, "initiative" => 5,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 7,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "KV-1",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 5, "attack_hard" => 10, "defense" => 12, "armor" => 8,
      "movement_points" => 5, "movement_type" => "tracked",
      "range" => 1, "spotting" => 2, "initiative" => 3,
      "max_strength" => 10, "max_ammo" => 5, "max_fuel" => 5,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "IS-2",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 8, "attack_hard" => 20, "defense" => 14, "armor" => 10,
      "movement_points" => 6, "movement_type" => "tracked",
      "range" => 2, "spotting" => 3, "initiative" => 5,
      "max_strength" => 10, "max_ammo" => 4, "max_fuel" => 5,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "SU-76",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 8, "defense" => 6, "armor" => 3,
      "movement_points" => 7, "movement_type" => "tracked",
      "range" => 1, "spotting" => 2, "initiative" => 4,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 7,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "SU-152",
    nationality: "soviet",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 10, "attack_hard" => 18, "defense" => 10, "armor" => 7,
      "movement_points" => 5, "movement_type" => "tracked",
      "range" => 2, "spotting" => 2, "initiative" => 3,
      "max_strength" => 10, "max_ammo" => 3, "max_fuel" => 5,
      "can_bridge" => false, "can_entrench" => false, "is_organic_transport" => false
    }
  },
  %{
    name: "76mm AT Gun",
    nationality: "soviet",
    era: "ww2",
    category: "anti_tank",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 2, "attack_hard" => 12, "defense" => 3, "armor" => 0,
      "movement_points" => 2, "movement_type" => "foot",
      "range" => 2, "spotting" => 3, "initiative" => 2,
      "max_strength" => 5, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "122mm Howitzer",
    nationality: "soviet",
    era: "ww2",
    category: "artillery",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 14, "attack_hard" => 5, "defense" => 2, "armor" => 0,
      "movement_points" => 2, "movement_type" => "foot",
      "range" => 5, "spotting" => 1, "initiative" => 2,
      "max_strength" => 5, "max_ammo" => 7, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "Recon Company",
    nationality: "soviet",
    era: "ww2",
    category: "recon",
    unit_size: "company",
    stats: %{
      "attack_soft" => 3, "attack_hard" => 1, "defense" => 3, "armor" => 0,
      "movement_points" => 8, "movement_type" => "foot",
      "range" => 0, "spotting" => 5, "initiative" => 6,
      "max_strength" => 5, "max_ammo" => 4, "max_fuel" => 0,
      "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
    }
  },
  %{
    name: "Engineer Platoon",
    nationality: "soviet",
    era: "ww2",
    category: "engineer",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 6, "attack_hard" => 2, "defense" => 4, "armor" => 0,
      "movement_points" => 4, "movement_type" => "foot",
      "range" => 0, "spotting" => 2, "initiative" => 3,
      "max_strength" => 10, "max_ammo" => 6, "max_fuel" => 0,
      "can_bridge" => true, "can_entrench" => true, "is_organic_transport" => false
    }
  }
]

# =============================================================================
# LEADERS
# =============================================================================

german_leaders = [
  %{
    name: "Heinz Guderian",
    nationality: "german",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2, "defense_modifier" => 1,
      "morale_modifier" => 15, "initiative_modifier" => 2,
      "abilities" => ["blitz", "combined_arms"]
    }
  },
  %{
    name: "Erich von Manstein",
    nationality: "german",
    era: "ww2",
    rank: "field_marshal",
    command_radius: 5,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2, "defense_modifier" => 2,
      "morale_modifier" => 15, "initiative_modifier" => 3,
      "abilities" => ["blitz", "defensive_genius"]
    }
  },
  %{
    name: "Walter Model",
    nationality: "german",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 1, "defense_modifier" => 3,
      "morale_modifier" => 10, "initiative_modifier" => 1,
      "abilities" => ["defensive_genius", "fortify"]
    }
  }
]

soviet_leaders = [
  %{
    name: "Georgy Zhukov",
    nationality: "soviet",
    era: "ww2",
    rank: "field_marshal",
    command_radius: 6,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 3, "defense_modifier" => 2,
      "morale_modifier" => 20, "initiative_modifier" => 2,
      "abilities" => ["inspire", "combined_arms"]
    }
  },
  %{
    name: "Ivan Konev",
    nationality: "soviet",
    era: "ww2",
    rank: "field_marshal",
    command_radius: 5,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2, "defense_modifier" => 1,
      "morale_modifier" => 15, "initiative_modifier" => 2,
      "abilities" => ["artillery_expert", "combined_arms"]
    }
  },
  %{
    name: "Konstantin Rokossovsky",
    nationality: "soviet",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2, "defense_modifier" => 2,
      "morale_modifier" => 15, "initiative_modifier" => 1,
      "abilities" => ["inspire", "defensive_genius"]
    }
  },
  %{
    name: "Nikolai Vatutin",
    nationality: "soviet",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2, "defense_modifier" => 1,
      "morale_modifier" => 10, "initiative_modifier" => 2,
      "abilities" => ["blitz", "logistics"]
    }
  }
]

# =============================================================================
# INSERT ALL
# =============================================================================

IO.puts("\n--- Seeding German unit templates ---")
for attrs <- german_templates do
  template = WW2Seeds.upsert_template!(attrs)
  IO.puts("  #{template.name}")
end

IO.puts("\n--- Seeding Soviet unit templates ---")
for attrs <- soviet_templates do
  template = WW2Seeds.upsert_template!(attrs)
  IO.puts("  #{template.name}")
end

IO.puts("\n--- Seeding German leaders ---")
for attrs <- german_leaders do
  leader = WW2Seeds.upsert_leader!(attrs)
  IO.puts("  #{leader.name}")
end

IO.puts("\n--- Seeding Soviet leaders ---")
for attrs <- soviet_leaders do
  leader = WW2Seeds.upsert_leader!(attrs)
  IO.puts("  #{leader.name}")
end

IO.puts("\nEastern Front seed data complete: #{length(german_templates) + length(soviet_templates)} templates, #{length(german_leaders) + length(soviet_leaders)} leaders")
