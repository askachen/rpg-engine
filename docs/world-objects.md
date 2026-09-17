# NPC 排程與物件互動

S4-02 的資料契約。內容仍由 JSON 編輯，不需要 Godot 編輯器。

## 出現與互動條件

所有地圖物件都可選填 `visible_when`，使用既有 AND 條件格式。未滿足時，物件不繪製、不接受點擊、不阻擋路徑，也不能直接用 ID 互動。省略或空陣列代表可出現。

既有 `conditions` 保留原意：控制互動是否可用，未滿足時仍可顯示鎖定提示；為相容既有內容，此時也不形成物件碰撞。不要把這個欄位當作隱藏條件。

## NPC 排程

在原本 NPC 定義上加入 `schedule`。NPC 保留單一 ID，跨地圖時不必複製定義：

```json
"schedule": [
  {"map":"workshop", "position":[19,12], "conditions":[
    {"kind":"period", "value":"evening"},
    {"kind":"flag", "id":"harbor_note_found", "value":true}
  ]},
  {"map":"quay", "position":[16,9], "conditions":[
    {"kind":"period", "value":"evening"}
  ]},
  {"map":"quay", "position":[14,7], "conditions":[]}
]
```

由上往下取第一個滿足的條目。沒有任何匹配時 NPC 不出現；最後的空條件是明確的 fallback。未設定 schedule 時，使用原本所在地图及 position。排程切換是離散換位，目前不播放 NPC 自行走到新位置的動畫。

`core.map_objects(map_id)` 是當前位置的唯一解析入口；省略 map_id 使用玩家目前地圖。繪圖、hover、點擊、互動、商店與尋路都使用它。解析不修改內容檔，位置由當前時段與旗標推導，存讀檔後重新解析。

驗證器檢查排程地圖、條件引用、邊界、牆、實體家具、出生點與其他物件的可能位置。為避免不確定的重疊，**即使兩條排程條件互斥，不同物件也不能共用排程位置**。相同 NPC 的不同條目可以共用位置。

玩家仍可能先走到 NPC 將抵達的格子。若後續非移動操作會讓玩家被實體物件占住，core 回傳 `world_blocked` 並還原整次狀態變更；請移開再重試。若是在提交對話選項時發生，會退出該次對話並回到地圖，事件仍未完成，避免玩家無法移動。每一步移動都重新檢查碰撞，舊路徑失效時停止。

## 調查與指定物品

```json
{
  "id":"harbor_locker", "kind":"inspect",
  "label":"harbor_locker", "position":[10,10], "solid":false,
  "text":"harbor_locker_text",
  "required_item":{"id":"locker_key", "count":1, "consume":true},
  "effects":[{"kind":"flag", "id":"harbor_note_found", "value":true}]
}
```

`label` 與 `text` 都是翻譯鍵。沒有 required_item 就是一般調查；effects 可省略。指定物品時，玩家點擊物件後看到所需物品與數量，再按「使用物品」確認；不足時按鈕停用。這是指定物品互動，完整背包選物／自由使用仍屬 S4-09。

程式呼叫為 `{"op":"interact","target":"harbor_locker","item":"locker_key"}`，公開 walkthrough Schema 也接受 item。缺少、錯誤或數量不足回傳 `item_required`，不修改狀態。扣除物品與 effects 視為同一次交易；任何效果失敗全部還原。`consume:false` 只檢查持有數量。

`repeatable` 預設 false：第一次成功後記錄 state.objects[id]，後續仍可讀取文字，但不再次要求物品或發放效果。設為 true 則每次成功都重新檢查物品並執行效果，作者應避免不小心製造無限獎勵。inspect 不會像 pickup／switch 一樣完成後消失；可自行用 visible_when 控制。

## 手動驗收

執行 `python tools/dev.py play --game fog_harbor`，開新遊戲：

1. 點左側「港口告示」閱讀時間提示。
2. 點「舊置物櫃」確認缺鑰匙時無法使用；返回地圖。
3. 拾取左下鑰匙，再點置物櫃並按「使用物品」，讀取便條。
4. 按等待到晚上，瑪拉會從碼頭移到工坊右下方；可走近並對話。
5. 未開櫃就等待到晚上時，瑪拉改在碼頭散步；深夜回郵務桌。

自動測試：`python -m pytest tests/test_objects.py -q`。既有兩條故事通關路線也必須繼續通過。這些指定案例不代表已證明任意作者內容皆無死路。
