# 路線、結局與紀念卡契約

目前格式位於遊戲 JSON；多檔與正式 Schema 列入 S2。角色與事件 ID 可自由命名，沒有字母加數字的限制。

```json
{
  "routes": {
    "ivy": {"events": ["arrival", "shared_promise"]}
  },
  "endings": {
    "reunion": {
      "text": "ending_reunion",
      "conditions": [{"kind": "completed", "id": "shared_promise", "value": true}]
    }
  },
  "gallery": {
    "ivy_keepsake": {
      "character": "ivy",
      "title": "keepsake_title",
      "text": "keepsake_quote",
      "conditions": [{"kind": "completed", "id": "shared_promise", "value": true}]
    }
  }
}
```

以上片段需搭配角色、事件及翻譯定義，不是完整遊戲檔。

## 路線

- 每個角色可設定一條線性路線；各路線獨立，事件只能屬於一條路線，且事件角色必須與路線角色一致。
- 第一個未完成事件才是該路線的下一事件。它仍需通過原有 AND 條件才能觸發；後面的高優先度事件不能跳過前面的事件。
- 不列入路線的事件是獨立事件，仍使用既有條件與優先度競爭。角色不一定要有路線。
- HUD 顯示「已完成路線事件數／總數」。`state.characters[who].stage` 仍是可配置的條件／效果數值，不以該數值推斷路線完成。
- 條件頁顯示下一事件的同一組 `checks()` 結果，包括 stage。不能只提高 stage 就讓未完成路線變成完成。
- 路線順序構成隱含前置依賴。若早期事件要求完成後面的事件，驗證器會回報循環。

## 結局

結局條件非空，全部成立才顯示其翻譯文字。多個結局同時成立時按 ID 字典順序選第一個。結局目前是 HUD 完成提示，不會退出遊戲或播放片尾；片尾演出不是本批交付範圍。不設定結局就不顯示完成提示。

## 紀念卡

每次成功完成事件後評估卡片條件，將解鎖 ID 寫入 profile；讀取較舊進度不會撤銷解鎖。此版本仍是文字／肖像紀念卡，非完整 CG／影片畫廊。其 ID 與角色 ID 無需相同，demo 沿用原 a/b 解鎖 ID 以相容既有紀錄。

## 相容性及驗證

demo 的事件 ID、存檔狀態與既有路線順序不變，載入後由完成事件清單重建進度，不另存一份路線計數。內容新增 `routes`、`endings`、`gallery`；沒有配置的內容不套用隱含 demo 預設。

`python tools/dev.py check` 包含三位角色、1／2／4 個事件、非規則命名、高優先度後續事件、結局、紀念卡、存讀檔與依賴循環案例。此 fixture 只用於重用回歸，不取代 S3 的第二款遊戲驗收。
