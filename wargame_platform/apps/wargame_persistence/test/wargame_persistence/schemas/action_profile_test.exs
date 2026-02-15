defmodule WargamePersistence.Schemas.ActionProfileTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.ActionProfile

  @valid_attrs %{
    name: "WW2 Standard",
    era: "ww2",
    actions: %{
      "options" => [
        %{"id" => "move_and_fire", "move" => true, "fire" => true},
        %{"id" => "fire_only", "move" => false, "fire" => true},
        %{"id" => "move_only", "move" => true, "fire" => false}
      ]
    },
    phase_sequence: %{
      "phases" => ["command", "movement", "combat", "exploitation", "supply", "end_phase"]
    },
    rules_module: "Elixir.WargameCore.Rules.StandardRules"
  }

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = ActionProfile.changeset(%ActionProfile{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = ActionProfile.changeset(%ActionProfile{}, Map.delete(@valid_attrs, :name))
      refute changeset.valid?
    end

    test "requires era" do
      changeset = ActionProfile.changeset(%ActionProfile{}, Map.delete(@valid_attrs, :era))
      refute changeset.valid?
    end

    test "rejects nil actions" do
      changeset = ActionProfile.changeset(%ActionProfile{}, %{@valid_attrs | actions: nil})
      refute changeset.valid?
    end

    test "rejects nil phase_sequence" do
      changeset = ActionProfile.changeset(%ActionProfile{}, %{@valid_attrs | phase_sequence: nil})
      refute changeset.valid?
    end

    test "requires rules_module" do
      changeset = ActionProfile.changeset(%ActionProfile{}, Map.delete(@valid_attrs, :rules_module))
      refute changeset.valid?
    end
  end
end
