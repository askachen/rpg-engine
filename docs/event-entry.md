# 日期、地點與完整事件入口（S5-02～04）

本批重用 numeric_lab，並完成 S5-12A 的通用 P0 整合案例；不代表真正 Homestay 已匯入或全選項可通關。

## 條件

以下可以放進事件或選項 conditions，與既有條件以 AND 組合：

```json
[
  {"kind": "day", "op": "gte", "value": 2},
  {"kind": "map", "id": "room"},
  {"kind": "target", "id": "work_desk"},
  {"kind": "zone", "map": "room", "id": "lobby"}
]
```

- day 比較絕對日期，op 為 eq/ne/lt/lte/gt/gte，內容中的 value 是 1～9007199254740991 的整數；可同時限制 period。NPC schedule、顯示條件及事件使用同一個 checks 評估器。深夜再花一時段會進入下一天。
- map 比較玩家目前地圖；target 比較這次互動物件的 stable ID。沒有互動上下文時，target 條件不通過，不能只靠 NPC 的角色 ID 推斷入口。
- zone 比較玩家所在格，非 NPC 所在格。地圖 zones 可增加可選 id，例如 `{"id":"lobby","rect":[1,1,8,5],"floor":0}`。左／上邊界包含，右／下排除；重疊區域可同時符合。zone 的 map 必須匹配，目前不支援跨圖區域。
- 既有沒有 id 的地板 zones 保持原行為；具名區域不得重複 ID 或超出地圖。地圖、物件、區域引用由 validate 檢查。

核心 `checks(conditions, context)`／`satisfied(conditions, context)` 接受可選 context，`event_candidates(character, context)` 使用同一評估器。GUI 從實際附近物件取得上下文顯示下一事件條件；不在適當入口時 target 會顯示未滿足。觸發及提交時重新檢查，NPC 消失、移走或玩家不再鄰近均不能提交。

日期顯示仍為絕對 Day；Extra Day 是 S5-09，非本批。target 條件適用互動事件／選項；沒有互動來源的排程／畫廊判定不可依賴 target。

## 物件與探索完整事件

inspect 可增加 event 指向完整事件。仍保留 text 作為一次性物件已完成後的提示：

```json
{
  "id": "work_desk", "kind": "inspect", "position": [3,5],
  "label": "work_label", "text": "work_line",
  "event": "work", "repeatable": true
}
```

完整 event 可省略 character；sequence 的 speaker 仍指向合法 avatar。未提供 sequence 的舊格式回退到事件 text；省略 character 時以主角作為回退 speaker。若要限定由物件啟動，省略 character 並使用 target 條件；有 character 的一般事件仍可能由相符 NPC 候選選到。

物件的 repeatable 必須和事件一致。event 入口不得同時宣告物件 effects，請把獎勵與狀態變更放在事件 effects。沒有 event 的 inspect 仍維持立即提示／效果契約。

可重複工作／訓練是普通 repeatable 事件；探索沒有收穫時可用空 effects 加 time_cost:1，結束後仍耗時。此批探索採玩家點擊入口，沒有每幀掃描或進區即自動觸發系統。

required_item 保留原 id/count/consume 定義。點擊入口時先確認所選物品及數量，**成功完成事件才一起消耗**；取消、效果失敗、重入、重複回呼不再扣一次。提交時再次確認物件、距離、條件及物品。成功記錄 completed 與物件狀態並套用 time_cost；分支及取消沿用原事件生命週期。

## 開場

在 manifest 根層設定 `"opening_event":"opening"`。此事件須存在、conditions 為空、不可 repeatable、不可放入 routes 或 initial.completed，也不能作為 inspect 的 event；NPC 候選不會選到它。

真正建立新局時先播放完整開場並鎖住一般世界操作；事件期間仍不可存檔。完成後回地圖，effects／time_cost 只提交一次。選擇取消或離開對話表示跳過開場，不發獎、不記完成，仍回地圖；之後讀檔不重播，新建另一局才重新播放。

`core.load_content()` 僅載入並初始化，不播放。GUI 新遊戲與 headless test_runner 都會呼叫 `core.new_game()`，從同一 active_event 開場；walkthrough 必須先 choose／cancel_event，不能忽略它直接 move。讀檔不呼叫 new_game，因此不會誤觸開場。

## 試玩與驗證

```powershell
python tools/dev.py play --game numeric_lab
python tools/dev.py test --game numeric_lab --json
python -m pytest tests/test_entries.py tests/test_numeric.py -q
```

試玩：完成開場→撿錢→與小晴訓練兩次及測驗→等待進入 Day 2→點工作桌→点探索點→到商店買茶→點課程入口並使用茶。最後進入 Day 3、CHA=1、金錢=9；普通通關路線最後存讀檔檢查狀態。負例另檢查錯日期／地圖／target／區域、取消、失敗回滾、NPC 跨圖排程及選項提交前的上下文改變。

基本物件與耗時事件已交付；OR／行動計數、! 提示、無限庫存、無副作用回想等仍屬後續 S5。
