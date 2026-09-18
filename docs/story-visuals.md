# 圖片與逐格動畫演出

S4-04 在對話 line 加入 `visual`，由獨立 `engine/story_visual.gd` 播放。舊版 background／portrait 路徑仍支援；同一行不能混用舊欄位與 visual。

```json
"visual": {
  "background":{"path":"res://games/fog_harbor/assets/harbor-evening-v1.png"},
  "layers":[{
    "id":"mara", "rect":[710,60,600,640],
    "animation":{
      "frames":[
        {"sheet":"mara_expressions","index":0},
        {"sheet":"mara_expressions","index":1},
        {"sheet":"mara_expressions","index":0}
      ],
      "fps":6, "loop":true, "end":"hold"
    }
  }]
}
```

## 圖片與位置

- 圖片引用使用既有 image 格式：`{"path":"res://..."}`、`{"sheet":"...","index":0}`，或舊 characters 圖集的整數索引。所有圖片仍需列入 assets，圖集需列入 visuals。
- background 以 1920×1080 設計座標顯示，保持完整圖片比例，必要時補黑邊，不拉伸、不裁切。實際視窗縮放沿用專案的畫面伸縮設定。
- layers 依陣列順序從下往上繪製，最多 8 層，id 在同一行內不可重複。
- rect 是 `[x,y,width,height]`，使用同一設計座標。寬高必須為正，整個矩形須在 1920×1080 範圍內。圖片在矩形中等比例置中；調整矩形即可控制位置與顯示大小。
- 每層二選一：靜態 `image`，或 `animation`。表情是不同圖片／圖集索引，沒有隱藏的角色表情名稱表。
- visual 完全替代該行的預設背景／角色立繪。只有 background、layers 為空，就是無立繪的風景 CG。省略 background 可在變暗地圖上疊圖；空 visual 不顯示角色。
- 每句明確配置，不沿用前一句圖片。換句、進入選項、分支切換、取消或返回標題時，舊畫面與時鐘都會移除。

## 動畫時間與結束

frames 需有 2–120 個圖片引用，fps 大於 0 且不超過 60。重複同一影格可延長停留時間；範例用多個睜眼影格加一個閉眼影格示範眨眼。生成圖的細微輪廓差異可由正式美術換成嚴格對齊影格；引擎不會自動補間或變形成 Live2D。

| 設定 | 行為 |
| --- | --- |
| loop=true、end=hold | 循環到玩家換句／取消；end=hide 不允許用於循環 |
| loop=false、end=hold | 播完一次後保持末格 |
| loop=false、end=hide | 播完一次後隱藏該層 |

一次播放的時長為影格數除以 fps；最後一格也有完整一格時間。動畫不阻擋下一句，不自行推進劇情或提交效果。自動播放、已讀快轉仍依原有文字規則前進；離開該句即釋放動畫，循環不會讓劇情等待無限久。

對話紀錄或隱藏對話框時，圖片仍顯示，但動畫時鐘暫停；返回後從原位置繼續。這是目前明確採用的行為。靜態／動畫圖片不攔截滑鼠，對話按鈕維持可操作。

## 範例及驗證

`python tools/dev.py play --game fog_harbor` 開新遊戲：拿鑰匙、開舊置物櫃、找瑪拉。閒聊開場顯示港口背景與眨眼；工作話題使用左側擔心表情；天氣話題先顯示風景 CG，再切到右側較小的笑臉。兩個分支的收尾分別示範一次播放後停格／隱藏。若已滿足郵務主線條件，請先完成優先的主線事件。

素材以內建 imagegen 生成，原檔未改像素：背景 1672×941 RGB，表情圖集 1254×1254 RGBA、2×2 格。原檔與完整提示詞存於 games/fog_harbor/assets；圖集使用固定尺寸取樣，沒有逐格自動裁切造成的縮放漂移。素材來源記錄見該目錄 README。

測試：`python -m pytest tests/test_story_visual.py -q`。涵蓋缺素材、圖集索引、圖層重名、越界矩形、非法動畫、混用欄位；原生滑鼠驗證實際貼圖、比例、位置大小、停格／隱藏、暫停／恢復、CG、表情與退出清理。既有 headless 劇情仍只執行 core，不需要等待圖片動畫。

影片播放屬 S4-05，Live2D 屬 S4-06。此階段不包含骨架動畫、圖片平移／縮放補間、跨句圖層持續或任意演出時間軸。
