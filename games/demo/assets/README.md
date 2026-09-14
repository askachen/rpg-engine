# Home interior atlas v1

Generated with the built-in image_gen tool on 2026-09-13. The original PNG, including alpha, is copied into this project unchanged. Runtime atlas regions are selected by `engine/main.gd`; there is no external editing or asset download dependency.

File: `home-interior-atlas-v1.png`. Four columns × four rows. Cells are addressed 0–15, row first; calculate cell size from the actual image dimensions rather than assuming the requested generation resolution.

| Row | Column 1 | Column 2 | Column 3 | Column 4 |
| --- | --- | --- | --- | --- |
| 1 | Oak floor | Tile floor | Horizontal wall | Vertical wall |
| 2 | Bed | Sofa | Dining table | Wardrobe |
| 3 | Stove | Sink | Refrigerator | Toilet |
| 4 | Bathtub | Desk | Plant | TV console |

Furniture placement and collision rectangles live in `games/demo/game.json`; they are independent of the raster image and can be reused in other maps.

Exact generation prompt is recorded in `home-interior-atlas-v1.prompt.txt`.

## Visual pass v2

All new PNGs were generated with the built-in image_gen tool and copied unchanged into this directory. Exact prompts accompany each image.

| File | Grid | Contents | Prompt |
| --- | --- | --- | --- |
| [home-decor-v2.png](home-decor-v2.png) | 3×3 | Sage/Persian/blue rugs, curtains, coffee table, plant, botanical art, bookcase, entry mat | [Prompt](home-decor-v2.prompt.txt) |
| [characters-v1.png](characters-v1.png) | 3×2 | Player, Haru and Rin: adult bust portraits above, corresponding chibi map avatars below | [Prompt](characters-v1.prompt.txt) |
| [town-v2.png](town-v2.png) | 4×4 | Grass, paving, roof, stone; bench, lamp, flowerbox, tree; shop, house, shelves, checkout; purse, door, fountain, flowerpots | [Prompt](town-v2.prompt.txt) |

`engine/art_library.gd` measures opaque bounds once, caches AtlasTextures, keeps prop/character aspect ratios, and repeats material textures at world scale. The coffee-table cell has an explicit source region because the neighboring generated curtain extends across its cell edge. Runtime sampling preserves the source PNG and its alpha.

Map avatars currently use standing artwork with movement bobbing. Directional walking frames, facial-expression variants and Live2D are not yet included.


### 劇情示範音訊

- `coffee-ambience-v1.wav`：16 秒、單聲道 22050 Hz、16-bit PCM，正弦和弦合成的簡單背景音樂。播放時循環。
- `cup-chime-v1.wav`：0.45 秒合成提示音。

兩者為程式合成的示範音色，沒有使用外部錄音；不代表正式配樂。此次嘗試使用內建 imagegen 製作咖啡背景時回傳 usage_limit_reached，未產生新圖片檔案。
