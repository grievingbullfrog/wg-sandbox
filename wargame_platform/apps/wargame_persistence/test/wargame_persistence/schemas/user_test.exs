defmodule WargamePersistence.Schemas.UserTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.User

  @valid_attrs %{username: "testuser", email: "test@example.com", password_hash: "hashed123"}

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = User.changeset(%User{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires username" do
      changeset = User.changeset(%User{}, Map.delete(@valid_attrs, :username))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).username
    end

    test "requires email" do
      changeset = User.changeset(%User{}, Map.delete(@valid_attrs, :email))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "validates username length" do
      changeset = User.changeset(%User{}, %{@valid_attrs | username: "ab"})
      refute changeset.valid?
    end

    test "validates email format" do
      changeset = User.changeset(%User{}, %{@valid_attrs | email: "invalid"})
      refute changeset.valid?
    end

    test "enforces unique username" do
      {:ok, _} = Repo.insert(User.changeset(%User{}, @valid_attrs))

      {:error, changeset} =
        Repo.insert(
          User.changeset(%User{}, %{@valid_attrs | email: "other@example.com"})
        )

      assert "has already been taken" in errors_on(changeset).username
    end

    test "enforces unique email" do
      {:ok, _} = Repo.insert(User.changeset(%User{}, @valid_attrs))

      {:error, changeset} =
        Repo.insert(
          User.changeset(%User{}, %{@valid_attrs | username: "otheruser"})
        )

      assert "has already been taken" in errors_on(changeset).email
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
