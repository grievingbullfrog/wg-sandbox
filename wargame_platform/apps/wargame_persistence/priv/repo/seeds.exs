alias WargamePersistence.Repo
alias WargamePersistence.Schemas.ActionProfile

# --- WW2 Standard Action Profile ---

ww2_profile_attrs = %{
  name: "WW2 Standard",
  era: "ww2",
  actions: %{
    "options" => [
      %{
        "id" => "move_and_fire",
        "move" => true,
        "fire" => true,
        "melee" => false,
        "move_penalty" => 0.5
      },
      %{
        "id" => "fire_only",
        "move" => false,
        "fire" => true,
        "melee" => false
      },
      %{
        "id" => "move_only",
        "move" => true,
        "fire" => false,
        "melee" => false
      },
      %{
        "id" => "hold",
        "move" => false,
        "fire" => false,
        "melee" => false,
        "entrench" => true
      },
      %{
        "id" => "assault",
        "move" => true,
        "fire" => true,
        "melee" => true,
        "move_penalty" => 0.5
      }
    ]
  },
  phase_sequence: %{
    "phases" => [
      %{"id" => "command", "name" => "Command", "allows_movement" => false, "allows_combat" => false, "allows_orders" => true, "is_optional" => false},
      %{"id" => "movement", "name" => "Movement", "allows_movement" => true, "allows_combat" => false, "allows_orders" => false, "is_optional" => false},
      %{"id" => "combat", "name" => "Combat", "allows_movement" => false, "allows_combat" => true, "allows_orders" => false, "is_optional" => false},
      %{"id" => "exploitation", "name" => "Exploitation", "allows_movement" => true, "allows_combat" => true, "allows_orders" => false, "is_optional" => true},
      %{"id" => "supply", "name" => "Supply", "allows_movement" => false, "allows_combat" => false, "allows_orders" => false, "is_optional" => false},
      %{"id" => "end_phase", "name" => "End Phase", "allows_movement" => false, "allows_combat" => false, "allows_orders" => false, "is_optional" => false}
    ]
  },
  rules_module: "Elixir.WargameCore.Rules.StandardRules"
}

case Repo.get_by(ActionProfile, name: "WW2 Standard", era: "ww2") do
  nil ->
    %ActionProfile{}
    |> ActionProfile.changeset(ww2_profile_attrs)
    |> Repo.insert!()
    |> then(fn profile -> IO.puts("Created WW2 Standard action profile: #{profile.id}") end)

  existing ->
    IO.puts("WW2 Standard action profile already exists: #{existing.id}")
end

# --- WW2 Eastern Front Units & Leaders ---
Code.require_file("seeds/ww2_eastern_front_units.exs", __DIR__)
