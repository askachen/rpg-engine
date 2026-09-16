# 四方向面向與行走影格

avatars 可選擇新增 walk 配置。portrait 與 sprite 仍必填，舊內容沒有 walk 時維持原本站立素材；不會把舊角色轉成其他人物的動畫。

```json
{
  "walk": {
    "fps": 10,
    "idle_frame": 1,
    "down": [{"sheet":"noah_walk","index":0},{"sheet":"noah_walk","index":1},{"sheet":"noah_walk","index":2},{"sheet":"noah_walk","index":1}],
    "left": [{"sheet":"noah_walk","index":3},{"sheet":"noah_walk","index":4},{"sheet":"noah_walk","index":5},{"sheet":"noah_walk","index":4}],
    "right": [{"sheet":"noah_walk","index":6},{"sheet":"noah_walk","index":7},{"sheet":"noah_walk","index":8},{"sheet":"noah_walk","index":7}],
    "up": [{"sheet":"noah_walk","index":9},{"sheet":"noah_walk","index":10},{"sheet":"noah_walk","index":11},{"sheet":"noah_walk","index":10}]
  }
}
```

以上是 avatar 內的局部片段；素材仍須登記 assets 與 visuals。每方向 2–32 個影格、fps > 0 且 <= 60、idle_frame 為各方向陣列內有效索引。每格沿用既有圖片引用格式，可指圖集或獨立圖片；驗證器檢查素材宣告、圖集索引與 idle 範圍。四方向必須完整配置，避免缺方向時突然變成另一張圖。

## 行為

- actor_motion 保存呈現用朝向與動畫時鐘，不修改 core.state、座標、碰撞或存檔格式。
- 滑鼠與鍵盤移動皆更新朝向；撞牆可轉向，但不播放成功行走。
- 移動中依 fps 循環，跑步依既有移動速度比例加快。最後一步結束後回到該方向 idle_frame。
- 右鍵停止、開選單、對話及換圖會停止步態；新遊戲、讀檔及繼續遊戲重設呈現狀態。朝向不寫入存檔。
- 相鄰互動時主角轉向物件；NPC 同時轉向主角。NPC 若未配置 walk，仍顯示舊 sprite；NPC 自動移動／排程屬於 S4-02。
- world renderer 依 motion.image_spec 選取資源，有逐格動畫時不再套用舊的浮動步態。

## 本批素材

霧港的 noah 主角使用 imagegen 生成的 noah-walk-v1.png：1086×1448、透明 RGBA、3 欄×4 列，每格 362×362。各列為下、左、右、上，三個姿勢以 0→1→2→1 循環。原始 PNG 未修改，完整生成提示詞同目錄保存。

visuals 使用固定寬高的 regions 與 opaque，跳過逐影格 alpha 自動收邊；僅調整取樣位置對齊各格人物，不讓走路時體型忽大忽小。這是 runtime 圖集取樣配置，不是對 PNG 重新繪製。生成圖的手腳姿勢仍可能有細微差異，正式美術可用同一資料格式替換。

目前只為霧港主角新增方向素材；demo、first_story 及其他 NPC 的現有美術仍保留。引擎能力與全角色素材製作是不同範圍。

## 驗證

`python -m pytest tests/test_motion.py -q`：缺方向、空影格、非法 fps、idle 越界、未宣告素材、圖集索引越界，以及實際滑鼠四向移動／停止／互動、步態切換、跑步時鐘、撞牆、暫停與舊素材相容性。

實際 NVIDIA 渲染器下另檢查四方向截圖，保存為 test-results/motion-up.png、motion-down.png、motion-left.png、motion-right.png。圖片只作本機驗收，原素材與配置則隨內容包提交。
