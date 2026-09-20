# 主角、主題與素材配置

本文件對應 S1-03；以下為遊戲 JSON 片段。完整 JSON Schema 仍在 S2。

```json
{
  "protagonist": "traveler",
  "default_language": "zh_TW",
  "avatars": {
    "traveler": {
      "portrait": {"sheet": "cast", "index": 0},
      "sprite": {"sheet": "cast", "index": 3}
    }
  },
  "presentation": {
    "font": "res://games/my_game/assets/body.ttf",
    "palette": {"panel": "473449", "button": "664b68", "hover": "855f87"},
    "title": {
      "eyebrow": "brand",
      "title": "title",
      "subtitle": "subtitle",
      "chapter": "chapter",
      "layers": [
        {"image": {"sheet": "cast", "index": 0}, "rect": [1040, 170, 500, 720]}
      ]
    },
    "world": {
      "wall": {"sheet": "interior", "horizontal": 2, "vertical": 3},
      "icons": {
        "pickup": {"sheet": "town", "index": 12},
        "switch": {"sheet": "town", "index": 5}
      }
    }
  }
}
```

`protagonist` 必須存在於 avatars，劇本中該角色發言的 speaker 也使用此 ID。角色台詞名稱、標題四個文字欄位均使用翻譯鍵。主角不必是有好感度／路線的 NPC。

肖像、地圖角色、標題圖層與物件圖示共用圖像引用：`{"sheet":"名稱","index":格位}` 或 `{"path":"res://...png"}`。圖片路徑需列入 assets；圖集需在 visuals 中定義。舊版數字引用仍相容，表示 characters 圖集的格位；新內容應使用明確引用。繪製維持比例、置中且底部對齊。

標題 layers 是由後到前的順序。rect 使用 1920×1080 設計座標 `[x,y,width,height]`，可使用角色、Logo 或背景圖片；圖層目前在文字 UI 下方。省略 layers 時不再出現任何 demo 人物。背景仍有通用雙圓裝飾，可用透明 title_outer／title_inner 隱藏。

字型可配置 TTF／OTF 或 Godot Font `.tres`，需列入 assets。省略時使用 Godot 備援字型。測試中的 SystemFont 資源只驗證切換機制，不是可攜式字型交付；正式遊戲應附具備適當授權的字型，相關清單在 S8-03。字型必須涵蓋目標語言，跨系統字型一致性屬 S7 驗收。

可配置 palette：background、text、panel、border、button、hover、accent、muted、success、warning、shade、title_outer、title_inner。使用 RGB 或 RGBA 十六進位字串；未指定的鍵使用框架預設值。角色名稱色仍由 characters 的 color 定義。這是 UI 主題，並不會重新上色所有地圖素材。

地圖需指定 floor_sheet；家具／裝飾需指定 sheet。地圖 materials 可用圖格索引字串指定紋理 repeat 與 tint，例如 `"materials":{"0":{"repeat":3,"tint":"b6c8ac"}}`。repeat 至少為 1。牆壁及拾取／開關圖示讀取 presentation.world，沒有指定時不繪製對應圖像；碰撞仍由地圖資料決定。

紀念卡標題、肖像與解鎖見 `routes.md`。目前仍不包含正式 CG／影片畫廊、每個畫面的任意布局編輯或多解析度驗收。
