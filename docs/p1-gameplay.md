# S5-05～09：條件、行動、追蹤、庫存、回想與日期

此文件描述已實作的 JSON／Godot API。例子可參考 `games/numeric_lab`，啟動方式：

```powershell
python tools/dev.py play --game numeric_lab
python tools/dev.py validate --game numeric_lab --json
python tools/dev.py check --game numeric_lab --json
```

## 條件樹與行動紀錄

所有原本接受 `conditions` 的位置仍接收陣列，陣列代表 AND。新增非空 `all`／`any` 節點，內容驗證限制最多八層群組；巢狀引用也會驗證。`checks()` 保留每一個子節點的 `children`、`passed`、`actual`、`expected`，不因 OR 第一項成立而隱藏其他診斷。

```json
[
  {
    "kind": "any",
    "conditions": [
      {
        "kind": "action_count",
        "tags": ["work", "train"],
        "op": "gte",
        "value": 7,
        "window": {"unit": "days", "size": 3, "include_current": true}
      },
      {"kind": "day", "op": "gte", "value": 30}
    ]
  }
]
```

這裡的三天只是明確的示例政策，**不是 Homestay 的 Recent 定義**。`window` 省略代表開局至今累計；指定時三個欄位皆必填：

| 欄位 | 語意 |
| --- | --- |
| `unit: days` | 絕對日曆日；含今日的三天為今日、昨日、前日 |
| `unit: periods` | 絕對時段索引 `(day-1)*3 + period_index`，白天／晚上／深夜 |
| `size` | 正整數，窗口包含幾個單位 |
| `include_current` | true 包含目前單位；false 以剛結束的上一單位為窗口末端 |

事件可加 `"action_tags": ["work", "train"]`。只有成功完成事件才寫入一筆 `state.actions`，包含 `event`、`tags`、`day`、`period`。時間戳是**提交效果後、消耗 time_cost 前**的日期／時段。同一筆紀錄符合多個 tags 仍只計一次。分支中途、取消、效果失敗、重複完成回呼、讀檔、回想都不新增。條件中的標籤必須至少由一個事件宣告。

目前完整保存紀錄，不截斷、不近似，所以任意已宣告窗口與累計都可精確查詢。超長遊戲的壓縮另屬效能工作。舊存檔缺少 `actions` 時初始化為空；不從 `completed` 猜測過去重複事件次數。非法標籤、未來／逆序時間戳等會拒絕載入並保持現有狀態。更改既有事件標籤時須安排內容／存檔遷移，不能直接刪除舊標籤。

## 可用標記與非線性追蹤

NPC 的 `!` 使用目前 target 上下文下的 `event_candidates()`，物件使用同一事件條件／路線／完成狀態判定，也檢查所需物品。地點／區域依目前玩家所在位置判定；標記不是移動至物件後的預測。按下互動時仍重新檢查位置與條件。

在 manifest 根節點加入：

```json
"tracking": {
  "guide": [
    {"event": "milestone", "reveal": "always"},
    {"event": "course", "reveal": "available"}
  ]
}
```

tracking 只決定顯示，事件不必屬於該角色，也不限制順序。既有 `routes` 仍強制線性順序，兩者可並存。`reveal` 預設 `always`；`available` 在條件可用或完成後揭露，`completed` 僅完成後揭露；其他情況顯示鎖定占位。開發模式顯示完整條件。條件樹會顯示能力值、日期、地點、完成紀錄、AND／OR 與行動計數；能力完整值仍由既有狀態面板查看。

## 庫存

```json
"shops": {
  "kiosk": {
    "snack": {"price": 1, "unlimited": true},
    "voucher": {"price": 1, "capacity": 2, "restock": "daily"}
  }
}
```

無限商品不需要 `initial.stock`，不減少或建立假庫存；禁止混用 `stock`／`capacity`／`restock`。購買仍檢查金錢、商店可達性及物件條件。

有限商品沿用 `initial.stock["shop:item"]`，未配置庫存視為零。`capacity` 是可選上限；`restock: daily` 必須指定 capacity。成功的時間推進跨過日界時直接補至 capacity，跨多天也只補至上限。日內刷新／讀檔不觸發補貨；持久化的絕對 day 就是日界游標，不額外維護容易失同步的 last-restock 旗標。取消、回想與交易回滾不會偷偷補貨。

明確效果也可補貨：

```json
{"kind": "stock", "shop": "kiosk", "id": "voucher", "op": "add", "value": 1}
```

`add` 在目前庫存上增加；`set` 替換為非負整數。禁止作用於無限商品。超出 capacity／安全整數界線會拒絕整筆效果交易，不截斷，也不留下先前的扣款／獎勵。存檔中的超限庫存同樣拒絕載入。

## 完整事件回想

在原畫廊卡片加入 `"event": "milestone"`。其他欄位（character、title、text、conditions）維持既有契約；conditions 負責 profile 解鎖。已解鎖卡片若有 event，優先啟動完整事件；沒有 event 的舊卡片維持圖片／影片／紀念卡行為。

`core.replay_session(card_id, unlocked)` 檢查卡片解鎖及事件引用，建立獨立內容／狀態副本。回想播放器使用獨立 profile 與對話紀錄，不暴露正常存檔 UI。事件／選項的玩法門檻不生效，但分支 `next`、對話、媒體與取消仍照原結構運作。所有玩法效果都略過，不能利用回想領獎、耗時、補貨、記錄行動或解鎖新畫廊。

正常結束、取消、影片跳過後取消、缺少影片會清理播放器並回到畫廊。缺影片自動結束回想；正常遊戲的影片錯誤介面維持原行為。回想不写 profile 已讀、解鎖或存檔；在回想 core 呼叫 save/load/world 操作會拒絕。

本次不加入劇情局部變數系統；目前分支依 `next` 選擇，狀態效果不作為回想內的分支計算機制。

## Extra Day 顯示

manifest 根節點：

```json
"date_display": {
  "normal_days": 90,
  "normal_text": "date_normal",
  "extra_text": "date_extra"
}
```

語系鍵各需恰好一個 `{day}`，例如英文 `Day {day}`／`Extra Day {day}`，繁中 `第 {day} 天`／`延住第 {day} 天`。`core.format_day(day, language)` 同時供 HUD、存檔摘要與玩家條件提示使用。90→Day 90、91→Extra Day 1、92→Extra Day 2；未配置保留 DAY 顯示。

真正 state.day、存檔、條件、排程、行動窗口永遠使用絕對日期，不會把 91 改成 1。numeric_lab 刻意用三天界線方便試玩；這不是遊戲的正式營運／延住規則。

## 驗證範圍

沿用 numeric_lab：開場、訓練、工作、物件入口、計數與日期兩條 OR 路線、非線性追蹤、商店、存讀檔、回想、Extra Day。普通通關路線不用注入狀態；毀損存檔與媒體故障測試才使用刻意破壞的測試資料。

此合成範例完成 S5-12B 的引擎整合證據，**不代表 Homestay 實際內容已匯入或完成首月验收**。S5-10 跨句持續動畫、S5-11 無選項自動結束仍未交付。
