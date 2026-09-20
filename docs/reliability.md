# S6：存檔可靠性、診斷與有界驗證

## 存檔格式與版本

新存檔寫入 `version: 2`；結構見 [save.schema.json](../schemas/save.schema.json)，內容引用與碰撞由 Godot `save_contract.gd` 再驗證。`game_id`、`content_version`、`saved_at`、`developer` 與完整 `state` 是存檔信封欄位。

驗證涵蓋數值型別／範圍、日期／時段、座標與實際可走位置、角色巢狀欄位、道具／庫存／物件／旗標／事件引用、重複完成紀錄、能力／變數與行動紀錄。布林值不能冒充整數。旗標 ID 由初始 flags 與內容中的 flag 條件／效果收集。未知 state 欄位、不相容版本、未來內容版本皆拒絕。失敗只回傳原因，不能改動當局或偷偷讀備份。

| 版本情況 | 行為 |
| --- | --- |
| 舊存檔格式 v1 | 在記憶體升級為 v2；缺少 content_version 視為 1、缺少 saved_at 使用檔案時間、developer 預設 false |
| v2 缺少必要 metadata | 視為損壞，不冒充 v1 |
| 未知存檔格式／未來內容版本 | 拒絕並提供原因 |
| 舊內容版本 | 必須有明確的 forward migration chain；保留既有 demo 的 reposition_before_version 相容入口 |
| 缺少新 stats／variables／actions | 沿用 S5 定義初始化；不捏造未記錄的舊行動 |

`core.read_save(path)` 回傳正規化的資料或空字典，`core.save_error` 是機器可讀原因，如 `unsupported_save_version`、`future_content_version`、`missing_content_migration:1`、`invalid_inventory:foo`。`load_game` 只有在全部通過後才替換 live state。讀取不直接改寫原始檔，下次明確存檔才寫 v2。

內容版本升級例子：將根層 `version` 從 1 提高為 2，並加入：

```json
"save_migrations": [
  {
    "from_version": 1,
    "to_version": 2,
    "renames": {"stats": {"old_INT": "INT"}}
  }
]
```

可 rename 的群組為 `stats`、`variables`、`inventory`；inventory 改名會同步對應庫存的 item ID。目標碰撞、重複起點、倒退版本會拒絕。純相容升版也需明列 from/to，可省略 renames。這是可擴充的遷移入口，**不支援任意腳本遷移或任意 map／character 改名**；新增此類轉換時要擴充契約與測試。既有地圖 reposition 仍先拒絕越界座標，再重設合法位置。

## 槽位備份與復原

槽位仍為 0 自動、1～6 手動。每次寫入依序：

1. 驗證候選資料。
2. 寫同目錄 `.tmp`、flush、重讀驗證。
3. 若既有主檔有效，經 `.bak.tmp` 寫入／驗證，再 rename 為 `.bak`。
4. rename 新 `.tmp` 為主檔，不先刪除主檔。

只有上一份**有效主檔**能替換備份；壞主檔不能污染好備份。啟動／載入忽略未完成的暫存檔。遇到寫入／備份／replace 失敗會回傳 false 並保持主檔可用。這是本機檔案系統的中斷防護，不宣稱能抵抗所有磁碟故障或突然斷電的硬體快取遺失。

讀檔頁顯示壞檔原因及「復原備份」入口。復原需確認，以有效 `.bak` 替換主檔，之後由使用者選擇載入；不自動退回較舊進度。刪除也需確認，會清除該槽位主檔、備份及殘留暫存檔，摘要隨即更新。取消確認不動檔案。

API：`SaveSlots.restore(slot)`、`delete_slot(slot)`；`details()` 新增 `reason`、`recoverable`、`backup`、`backup_exists`。有效的備份不會被 `latest()` 當成有效主檔，避免 Continue 靜默倒退。

本批備份範圍是單局槽位。跨局 profile 設定／解鎖仍使用既有獨立持久化機制，沒有新增 profile 復原 UI。

## 開發診斷與修改標記

預設開發面板為唯讀，列出當前各物件上下文的事件候選／完整條件樹、來源內容檔案、最近操作的 event／node／step 與逐路徑 state diff。情境 runner 額外記錄原始 scenario 路徑與 scenario_step。

要啟用修改：

```powershell
python tools/dev.py play --game numeric_lab --dev
```

面板提供 JSON 指令輸入，所有指令經 `core.act()` 驗證：

```json
{"op":"debug","action":"set","group":"stats","id":"INT","value":2}
{"op":"debug","action":"teleport","map":"room","spawn":"entry"}
{"op":"debug","action":"event","event":"work"}
```

set 只支援有定義的 stats／variables，遵守數值上下限；teleport 只接受已定義 spawn 並檢查可走；event 是指定事件的正式啟動，仍遵守入口、條件與 route，沒有默默強制發獎。正常演出與回想期間不能重入。

成功修改／指定啟動後，HUD 與存檔摘要標記 `[DEV]`，存檔 `developer: true` 持久保留；開新局才清除。這不是反作弊機制。release build 由 `OS.has_feature("debug")` 硬性封鎖修改，release 也不顯示診斷面板；測試另以 `--release` 在 editor binary 模擬封鎖。真正 Windows release 產物已在 S7 驗證，見 [發行契約](windows-release.md)。

## 防卡關情境與重播

```powershell
python tools/dev.py scenarios --game numeric_lab --json
python tools/dev.py scenarios --game demo --json
```

依序執行該包 `tests/scenarios/*.json`，每條使用新局與隔離的存檔。沿用公開 walkthrough 結構，所有動作呼叫原生 core；新增每步可選 `expect_result`：

```json
{"op":"buy","shop":"kiosk","item":"tea",
 "expect_result":{"ok":false,"message":"insufficient_money"}}
```

省略仍要求 ok=true。負例預期只接受 ok／message；未知狀態注入指令仍拒絕。期末 expect 採完整欄位比較，結束時不得殘留 active_event。失敗報告保留原始路線、回應、前後 state、diff 與可供 `test --scenario` 重跑的 JSON。

已納入：兩位角色先後順序、取消選項、錯過時段後等下個週期、買其他商品導致金錢不足後靠工作恢復、消耗共用道具後拒絕再次使用，並交錯存讀檔。這是有意義的情境集，不是所有組合的完備證明。

## 有界可達性

```powershell
python tools/dev.py explore --game numeric_lab --max-states 1000 --max-depth 30 --search-seconds 10 --json
```

先做內容／必要素材引用驗證、Godot 匯入與原生素材 probe，再以 BFS 執行真實 `core.act` 的 move、wait、interact、buy、choose、cancel_event。沒有第二份 Python 規則。可用 `--goal ENDING_ID` 指定結局，省略代表任一結局。

| 結果 | 語意 |
| --- | --- |
| witness_found / exit 0 | 找到一條可重播的結局路線；不代表所有玩法皆可通關 |
| inconclusive / exit 1 | 達狀態、深度或時間上限，未完成探索；不能當成不可能通關 |
| exhausted_no_goal / exit 1 | 在工具涵蓋的操作模型內前沿耗盡，未找到目標；仍不等於任意外掛玩法的證明 |

報告列出限制、狀態數、轉移數、展開數、達到的深度、耗時、拒絕原因統計，並固定 `guarantees_all_routes: false`。重播證據以普通指令重建，不注入探索狀態。無限日期／重複事件／行動紀錄可能造成巨大狀態空間，達上限很正常。此工具不探索 UI 時序、存檔 IO 故障、profile、任意腳本或媒體；這些由獨立測試覆蓋。

## 快速、完整測試與 CI

```powershell
python tools/dev.py check --game numeric_lab --suite fast --json
python tools/dev.py check --game numeric_lab --suite full --timeout 600 --json
```

`static`、`rules`、`ui`、`media` 為互斥層，`fast` 是 static＋rules，`full` 是全部。選層是明確縮小範圍，不假装完成全部驗收；報告 data.suite 指明範圍。工具依賴不存在或子程序失敗會報錯，沒有 silent skip。UI 層採原生 headless 滑鼠流程，GPU 畫面仍另行實跑。

[GitHub Actions](../.github/workflows/engine.yml) 在乾淨 Windows checkout 以四個獨立 job 執行各層，鎖定 Python／Godot／Python 套件版本；保留 JUnit、Godot／pytest 日誌、情境結果與已產生的截圖。沒有共享並行匯入同一個 checkout。工作流程的遠端成功與否以該 commit 的 Actions 結果為準；本機完整回歸不能冒充遠端 CI 成功。

### 即時診斷紀錄容量

S7 起遊戲中的 `core.history` 保留最近 256 筆，步驟序號持續遞增；新遊戲重設。這不影響存檔中的事件完成、行動與持久計數。離線 `test_runner` 設 `history_limit=0`，仍輸出完整情境追蹤。
