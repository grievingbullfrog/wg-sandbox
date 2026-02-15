defmodule WargamePersistence.Schemas.LeaderTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.Leader

  @valid_attrs %{
    name: "Heinz Guderian",
    nationality: "german",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{
      "attack_modifier" => 2,
      "defense_modifier" => 1,
      "morale_modifier" => 15,
      "initiative_modifier" => 2,
      "abilities" => ["blitz", "combined_arms"]
    }
  }

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = Leader.changeset(%Leader{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Leader.changeset(%Leader{}, Map.delete(@valid_attrs, :name))
      refute changeset.valid?
    end

    test "requires rank" do
      changeset = Leader.changeset(%Leader{}, Map.delete(@valid_attrs, :rank))
      refute changeset.valid?
    end

    test "requires command_radius" do
      changeset = Leader.changeset(%Leader{}, Map.delete(@valid_attrs, :command_radius))
      refute changeset.valid?
    end

    test "validates rank inclusion" do
      changeset = Leader.changeset(%Leader{}, %{@valid_attrs | rank: "invalid"})
      refute changeset.valid?
    end

    test "validates command_radius range" do
      changeset = Leader.changeset(%Leader{}, %{@valid_attrs | command_radius: 0})
      refute changeset.valid?

      changeset = Leader.changeset(%Leader{}, %{@valid_attrs | command_radius: 7})
      refute changeset.valid?
    end

    test "accepts all valid ranks" do
      for rank <- Leader.valid_ranks() do
        changeset = Leader.changeset(%Leader{}, %{@valid_attrs | rank: rank})
        assert changeset.valid?, "expected rank #{rank} to be valid"
      end
    end
  end
end
