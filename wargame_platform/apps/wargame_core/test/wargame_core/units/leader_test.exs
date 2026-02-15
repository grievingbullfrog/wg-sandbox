defmodule WargameCore.Units.LeaderTest do
  use ExUnit.Case, async: true

  alias WargameCore.Units.Leader
  alias WargameCore.Hex.Coord

  @guderian_attrs %{
    id: "guderian",
    name: "Heinz Guderian",
    nationality: "german",
    era: "ww2",
    is_historical: true,
    rank: :general,
    command_radius: 4,
    attack_modifier: 2,
    defense_modifier: 1,
    morale_modifier: 15,
    initiative_modifier: 2,
    abilities: [:blitz, :combined_arms],
    position: Coord.new(5, 5),
    side: :axis,
    force: :german
  }

  describe "new/1" do
    test "creates a leader from attributes" do
      leader = Leader.new(@guderian_attrs)
      assert leader.name == "Heinz Guderian"
      assert leader.rank == :general
      assert leader.command_radius == 4
      assert leader.attack_modifier == 2
      assert leader.is_historical == true
    end

    test "creates from keyword list" do
      attrs = Enum.into(@guderian_attrs, [])
      leader = Leader.new(attrs)
      assert leader.name == "Heinz Guderian"
    end

    test "sets defaults for optional fields" do
      minimal = %{
        name: "Generic Colonel",
        nationality: "german",
        era: "ww2",
        rank: :colonel,
        side: :axis,
        force: :german
      }

      leader = Leader.new(minimal)
      assert leader.command_radius == 2
      assert leader.attack_modifier == 0
      assert leader.defense_modifier == 0
      assert leader.morale_modifier == 0
      assert leader.initiative_modifier == 0
      assert leader.abilities == []
      assert leader.is_historical == false
    end

    test "generates an id if not provided" do
      leader = Leader.new(%{@guderian_attrs | id: nil})
      assert leader.id != nil
    end

    test "uses rank_to_default_radius when no radius given" do
      leader = Leader.new(%{
        name: "Lt",
        nationality: "german",
        era: "ww2",
        rank: :lieutenant,
        side: :axis,
        force: :german
      })

      assert leader.command_radius == 1

      leader = Leader.new(%{
        name: "FM",
        nationality: "german",
        era: "ww2",
        rank: :field_marshal,
        side: :axis,
        force: :german
      })

      assert leader.command_radius == 6
    end
  end

  describe "in_command_radius?/2" do
    test "returns true for coords within radius" do
      leader = Leader.new(@guderian_attrs)
      # Leader at (5,5), radius 4
      assert Leader.in_command_radius?(leader, Coord.new(5, 5))
      assert Leader.in_command_radius?(leader, Coord.new(6, 5))
      assert Leader.in_command_radius?(leader, Coord.new(9, 5))
    end

    test "returns false for coords outside radius" do
      leader = Leader.new(@guderian_attrs)
      # Distance > 4 from (5,5)
      assert Leader.in_command_radius?(leader, Coord.new(10, 5)) == false
    end

    test "returns false when leader has no position" do
      leader = Leader.new(%{@guderian_attrs | position: nil})
      refute Leader.in_command_radius?(leader, Coord.new(5, 5))
    end
  end

  describe "apply_modifiers/2" do
    test "returns modifier map for a unit within radius" do
      leader = Leader.new(@guderian_attrs)

      modifiers = Leader.apply_modifiers(leader, Coord.new(6, 5))
      assert modifiers.attack == 2
      assert modifiers.defense == 1
      assert modifiers.morale == 15
      assert modifiers.initiative == 2
    end

    test "returns zero modifiers for unit out of radius" do
      leader = Leader.new(@guderian_attrs)

      modifiers = Leader.apply_modifiers(leader, Coord.new(15, 15))
      assert modifiers.attack == 0
      assert modifiers.defense == 0
      assert modifiers.morale == 0
      assert modifiers.initiative == 0
    end
  end

  describe "has_ability?/2" do
    test "true when leader has the ability" do
      leader = Leader.new(@guderian_attrs)
      assert Leader.has_ability?(leader, :blitz)
      assert Leader.has_ability?(leader, :combined_arms)
    end

    test "false when leader doesn't have the ability" do
      leader = Leader.new(@guderian_attrs)
      refute Leader.has_ability?(leader, :defensive_genius)
    end
  end

  describe "generate_replacement/1" do
    test "creates a generic leader of same rank with weaker stats" do
      leader = Leader.new(@guderian_attrs)
      replacement = Leader.generate_replacement(leader)

      assert replacement.rank == :general
      assert replacement.nationality == "german"
      assert replacement.is_historical == false
      assert replacement.abilities == []
      # Replacement has weaker stats
      assert replacement.attack_modifier < leader.attack_modifier
      assert replacement.defense_modifier <= leader.defense_modifier
    end

    test "replacement retains same side and force" do
      leader = Leader.new(@guderian_attrs)
      replacement = Leader.generate_replacement(leader)
      assert replacement.side == :axis
      assert replacement.force == :german
    end
  end

  describe "death_check/1" do
    test "returns :survives or :killed" do
      leader = Leader.new(@guderian_attrs)
      result = Leader.death_check(leader)
      assert result in [:survives, :killed]
    end
  end

  describe "rank_to_default_radius/1" do
    test "maps each rank to expected radius" do
      assert Leader.rank_to_default_radius(:lieutenant) == 1
      assert Leader.rank_to_default_radius(:captain) == 1
      assert Leader.rank_to_default_radius(:major) == 2
      assert Leader.rank_to_default_radius(:colonel) == 2
      assert Leader.rank_to_default_radius(:general) == 4
      assert Leader.rank_to_default_radius(:field_marshal) == 6
    end
  end

  describe "valid_ranks/0" do
    test "returns all valid rank atoms" do
      ranks = Leader.valid_ranks()
      assert :lieutenant in ranks
      assert :captain in ranks
      assert :major in ranks
      assert :colonel in ranks
      assert :general in ranks
      assert :field_marshal in ranks
    end
  end

  describe "valid_abilities/0" do
    test "returns all valid ability atoms" do
      abilities = Leader.valid_abilities()
      assert :inspire in abilities
      assert :blitz in abilities
      assert :fortify in abilities
      assert :recon_bonus in abilities
      assert :artillery_expert in abilities
      assert :combined_arms in abilities
      assert :defensive_genius in abilities
      assert :logistics in abilities
    end
  end
end
