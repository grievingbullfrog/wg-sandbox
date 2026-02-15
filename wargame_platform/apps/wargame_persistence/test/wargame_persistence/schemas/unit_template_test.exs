defmodule WargamePersistence.Schemas.UnitTemplateTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.UnitTemplate

  @valid_attrs %{
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{
      "attack_soft" => 8,
      "attack_hard" => 12,
      "defense" => 10,
      "armor" => 6,
      "movement_points" => 6,
      "movement_type" => "tracked"
    }
  }

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, Map.delete(@valid_attrs, :name))
      refute changeset.valid?
    end

    test "requires nationality" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, Map.delete(@valid_attrs, :nationality))
      refute changeset.valid?
    end

    test "requires era" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, Map.delete(@valid_attrs, :era))
      refute changeset.valid?
    end

    test "requires category" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, Map.delete(@valid_attrs, :category))
      refute changeset.valid?
    end

    test "requires unit_size" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, Map.delete(@valid_attrs, :unit_size))
      refute changeset.valid?
    end

    test "validates category inclusion" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, %{@valid_attrs | category: "invalid"})
      refute changeset.valid?
    end

    test "validates unit_size inclusion" do
      changeset = UnitTemplate.changeset(%UnitTemplate{}, %{@valid_attrs | unit_size: "invalid"})
      refute changeset.valid?
    end

    test "accepts all valid categories" do
      for category <- UnitTemplate.valid_categories() do
        changeset = UnitTemplate.changeset(%UnitTemplate{}, %{@valid_attrs | category: category})
        assert changeset.valid?, "expected category #{category} to be valid"
      end
    end

    test "accepts all valid unit sizes" do
      for size <- UnitTemplate.valid_unit_sizes() do
        changeset = UnitTemplate.changeset(%UnitTemplate{}, %{@valid_attrs | unit_size: size})
        assert changeset.valid?, "expected unit_size #{size} to be valid"
      end
    end
  end
end
