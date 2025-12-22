defmodule WargameCore.Hex.Grid do
  @moduledoc """
  Grid operations for hex coordinates.

  Provides functions for:
  - Line drawing between hexes
  - Range queries (all hexes within distance)
  - Ring queries (hexes at exact distance)
  - Line of sight calculations
  - Pathfinding support
  """

  alias WargameCore.Hex.Coord

  @doc """
  Returns all hexes within a given range of a center hex.

  ## Examples

      iex> center = WargameCore.Hex.Coord.new(0, 0)
      iex> hexes = WargameCore.Hex.Grid.hexes_in_range(center, 1)
      iex> length(hexes)
      7
  """
  @spec hexes_in_range(Coord.t(), non_neg_integer()) :: [Coord.t()]
  def hexes_in_range(%Coord{} = center, range) when is_integer(range) and range >= 0 do
    for q <- -range..range,
        r <- max(-range, -q - range)..min(range, -q + range) do
      Coord.new(center.q + q, center.r + r)
    end
  end

  @doc """
  Returns hexes forming a ring at a given radius from center.

  ## Examples

      iex> center = WargameCore.Hex.Coord.new(0, 0)
      iex> hexes = WargameCore.Hex.Grid.hex_ring(center, 2)
      iex> length(hexes)
      12
  """
  @spec hex_ring(Coord.t(), non_neg_integer()) :: [Coord.t()]
  def hex_ring(%Coord{} = center, 0), do: [center]

  def hex_ring(%Coord{} = center, radius) when is_integer(radius) and radius > 0 do
    # Start at the hex in direction 4 (southwest), scaled by radius
    {dq, dr} = Coord.direction_vector(4)
    start = Coord.new(center.q + dq * radius, center.r + dr * radius)

    # Walk around the ring - for each of 6 directions, walk `radius` steps
    Enum.reduce(0..5, {start, []}, fn direction, {current, acc} ->
      # Walk `radius` steps in this direction, collecting hexes
      {final, collected} =
        Enum.reduce(1..radius, {current, [current]}, fn _, {c, list} ->
          next = Coord.neighbor(c, direction)
          {next, [next | list]}
        end)

      # Don't include the last hex (it's the start of the next edge)
      {final, acc ++ Enum.reverse(tl(collected))}
    end)
    |> elem(1)
    |> Enum.uniq_by(&Coord.to_key/1)
  end

  @doc """
  Draws a line between two hexes using linear interpolation.
  Returns all hexes along the line, including start and end.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(0, 0)
      iex> b = WargameCore.Hex.Coord.new(3, 0)
      iex> line = WargameCore.Hex.Grid.line_draw(a, b)
      iex> length(line)
      4
  """
  @spec line_draw(Coord.t(), Coord.t()) :: [Coord.t()]
  def line_draw(%Coord{} = a, %Coord{} = b) do
    n = Coord.distance(a, b)

    if n == 0 do
      [a]
    else
      Enum.map(0..n, fn i ->
        t = i / n
        # Linear interpolation in cube coordinates
        q = a.q + (b.q - a.q) * t
        r = a.r + (b.r - a.r) * t
        # Add small offset to avoid edge cases at exact boundaries
        Coord.hex_round(q + 1.0e-6, r + 1.0e-6)
      end)
    end
  end

  @doc """
  Checks if there is line of sight between two hexes.

  Takes a function that determines if a hex blocks LOS.
  The blocking function receives a coordinate and returns true if it blocks sight.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(0, 0)
      iex> b = WargameCore.Hex.Coord.new(3, 0)
      iex> WargameCore.Hex.Grid.has_line_of_sight?(a, b, fn _ -> false end)
      true
  """
  @spec has_line_of_sight?(Coord.t(), Coord.t(), (Coord.t() -> boolean())) :: boolean()
  def has_line_of_sight?(%Coord{} = from, %Coord{} = to, blocks_los_fn) when is_function(blocks_los_fn, 1) do
    line = line_draw(from, to)

    # Check all hexes except start and end
    line
    |> Enum.slice(1..-2//1)
    |> Enum.all?(fn coord -> not blocks_los_fn.(coord) end)
  end

  @doc """
  Returns hexes that are reachable from a starting point within a movement budget.

  Takes a function that returns the movement cost to enter a hex.
  Returns a map of {coord => remaining_movement}.

  ## Parameters
  - start: Starting coordinate
  - movement: Total movement points available
  - movement_cost_fn: Function that takes a coord and returns movement cost (or :impassable)

  ## Examples

      iex> start = WargameCore.Hex.Coord.new(0, 0)
      iex> reachable = WargameCore.Hex.Grid.reachable_hexes(start, 2, fn _ -> 1 end)
      iex> map_size(reachable) > 0
      true
  """
  @spec reachable_hexes(Coord.t(), number(), (Coord.t() -> number() | :impassable)) ::
          %{Coord.t() => number()}
  def reachable_hexes(%Coord{} = start, movement, movement_cost_fn)
      when is_number(movement) and is_function(movement_cost_fn, 1) do
    do_reachable(
      [{start, movement}],
      %{Coord.to_key(start) => movement},
      movement_cost_fn
    )
  end

  defp do_reachable([], visited, _cost_fn), do: visited

  defp do_reachable([{current, remaining} | rest], visited, cost_fn) do
    neighbors = Coord.neighbors(current)

    {new_frontier, new_visited} =
      Enum.reduce(neighbors, {rest, visited}, fn neighbor, {frontier, vis} ->
        key = Coord.to_key(neighbor)
        cost = cost_fn.(neighbor)

        cond do
          cost == :impassable ->
            {frontier, vis}

          remaining - cost < 0 ->
            {frontier, vis}

          Map.get(vis, key, -1) >= remaining - cost ->
            {frontier, vis}

          true ->
            new_remaining = remaining - cost
            {[{neighbor, new_remaining} | frontier], Map.put(vis, key, new_remaining)}
        end
      end)

    do_reachable(new_frontier, new_visited, cost_fn)
  end

  @doc """
  Finds the shortest path between two hexes using A* algorithm.

  Returns {:ok, path} where path is a list of coordinates from start to goal,
  or {:error, :no_path} if no path exists.

  ## Parameters
  - start: Starting coordinate
  - goal: Target coordinate
  - movement_cost_fn: Function returning cost to enter a hex (or :impassable)

  ## Examples

      iex> start = WargameCore.Hex.Coord.new(0, 0)
      iex> goal = WargameCore.Hex.Coord.new(2, 0)
      iex> {:ok, path} = WargameCore.Hex.Grid.find_path(start, goal, fn _ -> 1 end)
      iex> length(path)
      3
  """
  @spec find_path(Coord.t(), Coord.t(), (Coord.t() -> number() | :impassable)) ::
          {:ok, [Coord.t()]} | {:error, :no_path}
  def find_path(%Coord{} = start, %Coord{} = goal, movement_cost_fn)
      when is_function(movement_cost_fn, 1) do
    start_key = Coord.to_key(start)
    goal_key = Coord.to_key(goal)

    if start_key == goal_key do
      {:ok, [start]}
    else
      # Priority queue as sorted list: [{priority, coord, g_score}]
      open_set = [{Coord.distance(start, goal), start, 0}]
      came_from = %{}
      g_scores = %{start_key => 0}

      case do_astar(open_set, came_from, g_scores, goal, goal_key, movement_cost_fn) do
        {:ok, came_from_final} ->
          path = reconstruct_path(came_from_final, goal)
          {:ok, path}

        :no_path ->
          {:error, :no_path}
      end
    end
  end

  defp do_astar([], _came_from, _g_scores, _goal, _goal_key, _cost_fn), do: :no_path

  defp do_astar([{_priority, current, current_g} | rest], came_from, g_scores, goal, goal_key, cost_fn) do
    current_key = Coord.to_key(current)

    if current_key == goal_key do
      {:ok, came_from}
    else
      neighbors = Coord.neighbors(current)

      {new_open, new_came_from, new_g_scores} =
        Enum.reduce(neighbors, {rest, came_from, g_scores}, fn neighbor, {open, cf, gs} ->
          neighbor_key = Coord.to_key(neighbor)
          cost = cost_fn.(neighbor)

          if cost == :impassable do
            {open, cf, gs}
          else
            tentative_g = current_g + cost

            if tentative_g < Map.get(gs, neighbor_key, :infinity) do
              h = Coord.distance(neighbor, goal)
              f = tentative_g + h

              new_open = insert_by_priority(open, {f, neighbor, tentative_g})
              new_cf = Map.put(cf, neighbor_key, current)
              new_gs = Map.put(gs, neighbor_key, tentative_g)

              {new_open, new_cf, new_gs}
            else
              {open, cf, gs}
            end
          end
        end)

      do_astar(new_open, new_came_from, new_g_scores, goal, goal_key, cost_fn)
    end
  end

  defp insert_by_priority(list, {priority, _, _} = item) do
    {before, after_list} = Enum.split_while(list, fn {p, _, _} -> p < priority end)
    before ++ [item | after_list]
  end

  defp reconstruct_path(came_from, current) do
    do_reconstruct(came_from, current, [current])
  end

  defp do_reconstruct(came_from, current, path) do
    current_key = Coord.to_key(current)

    case Map.get(came_from, current_key) do
      nil -> path
      prev -> do_reconstruct(came_from, prev, [prev | path])
    end
  end

  @doc """
  Returns the direction from one hex to an adjacent hex.
  Returns nil if the hexes are not adjacent.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(0, 0)
      iex> b = WargameCore.Hex.Coord.new(1, 0)
      iex> WargameCore.Hex.Grid.direction_to(a, b)
      0
  """
  @spec direction_to(Coord.t(), Coord.t()) :: 0..5 | nil
  def direction_to(%Coord{} = from, %Coord{} = to) do
    diff = Coord.subtract(to, from)

    Enum.find(0..5, fn dir ->
      {dq, dr} = Coord.direction_vector(dir)
      diff.q == dq and diff.r == dr
    end)
  end

  @doc """
  Returns all hexes in a wedge/cone shape from origin in a direction.

  ## Parameters
  - origin: Starting coordinate
  - direction: Direction (0-5) the cone faces
  - range: How far the cone extends
  - width: How wide the cone spreads (in 60-degree increments, 0-2)
  """
  @spec cone(Coord.t(), 0..5, non_neg_integer(), 0..2) :: [Coord.t()]
  def cone(%Coord{} = _origin, _direction, 0, _width), do: []

  def cone(%Coord{} = origin, direction, range, width)
      when direction in 0..5 and is_integer(range) and range > 0 and width in 0..2 do
    directions =
      case width do
        0 -> [direction]
        1 -> [Coord.rotate_direction(direction, -1), direction, Coord.rotate_direction(direction, 1)]
        2 -> Enum.map(-2..2, &Coord.rotate_direction(direction, &1))
      end

    Enum.flat_map(1..range, fn dist ->
      Enum.flat_map(directions, fn dir ->
        {dq, dr} = Coord.direction_vector(dir)
        [Coord.new(origin.q + dq * dist, origin.r + dr * dist)]
      end)
    end)
    |> Enum.uniq_by(&Coord.to_key/1)
  end
end
