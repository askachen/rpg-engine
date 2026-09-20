# RPG Engine — Story Garden

給 AI Agentic Coding 使用的 **Godot 4.7.2 / GDScript 無戰鬥敘事 RPG 框架**。內容由 JSON 與素材檔案定義；建立地圖、對話、條件、角色路線與商店不需要操作 Godot 編輯器。

**目前適合技術評估與原型開發，尚未達到正式對外交付／Steam 發行品質。** S2 工具鏈已確認；S3 已確認；S4-01～05 已確認；S4-06 Live2D 依使用者指示暫緩；S4-07～08 已確認；S4-09 已確認；新增 48 個 Cozy Home 地圖素材與展示包，待本批確認；完整狀態以 [TASKS.md](TASKS.md) 為準。規劃中的功能不代表已實作。

## 其他 AI：先用這個流程評估

**Homestay 需求排程更新**：新增 [S5 內容能力計畫](docs/s5-content-capabilities.md)，先補 P0 通用數值、日期比較、地點／互動上下文與開場／物件完整事件，再補 P1 條件樹、計數、提示、庫存、回想及 Extra Day。這些是**待開發能力**，目前不可直接依此匯入正式內容。原 S5／S6／S7 順延為 S6（存檔與測試）／S7（Windows）／S8（團隊交付）；詳細任務及門檻見 [TASKS.md](TASKS.md)。

請從 repo 根目錄執行。不要先修改 `engine/`；先用新內容包验证可重用性。

環境：Windows、Python 3.10+、Godot 4.7.2 標準版（非 .NET 版即可）。將 Godot 解壓到 `.tools/godot/`，或設定 `GODOT_BIN` 為 Godot console 執行檔的完整路徑。此 repo 不附 Python、Godot 或匯出範本。

```powershell
git clone https://github.com/askachen/rpg-engine.git
cd rpg-engine
python -m pip install -r requirements-dev.txt
# 如果 Godot 不在 .tools/godot/，請改成你的實際路徑：
$env:GODOT_BIN = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
python tools/dev.py list --json
python tools/dev.py validate --game first_story --json
python tools/dev.py test --game first_story --json
python tools/dev.py play --game first_story
```

請選擇尚不存在的遊戲 ID，例如 `ai_review`：

```powershell
python tools/dev.py new --game ai_review --json
python tools/dev.py validate --game ai_review --json
python tools/dev.py test --game ai_review --json
python tools/dev.py build --game ai_review --json
python tools/dev.py check --game ai_review --timeout 240 --json
```

下一步：閱讀 `games/ai_review/README.md`，修改 `events/` 的對話並同步兩份 `locales/`；再新增一個事件、登記 Manifest.sources.events 與 routes，更新 `tests/walkthrough.json`，重跑 validate 與 test。預期不需修改共用引擎。遇到缺少的能力請提出缺口，勿以直接注入金錢、完成旗標或略過失敗步驟讓測試通過。

建議回報：執行環境、實際執行指令與退出碼、成功建立／修改的內容、JSON 診斷、必須修改 engine 的原因，以及是否足以開發你的目標遊戲。完整機器協定見 [CLI 契約](docs/cli.md)。

## 指令與自動測試

| 指令 | 實際作用 |
| --- | --- |
| `list` | 列出 games/ 下的入口 |
| `new --game ID` | 建立独立素材、雙語內容及通關路線；拒絕覆寫 |
| `validate --game ID` | Schema、引用、地圖資料、素材完整性及翻譯檢查；不需要 Godot |
| `test --game ID` | 真正 Godot 規則執行該遊戲的 tests/walkthrough.json |
| `test --game ID --scenario PATH` | 執行指定測試路線；PATH 相對 repo 根目錄或絕對路徑 |
| `check --game ID` | 指定內容驗證／載入，加上共用引擎與 demo pytest 回歸 |
| `play --game ID` | 驗證、匯入、原生素材檢查後開啟遊戲 |
| `build --game ID` | 產生只包含選定遊戲及共用引擎的 Godot 原始專案 ZIP |
| `editor --game ID` | 開啟編輯器；內容製作不依賴此操作 |
| `ui-smoke` | demo 專用實際渲染器截圖測試 |

所有命令可加 `--json`，stdout 只輸出一份 JSON。退出碼：`0` 成功、`1` 資料／測試／程序失敗、`2` 用法或入口不存在、`3` 依賴／IO／逾時。`--timeout 240` 是每個非互動子程序的預設期限；play/editor 等待視窗關閉後才輸出結果。

每次執行使用獨立 `test-results/run-*/`，JSON 的 artifacts 指向日誌、原生素材報告、通關完整狀態／歷史及 check 的 JUnit。測試存檔與手動試玩的 `.tools/userdata/` 隔離。請從 artifacts 讀路徑，不要寫死舊版報告檔名。並行執行同一 checkout 的 Godot 匯入仍可能競爭 `.godot/`；CI 請使用獨立 checkout 或序列執行。

`test` 驗證指定路線的每一步成功、最終 expect 欄位完全相等且沒有未結束事件。它**不證明任意選項排列都能通關**；check 也不取代自製遊戲的通關路線。Schema 拒絕未知測試操作與直接狀態注入。Godot 是唯一正式玩法規則，Python 不另寫一套規則。

`build` 輸出 `builds/<game-id>-<hash>-source.zip`，內含 project.godot、合併內容及素材雜湊清單。解壓後用 Godot 匯入並啟動 project.godot。**這不是 Windows .exe，也不是完整開發 SDK**；不含 Python 工具或 Godot。Windows 發行匯出與 Steam 驗收仍在 S7。來源相同時產物可重現，不覆寫不同內容的既有產物。

## 已有玩法與操作

### 內建地圖素材：Cozy Home

新增 **48 個**可直接配置的素材：4 種牆面、4 種門、4 種窗、4 種燈具，另有 16 個客廳／臥室家具及 16 個廚房／浴室／商店設備。原始透明 PNG、生成 prompt、固定 ID、建議尺寸、圖層與碰撞預設皆附在 repo。

- [離線可搜尋圖鑑](asset_packs/cozy_home/index.html)（下載後用瀏覽器開啟）／[JSON 目錄](asset_packs/cozy_home/catalog.json)／[使用說明](asset_packs/cozy_home/README.md)。
- 展示遊戲：`python tools/dev.py play --game asset_showroom`，可用滑鼠走動、切換三個展間。
- 安裝到已建立的遊戲：`python tools/asset_pack.py install --game YOUR_GAME`。
- 產生配置：`python tools/asset_pack.py place sofa --id lounge_sofa --at 5 6`；將輸出的 value 加入指定地圖 collection，再執行 validate。

素材按建議格數配置，保持長寬比；安裝工具不修改既有地圖，重複安裝不會覆寫自訂素材。牆面是裝飾面板，尚非自動拼接牆系統；門與燈為靜態圖片，互動事件須另設。詳見 [本批驗收](docs/acceptance/021-cozy-home.md)。

- 可行走地圖、碰撞、出口／鎖定出口、拾取、啟動物件、商店、金錢與背包。
- NPC 依時段／AND 條件跨地圖換位、條件式出現、調查及指定物品互動；資料格式與霧港試玩步驟見 [物件契約](docs/world-objects.md)。
- 白天／晚上／深夜；多位角色的單線劇情可同時推進；好感、完成事件、道具等 AND 條件與進度提示。
- 多段對話、事件內多節點分支、可重複支線、優先序診斷，以及結尾一次提交／中途取消；見 [劇情契約](docs/story-contract.md)。
- 打字效果、自動播放、已讀快轉、紀錄、背景／肖像圖片及音訊。
- 劇情圖片分層、風景 CG、表情、位置與大小、逐格循環／停格／隱藏；霧港有正式素材示範，見 [圖片演出契約](docs/story-visuals.md)。
- Theora `.ogv` 影片、循環／跳過／暫停／音量及 MP4 離線轉檔；見 [影片契約](docs/video.md)。
- 音樂／音效／語音分組、視窗解析度／全螢幕、對話字級／打字速度／自動等待與重啟保留；見 [設定契約](docs/settings.md)。
- CG／影片畫廊、縮圖分類、持久化解鎖與播放／返回；見 [畫廊契約](docs/gallery.md)。
- 背包說明／數量／物件使用、商店庫存與不足原因、進度收合、離開確認及製作名單；見 [背包與選單](docs/inventory-menus.md)。
- 開頭選單、中英切換、6 個手動存檔槽、自動存檔、繼續遊戲、紀念卡與開發者狀態畫面。
- 全程可用滑鼠：點地移動，點 NPC／物件走近互動，右鍵停止；畫面按鈕切換跑步、等待與選單。預設 1920×1080。

`demo` 是四張地圖、兩位角色六事件的較完整展示。`first_story` 是一個房間、兩個事件的最小範本。`theme_preview` 是主題測試 fixture。後兩者不是 S3 的獨立第二款正式示範遊戲。

`fog_harbor` 是 S3 的獨立故事《霧港來信》：三張新地圖、兩位角色 4／2 個事件路線，包含不同次序的兩條通關情境，使用既有美術的獨立副本。直接執行 `python tools/dev.py play --game fog_harbor`；攻略與限制見 [內容包說明](games/fog_harbor/README.md)。demo 現在也附帶 tests/walkthrough.json，可使用同一 test 指令通關。

first_story 的滑鼠路線：拾取錢 → 跟 Haru 對話接受 → 到櫃台買茶 → 再跟 Haru 對話接受。demo 的路線與美術歷史見既有驗收紀錄與內容檔案。

## 檔案與延伸閱讀

| 路徑／文件 | 用途 |
| --- | --- |
| [內容包](docs/content-pack.md)、[新遊戲](docs/new-game.md) | Manifest、拆檔與範本工作流程 |
| [Schema](docs/schema.md)、schemas/ | 結構、來源欄位診斷與正式規格 |
| [路線](docs/routes.md)、[劇情](docs/dialogue.md) | 條件、演出與事件格式 |
| [主題](docs/presentation.md)、[素材與語系](docs/assets-locales.md) | 外觀、圖集、翻譯與檢查限制 |
| [架構與 API](docs/architecture.md) | core.act、模組分工及擴充邊界 |
| engine/core.gd | 唯一正式規則與持久化狀態 |
| engine/test_runner.gd | JSON 到正式規則的測試橋接 |
| games/*/game.json | 各遊戲入口，素材引用使用 res:// |
| [規格狀態](docs/spec-status.md)、[Tasks](TASKS.md) | 能力現況與逐階段驗收 |

內容 ID 必須穩定；game ID 使用 1–64 位英文字母／數字／底線／連字號，首字是字母或數字。各遊戲 ID 隔離存檔、設定與解鎖。demo 的舊地圖讀檔遷移只在該包明確配置時啟用。

## 尚缺的交付能力

Live2D（[準備檢查與缺件說明](docs/live2d.md)，尚不支援播放）、存檔 Schema 與備份、更多動作與轉場、Windows 匯出與多解析度矩陣、完整 SDK／授權清單及外部團隊試用仍未完成。素材提示詞與來源記錄位於各 assets/；本 repo 尚未提供正式對外授權文件。

素材檢查已包含 Python 圖片／WAV 檢查與 Godot 原生載入，但另有 Ogg 結構／完整解碼與原生影片流程測試；仍不等於喇叭音訊量測、所有字形或發行環境驗收。本機 Godot 可能輸出憑證存放區警告；請分辨環境警告與 SCRIPT ERROR，不要把失敗測試忽略。

每階段完成後會更新驗收文件並 commit/push。自動測試通過與使用者確認驗收是不同狀態。

S3 隔離回歸會讓 demo 與 fog_harbor 共用同一個臨時使用者目錄，透過滑鼠建立不同設定與進度，交替重啟並驗證存檔、畫廊及已讀資料。誤放的外來存檔會被拒絕，槽位停用且不改目前狀態；見 [隔離驗收](docs/acceptance/010-isolation.md)。

## 地圖視窗更新

大地圖現在會跟隨玩家捲動並裁切於固定世界視窗，HUD 不移動；滑鼠提示顯示互動物件名稱，出入口有淡出／淡入與輸入鎖定。霧港工坊地毯已改為明確地面層，可放在桌子與角色底下。使用 `python tools/dev.py play --game fog_harbor` 試玩；鏡頭、素材層級與測試契約見 [地圖視窗說明](docs/world-view.md)。霧港主角已新增四方向面向與逐格行走動畫；舊角色素材保持相容，配置見 [角色動畫](docs/actor-animation.md)。
