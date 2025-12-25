# Overview

wg-sandbox (not final name) is a turn-based strategy war game modeled after the Talonsoft series of games from the 1990s. Players select a scenario to play, vs AI or another player, and various options when they start a new game (an instance of a scneario).

We as game authors will need map tools, primarily a map editor, as well as a scenario editor, in order to develop the various playable scenarios. The game will also support a campaign mode which is a specific list of scenarios to complete, in order, with a success criteria needing to be achieved in a scenario in order to progress to the next one.

A scenario contains a map, a start and end time (which implies a total number of turns), the start date, the starting force_id (who goes first), the turn scale (how long is a turn, default 20 minutes/day, 1 hour/night), and the order of battle for each side in the scenario. The order of battle is the list of units, when they nominally become available (this can be modified during game play by various factors), and where they become available (units present at the beginning will be located in their starting position/orientation; reinforcments will specify the hex where they enter the map when they arrive). It also contains a list of objectives for each side.

Each force will have a variety of unit types available to it. A unit has an id, a type, a category_type, a force_id, full_strength size, current_strength size, rendering_id, location, orientation(edge number), state(ready, at ease, uncrewed, destroyed).

Each force plays during each game turn, in the order specified by the scenario's starting force_id. For each force the play proceeds in segments: movement, ranged attacks, melee attacks then reinforcements applied (if any).

# Landing Page

This is the main URL for the game and its associated features.

# Map Editor Features

Users can create, update, save, load and delete maps. A map has a name, a version number, a centerpoint(lat/long), a scale (meters/hex), a size (width and height in numbers of tiles), and a base elevation.

Each hex/tile has a differential_elevation(meters), a type, a category_type, edge types, and zero or more transportation segments.

## Menus and Controls

### New Map: Create a new map from scratch [button/menu or ctrl-N or cmd-N]

#### Popup dialog to set options for new map
- width
- height
- per-tile scale (100/200/500/1000/2000/5000/10000 meters)
- base elevation
- centerpoint (lat/long)

### Update Map Options -> like New Map [button/menu]
Users can update the map options that they set when creating the map

### Satellite Image Overlay
Based on the centerpoint, fetch a satellite image for the locale, scaled and cropped to match the map location and scale, and overlay it onto the map being created at a variable opacity. The overlay will be left and available (as an option) for use during actual gameply, but its primary purpose is to guide the map author in designing the map.

### Save Map
Obvious

### Load Map
Obvious

## Terrain types

Each terrain type will have multiple renderings, or versions, available, numbered, to select from when building a map. There will be 2D and 3D versions of each of the available renderings for use in those map display modes. Each terrain type will have potentially multiple movement penalties for different categories of units, in terms of percent reduction to base speed. So for example a clear terrain tile will have 0% penalty for any unit category. Marsh will have a 30% penalty for foot units and a 50% penalty for tracked units. The penalties are not intrinsic to the map, but rather the scenario.

### Clear
- Wide variety of renderings available
- Pasture, farm fields, farms, hamlets

### Forest
- Wide variety of renderings available
- Pine v deciduous v high elevation

### Marsh
- Wide variety of renderings available
- Louisiana vs. Gaudalcanal vs. Bangladesh

### Orchard
- Wide variety of renderings available
- Apple, pear, orange, pecan, walnut, almond, cherry

### Town/Light Urban
- Wide variety of renderings available

### City/Heavy Urban
- Wide variety of renderings available

### Industrial Park
- Wide variety of renderings available

### Desert

### Semi-Arid

### Tundra

### Arctic

### Freshwater Lake

### Frozen Freshwater Lake

### Ocean

### Frozen Ocean

## Tile Edge Types

Water features other than bodies of water will be aligned along the edges of tiles. When units cross the edge of a tile, they may incur a movement penalty depending on the category of the unit. For example, a foot infantry unit might have a 50% movement reduction when crossing a stream, while a medium tank unit might only have a 10% penalty. The penalties are not intrinsic to the map, but rather the scenario.

- None (default)
- Intermittent stream
- Stream
- Small River
- Large River

## Transport Overlays

A tile may have various transport systems crossing it. More than one transport segment of a given type may be present in a tile. Each segment has one or more entry edges and zero or more exit edges and all meet within the tile. There will be at least one rendering/version available to select from for each transport type/entry-exit-combo/terrrain type.

- Trail
- Small unpaved road
- Large unpaved road
- Small paved road
- Large paved road
- Railroad track
- Runway

## Objectives

A tile may have zero or more game objectives defined on it (typically zero or one). A game objective has a name, the force id of the force that has the objective, the hex address, and a point value assigned to it. The last force that entered the tile is considered to own it, from an objectives persepctive. It doesn't need to be always occupied to count for one force or another.

# Scenario Editor

## Movement Penalties

Movement penalties per terrain type/transport segments/unit category_type are specified at the scenario level. For example, a marsh with no transport segments would have a 30% movement penalty for foot units, a 50% penalty for tracked units, and a 75% penalty for wheeled units.

Movement penalties per edge type/unit category_type are also specified at the scenario level. For example a clear segment with all clear edges would have a 0% penalty for foot units, a stream edge would have a 50% penalty and a river edge would have a 100% penailty.

# Unit Editor

Game authors will need the ability to create new units and even new categories of units, but this is an advanced feature left for later.

## Unit Types And Categories

Units will be of a specific type, and each unit_type is a member of a unit_category. Each unit_category has a base movement speed, range and melee attack powers as well.

# General Gameplay

# Player v AI Gameplay Features

# Player v Player Gameplay Features

