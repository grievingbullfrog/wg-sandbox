defmodule WargamePersistence.UnitsTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Units

  @template_attrs %{
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{"attack_soft" => 8, "attack_hard" => 12, "defense" => 10}
  }

  @leader_attrs %{
    name: "Heinz Guderian",
    nationality: "german",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{"attack_modifier" => 2, "defense_modifier" => 1}
  }

  describe "unit template CRUD" do
    test "create_unit_template/1 creates a template" do
      assert {:ok, template} = Units.create_unit_template(@template_attrs)
      assert template.name == "Panzer IV"
      assert template.category == "armor"
    end

    test "get_unit_template!/1 returns the template" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert Units.get_unit_template!(template.id).name == "Panzer IV"
    end

    test "update_unit_template/2 updates" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert {:ok, updated} = Units.update_unit_template(template, %{name: "Panzer IV Ausf. H"})
      assert updated.name == "Panzer IV Ausf. H"
    end

    test "delete_unit_template/1 deletes" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert {:ok, _} = Units.delete_unit_template(template)
      assert Units.get_unit_template(template.id) == nil
    end

    test "list_unit_templates/1 with filters" do
      {:ok, _} = Units.create_unit_template(@template_attrs)

      {:ok, _} =
        Units.create_unit_template(%{
          @template_attrs
          | name: "Rifle Platoon",
            nationality: "soviet",
            category: "infantry"
        })

      assert length(Units.list_unit_templates()) == 2
      assert length(Units.list_unit_templates(nationality: "german")) == 1
      assert length(Units.list_unit_templates(category: "infantry")) == 1
      assert length(Units.list_unit_templates(era: "ww2")) == 2
    end
  end

  describe "leader CRUD" do
    test "create_leader/1 creates a leader" do
      assert {:ok, leader} = Units.create_leader(@leader_attrs)
      assert leader.name == "Heinz Guderian"
      assert leader.rank == "general"
    end

    test "get_leader!/1 returns the leader" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert Units.get_leader!(leader.id).name == "Heinz Guderian"
    end

    test "update_leader/2 updates" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert {:ok, updated} = Units.update_leader(leader, %{command_radius: 5})
      assert updated.command_radius == 5
    end

    test "delete_leader/1 deletes" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert {:ok, _} = Units.delete_leader(leader)
      assert Units.get_leader(leader.id) == nil
    end

    test "list_leaders/1 with filters" do
      {:ok, _} = Units.create_leader(@leader_attrs)

      {:ok, _} =
        Units.create_leader(%{
          @leader_attrs
          | name: "Zhukov",
            nationality: "soviet",
            rank: "field_marshal",
            command_radius: 6
        })

      assert length(Units.list_leaders()) == 2
      assert length(Units.list_leaders(nationality: "german")) == 1
      assert length(Units.list_leaders(rank: "general")) == 1
      assert length(Units.list_leaders(is_historical: true)) == 2
    end
  end
end
