# CLI 協定 v1

公開入口是 `python tools/dev.py`。無子命令等同 check；所有內容命令接受 `--game NAME` 或 JSON 路徑，預設 demo。相對路徑以 repo 根目錄為基準。完整命令表與安裝方式見 [README](../README.md)。`--help` 是 argparse 的人類說明，不輸出協定 JSON。

## 結果

加 `--json` 時 stdout 是單一 JSON 物件，不混入 Godot／pytest 日誌。正常與預期失敗均使用以下欄位；不要解析 message 文案決定控制流程。

```json
{
  "protocol_version": 1,
  "command": "validate",
  "game": "first_story",
  "ok": true,
  "exit_code": 0,
  "diagnostics": [],
  "artifacts": {},
  "data": {"manifest": "absolute/path/game.json"},
  "duration_seconds": 0.25
}
```

diagnostics 每項有 `code` 與 `message`；內容 Schema 診斷的 message 保留來源檔案與 JSON 路徑。artifacts 是名稱到絕對路徑的映射，僅在該階段產生時出現。data 隨指令變化：list 的 games、test 的 state/steps、build 的 build_kind、check 的 scope。參數解析失敗時 command/game 可以是 null。

| Exit | 語意 | code 範例 |
| --- | --- | --- |
| 0 | 成功 | 無診斷 |
| 1 | 內容、測試或子程序失敗 | content、invalid_data、validation_failed、assertion、test_failed、process_failed |
| 2 | 指令用法、指定入口／路線不存在或建立目錄衝突 | usage、not_found、destination、unsupported |
| 3 | 環境依賴、IO 或逾時 | dependency、environment、timeout |

process_failed 訊息與日誌記錄原始子程序退出碼。缺少 Godot 不會把 test 標為成功或略過。`--timeout` 範圍為大於 0 且最多 3600 秒，預設每個非互動子程序 240 秒；大型 check 可增加期限。逾時會結束直接子程序並保留已有日誌。play/editor 是互動程序，不套期限，關閉後才有最終報告。作業系統強制終止或鍵盤中斷不保證有 JSON 結果。

## 通關情境

預設 `games/NAME/tests/walkthrough.json`；可用 `--scenario PATH` 指定另一條路線。結構由 [walkthrough.schema.json](../schemas/walkthrough.schema.json) 驗證，禁止未知欄位、content 覆寫及任意狀態注入。

```json
{
  "steps": [{"op": "wait"}],
  "expect": {"period": "evening", "money": 0}
}
```

steps 與 expect 皆不可空。expect 接受 initial 已存在的頂層狀態欄位，以及已宣告 stats／variables 與 actions；指定欄位採完整 JSON 值比較（陣列順序、巢狀物件均須相等），未指定欄位不比較。每步預設要求 response.ok=true；可用 expect_result 指定 ok／message 負例，回應數須等於步數，結束時不得有 active_event。checks/path/snapshot 是查詢；存讀檔使用當次測試目錄，沒有預先留下的槽位。`scenarios --game ID` 批次跑 tests/scenarios/*.json；失敗保留可重播 JSON。

此測試呼叫實際 core.act，但不跑對話 UI 演出。既有 pytest 的 Viewport 滑鼠測試負責介面回歸。check 跑共用測試；test 才是指定遊戲路線。

## 建置與限制

S2 的 build 先驗證內容、Godot 匯入與原生素材，再產生 Godot 原始專案 ZIP；不是 exe。包含共用 runtime、test_runner、合併後的選定內容、assets 清單中的檔案與已有匯入設定／素材來源說明。排除其他遊戲內容、測試 UI 腳本、工具、快取和存檔。原始 assets 路徑會保留，因此引用共享美術的遊戲仍會帶入該素材。

資源依賴必須全部列入 assets；不自動遞迴解析自訂 .tres 的外部資源。加入此類素材時應驗證解壓後可啟動。產物含 build-manifest.json 的 SHA-256 清單，ZIP 使用固定時間戳與排序，檔名包含內容雜湊；同內容重建回傳相同產物，不覆寫不同檔案。

解壓後使用 Godot 4.7.2 匯入 project.godot 即可啟動。Python 編輯／驗證工具仍需完整 repo。S7 另處理 Windows executable、匯出範本與發行驗收。

每次 test/check 使用獨立 run 目錄和 APPDATA，不讀手動試玩存檔。匯入快取仍屬 checkout 共用；請勿在同 checkout 並行跑匯入。builds/、test-results/、.tools/ 不提交到 Git。

## S6 擴充

`check --suite static/rules/ui/media/fast/full` 選擇測試層，預設 full。`play --dev` 啟用有標記的開發修改；只允許 play。`explore` 接受 `--max-states`（1～100000）、`--max-depth`（1～1000）、`--search-seconds`（>0～300）、可選 `--goal` 結局 ID。探索超限回傳 exit 1／inconclusive，不是通關成功也不是死局證明；一條 witness 成功也不保證所有路線。詳見 [可靠性契約](reliability.md)。

探索重播使用完整期末 state 斷言；若證據停在事件內，重播末尾會明確加 cancel_event，避免殘留演出。空路線使用 snapshot 查詢，沒有注入狀態。原始探索狀態／active_event 仍保留在 exploration.json，報告標示 replay_cancels_active_event。
