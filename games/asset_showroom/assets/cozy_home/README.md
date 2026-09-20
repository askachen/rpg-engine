# Cozy Home v1 — 48 built-in map props

Three original RGBA atlases generated with the built-in image generation tool.
Exact prompts are preserved beside each PNG. Original pixels are unchanged.
`catalog.json` specifies stable IDs, source rectangles, recommended tile sizes,
layers and collision defaults. Source rectangles are normalized to the **whole image**;
each installed visual uses a 1×1 sheet and explicit region 0. This avoids cutting
sprites at approximate generated grid boundaries. Each PNG is registered once in assets.

From the engine root:

```powershell
python tools/asset_pack.py list
python tools/asset_pack.py install --game my_game
python tools/asset_pack.py place sofa --id lounge_sofa --at 5 6
python tools/dev.py validate --game my_game
python tools/dev.py play --game asset_showroom
```

Create `my_game` with `python tools/dev.py new --game my_game` first.
Install copies artwork and provenance into the game and registers its visuals.
It is repeatable and refuses conflicting files/visual IDs; it does not alter maps.
`place` prints a collection name and value: append the value to that collection in
your map JSON. The output is ordinary engine data, not a new runtime format.
Use a unique instance ID per placement. Installation is optional for new games.

Scale convention: one tile is approximately half a metre; a double bed is 3×4,
a single bed 2×4, sofa 4×3, dining table 3×2, chair 1×2. The engine fits the source
without stretching within this rectangle. Solid furniture blocks its complete
rectangle; it does not have pixel-perfect collisions. Keep at least one tile of
walking space between solid objects. Rugs use floor layer and are non-solid.
Wall art, windows, lamps and doors use decorations; add wall collisions and exit/
inspect/switch events separately. Doors are static sprites, lamps are baked art,
wall panels are frontal decorative sections, **not an autotile wall system**.
Do not rotate these frontal wall panels into side walls.

The showroom is a catalog layout, not a furnished story level: all 48 entries are
visible across three connected rooms, with a simple ordinary-input story route.
Open `asset_packs/cozy_home/index.html` for an offline searchable visual catalog.

Provenance: generated for this project, 2026-09-20, using built-in imagegen;
no third-party reference images supplied. This record is not independent rights
clearance; project-wide redistribution/release review remains tracked in S7.
