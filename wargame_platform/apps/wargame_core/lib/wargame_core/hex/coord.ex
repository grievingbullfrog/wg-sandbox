defmodule WargameCore.Hex.Coord do
  @moduledoc """
  Axial coordinate system for hex grids.

  Uses axial coordinates (q, r) with computed cube coordinate s = -q - r.
  Based on Red Blob Games implementation guide.

  ## Coordinate System

  Pointy-top hexes with axial coordinates:
  - q: column (increases east)
  - r: row (increases southeast)
  - s: computed as -q - r (for cube coordinate operations)

  ## Direction Indices (pointy-top, counter-clockwise from east)

      0: East      (+1,  0)
      1: Northeast (+1, -1)
      2: Northwest ( 0, -1)
      3: West      (-1,  0)
      4: Southwest (-1, +1)
      5: Southeast ( 0, +1)
  """

  @type t :: %__MODULE__{q: integer(), r: integer()}

  @enforce_keys [:q, :r]
  defstruct [:q, :r]

  @direction_vectors [
    {1, 0},   # 0: East
    {1, -1},  # 1: Northeast
    {0, -1},  # 2: Northwest
    {-1, 0},  # 3: West
    {-1, 1},  # 4: Southwest
    {0, 1}    # 5: Southeast
  ]

  @doc """
  Creates a new hex coordinate.

  ## Examples

      iex> WargameCore.Hex.Coord.new(3, 4)
      %WargameCore.Hex.Coord{q: 3, r: 4}
  """
  @spec new(integer(), integer()) :: t()
  def new(q, r) when is_integer(q) and is_integer(r) do
    %__MODULE__{q: q, r: r}
  end

  @doc """
  Creates a hex coordinate from cube coordinates.
  Validates that q + r + s = 0.

  ## Examples

      iex> WargameCore.Hex.Coord.from_cube(1, -2, 1)
      {:ok, %WargameCore.Hex.Coord{q: 1, r: -2}}

      iex> WargameCore.Hex.Coord.from_cube(1, 1, 1)
      {:error, :invalid_cube_coordinates}
  """
  @spec from_cube(integer(), integer(), integer()) :: {:ok, t()} | {:error, :invalid_cube_coordinates}
  def from_cube(q, r, s) when is_integer(q) and is_integer(r) and is_integer(s) do
    if q + r + s == 0 do
      {:ok, %__MODULE__{q: q, r: r}}
    else
      {:error, :invalid_cube_coordinates}
    end
  end

  @doc """
  Computes the cube s coordinate from axial coordinates.

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(3, -1)
      iex> WargameCore.Hex.Coord.s(coord)
      -2
  """
  @spec s(t()) :: integer()
  def s(%__MODULE__{q: q, r: r}), do: -q - r

  @doc """
  Calculates the distance between two hex coordinates.
  Distance is the number of steps needed to move from one hex to another.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(0, 0)
      iex> b = WargameCore.Hex.Coord.new(3, -1)
      iex> WargameCore.Hex.Coord.distance(a, b)
      3
  """
  @spec distance(t(), t()) :: non_neg_integer()
  def distance(%__MODULE__{} = a, %__MODULE__{} = b) do
    max(
      abs(a.q - b.q),
      max(
        abs(a.r - b.r),
        abs(s(a) - s(b))
      )
    )
  end

  @doc """
  Adds two coordinates together.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(1, 2)
      iex> b = WargameCore.Hex.Coord.new(3, -1)
      iex> WargameCore.Hex.Coord.add(a, b)
      %WargameCore.Hex.Coord{q: 4, r: 1}
  """
  @spec add(t(), t()) :: t()
  def add(%__MODULE__{q: q1, r: r1}, %__MODULE__{q: q2, r: r2}) do
    %__MODULE__{q: q1 + q2, r: r1 + r2}
  end

  @doc """
  Subtracts the second coordinate from the first.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(4, 1)
      iex> b = WargameCore.Hex.Coord.new(1, 2)
      iex> WargameCore.Hex.Coord.subtract(a, b)
      %WargameCore.Hex.Coord{q: 3, r: -1}
  """
  @spec subtract(t(), t()) :: t()
  def subtract(%__MODULE__{q: q1, r: r1}, %__MODULE__{q: q2, r: r2}) do
    %__MODULE__{q: q1 - q2, r: r1 - r2}
  end

  @doc """
  Scales a coordinate by a factor.

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(2, 3)
      iex> WargameCore.Hex.Coord.scale(coord, 2)
      %WargameCore.Hex.Coord{q: 4, r: 6}
  """
  @spec scale(t(), integer()) :: t()
  def scale(%__MODULE__{q: q, r: r}, factor) when is_integer(factor) do
    %__MODULE__{q: q * factor, r: r * factor}
  end

  @doc """
  Gets the neighbor in a given direction (0-5).

  ## Direction Indices
  - 0: East
  - 1: Northeast
  - 2: Northwest
  - 3: West
  - 4: Southwest
  - 5: Southeast

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(0, 0)
      iex> WargameCore.Hex.Coord.neighbor(coord, 0)
      %WargameCore.Hex.Coord{q: 1, r: 0}
  """
  @spec neighbor(t(), 0..5) :: t()
  def neighbor(%__MODULE__{q: q, r: r}, direction) when direction in 0..5 do
    {dq, dr} = Enum.at(@direction_vectors, direction)
    %__MODULE__{q: q + dq, r: r + dr}
  end

  @doc """
  Gets all six neighbors of a hex.

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(0, 0)
      iex> neighbors = WargameCore.Hex.Coord.neighbors(coord)
      iex> length(neighbors)
      6
  """
  @spec neighbors(t()) :: [t()]
  def neighbors(%__MODULE__{} = coord) do
    Enum.map(0..5, &neighbor(coord, &1))
  end

  @doc """
  Returns the direction vector for a given direction index.

  ## Examples

      iex> WargameCore.Hex.Coord.direction_vector(0)
      {1, 0}
  """
  @spec direction_vector(0..5) :: {integer(), integer()}
  def direction_vector(direction) when direction in 0..5 do
    Enum.at(@direction_vectors, direction)
  end

  @doc """
  Converts the coordinate to a string key for use in maps.

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(3, -2)
      iex> WargameCore.Hex.Coord.to_key(coord)
      "3,-2"
  """
  @spec to_key(t()) :: String.t()
  def to_key(%__MODULE__{q: q, r: r}) do
    "#{q},#{r}"
  end

  @doc """
  Parses a coordinate from a string key.

  ## Examples

      iex> WargameCore.Hex.Coord.from_key("3,-2")
      {:ok, %WargameCore.Hex.Coord{q: 3, r: -2}}

      iex> WargameCore.Hex.Coord.from_key("invalid")
      {:error, :invalid_key}
  """
  @spec from_key(String.t()) :: {:ok, t()} | {:error, :invalid_key}
  def from_key(key) when is_binary(key) do
    case String.split(key, ",") do
      [q_str, r_str] ->
        with {q, ""} <- Integer.parse(q_str),
             {r, ""} <- Integer.parse(r_str) do
          {:ok, %__MODULE__{q: q, r: r}}
        else
          _ -> {:error, :invalid_key}
        end

      _ ->
        {:error, :invalid_key}
    end
  end

  @doc """
  Converts axial hex coordinate to pixel position (pointy-top orientation).

  ## Parameters
  - coord: The hex coordinate
  - size: Hex size (distance from center to corner in pixels)

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(1, 1)
      iex> {x, y} = WargameCore.Hex.Coord.to_pixel(coord, 40)
      iex> is_float(x) and is_float(y)
      true
  """
  @spec to_pixel(t(), number()) :: {float(), float()}
  def to_pixel(%__MODULE__{q: q, r: r}, size) when is_number(size) do
    x = size * (:math.sqrt(3) * q + :math.sqrt(3) / 2 * r)
    y = size * (3 / 2 * r)
    {x, y}
  end

  @doc """
  Converts pixel position to the nearest hex coordinate (pointy-top orientation).

  ## Parameters
  - x: Pixel x position
  - y: Pixel y position
  - size: Hex size (distance from center to corner in pixels)

  ## Examples

      iex> coord = WargameCore.Hex.Coord.from_pixel(100.0, 50.0, 40)
      iex> is_struct(coord, WargameCore.Hex.Coord)
      true
  """
  @spec from_pixel(number(), number(), number()) :: t()
  def from_pixel(x, y, size) when is_number(x) and is_number(y) and is_number(size) do
    q = (:math.sqrt(3) / 3 * x - 1 / 3 * y) / size
    r = (2 / 3 * y) / size
    hex_round(q, r)
  end

  @doc """
  Rounds fractional hex coordinates to the nearest hex.

  Uses cube coordinate rounding for accuracy.
  """
  @spec hex_round(number(), number()) :: t()
  def hex_round(q, r) when is_number(q) and is_number(r) do
    s = -q - r

    rq = round(q)
    rr = round(r)
    rs = round(s)

    q_diff = abs(rq - q)
    r_diff = abs(rr - r)
    s_diff = abs(rs - s)

    {final_q, final_r} =
      cond do
        q_diff > r_diff and q_diff > s_diff ->
          {-rr - rs, rr}

        r_diff > s_diff ->
          {rq, -rq - rs}

        true ->
          {rq, rr}
      end

    %__MODULE__{q: final_q, r: final_r}
  end

  @doc """
  Checks if two coordinates are equal.

  ## Examples

      iex> a = WargameCore.Hex.Coord.new(1, 2)
      iex> b = WargameCore.Hex.Coord.new(1, 2)
      iex> WargameCore.Hex.Coord.equal?(a, b)
      true
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{q: q1, r: r1}, %__MODULE__{q: q2, r: r2}) do
    q1 == q2 and r1 == r2
  end

  @doc """
  Returns the opposite direction (180 degrees).

  ## Examples

      iex> WargameCore.Hex.Coord.opposite_direction(0)
      3
      iex> WargameCore.Hex.Coord.opposite_direction(1)
      4
  """
  @spec opposite_direction(0..5) :: 0..5
  def opposite_direction(direction) when direction in 0..5 do
    rem(direction + 3, 6)
  end

  @doc """
  Rotates a direction by a number of steps (each step is 60 degrees).
  Positive steps rotate counter-clockwise.

  ## Examples

      iex> WargameCore.Hex.Coord.rotate_direction(0, 1)
      1
      iex> WargameCore.Hex.Coord.rotate_direction(5, 2)
      1
  """
  @spec rotate_direction(0..5, integer()) :: 0..5
  def rotate_direction(direction, steps) when direction in 0..5 and is_integer(steps) do
    rem(rem(direction + steps, 6) + 6, 6)
  end

  @doc """
  Returns the direction from one coordinate to an adjacent coordinate.

  Returns nil if the coordinates are not adjacent.

  ## Examples

      iex> from = WargameCore.Hex.Coord.new(0, 0)
      iex> to = WargameCore.Hex.Coord.new(1, 0)
      iex> WargameCore.Hex.Coord.direction_to(from, to)
      0

      iex> from = WargameCore.Hex.Coord.new(0, 0)
      iex> to = WargameCore.Hex.Coord.new(2, 0)
      iex> WargameCore.Hex.Coord.direction_to(from, to)
      nil
  """
  @spec direction_to(t(), t()) :: 0..5 | nil
  def direction_to(%__MODULE__{q: q1, r: r1}, %__MODULE__{q: q2, r: r2}) do
    diff = {q2 - q1, r2 - r1}
    Enum.find_index(@direction_vectors, &(&1 == diff))
  end
end
