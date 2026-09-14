# RPG Engine — Story Garden

Godot 4.7.2 / GDScript 的資料驅動敘事框架。規格見 [mvp-spec.md](mvp-spec.md)。

目前是 **可玩開發原型，S1 已確認，正在進行 S2 內容工具鏈**，不是完整 MVP；任務狀態見 [TASKS.md](TASKS.md)。四張地圖已接入室內、戶外與裝飾圖集，主角及兩位女主角使用一致的人物頭像與地圖 avatar；不需要在 Godot 編輯器手動設定場景。

## 執行

需要 Python 3.10+、pytest 與 Godot 4.7.2。Godot 可放在 `.tools/godot/`，或設定 `GODOT_BIN` 指向執行檔。

```powershell
python -m pip install -r requirements-dev.txt
python tools/dev.py check
python tools/dev.py play
```

`check` 先檢查內容，再匯入 Godot 並執行 pytest。缺少 Godot 直接失敗，不略過規則測試。`test-results/junit.xml` 提供機器可讀結果；各情境 result.json 保留狀態與操作紀錄。

```powershell
python tools/dev.py editor
python tools/dev.py ui-smoke
```

`ui-smoke` 使用真正渲染器開啟 UI，保存標題、地圖、設定與選單截圖到 `test-results/`，然後關閉。圖形環境不可用時，不把 headless 結果当成視覺驗收。

開發啟動器把 APPDATA 指向 `.tools/userdata/`，開發存檔不接觸正式遊戲資料。

## 操作與示範路線

- 左鍵點地：自動尋路移動；點 NPC／物件／出口：自動走近並互動；右鍵停止。
- 等待與選單都有畫面按鈕，對話、商店、存讀檔、設定與畫廊皆可純滑鼠操作。
- 方向鍵／WASD、E／Enter 仍可作為選用快捷鍵。
- T：推進一個時段；Esc：選單；F3：檢視狀態（debug build）。
- 住處取得零用錢，出門找凜完成初見，啟動庭園燈，再與凜談話。
- 到雜貨店找晴初次對話，在櫃台買咖啡及邀請函。
- 等待晚上，找晴送咖啡，再次互動完成邀約。
- 返回街道，等待深夜，找凜完成約定。
- 兩人各有三個事件；順序可交錯。取消選項不完成事件，之後可再來。

## 程式分工

| 路徑 | 責任 |
| --- | --- |
| `engine/core.gd` | 唯一正式規則：移動、碰撞、時間、條件、購買、事件效果及存讀檔 |
| `engine/save_slots.gd` | 槽位路徑、資料摘要、最新有效存檔；相容舊版 slot1 |
| `engine/main.gd` | 遊戲 UI、圖集地圖、資料化角色路線進度與基本選單 |
| `engine/test_runner.gd` | JSON 測試橋接，呼叫 core.act；不提供狀態注入 |
| `games/demo/game.json` | Manifest、初始狀態及素材配置；地圖／事件／角色／翻譯由 sources 載入 |
| `tools/validate.py` | 內容引用、素材、翻譯、座標及必要事件循環檢查 |
| `tests/test_game.py` | 真正 Godot 規則的通關與失敗情境 |

所有內容 ID 保持穩定；完成事件清單與角色階段會持久化。條件由 `checks()` 統一產生玩家顯示與測試診斷。

demo 已拆成多檔；舊單檔內容仍可載入，正式 Draft 2020-12 Schema 已加入，先檢查結構再檢查引用與玩法資料。這不是所有狀態可達性的證明。

## 已完成與限制

- 已有：三張 24×14 格示範地圖與一張 30×17 格三房兩廳住處、格子碰撞、出入口、一次性拾取／啟動、鎖定出口、商店、三時段、兩人六事件、AND 條件、取消選項、狀態檢視、6 個手動存檔槽（選槽／覆寫確認）、獨立事件後自動存檔、最新有效進度繼續。
- 基本 UI：標題、選單、中英切換、主音量、全螢幕、跨存檔紀念卡解鎖。紀念卡是 UI 示範，**不是正式 CG／影片畫廊**。
- 尚待：安全備份與存檔刪除、完整存檔 Schema、影片與正式動畫演出、Live2D、完整設定、面向互動、轉場、第二內容包、Windows 匯出產物與解析度矩陣驗收。
- 自動測試驗證指定通關路線與邊界，不保證任意選擇排列均不卡關；不包含素材解碼或正式 Steam 發行驗證。

滑鼠回歸測試透過 Godot Viewport 發送實際 InputEventMouseButton，從標題點擊開始，走完兩位角色劇情、購買、等待、存讀檔與畫廊；不以直接呼叫 core.act 代替滑鼠輸入。

## 1080p 與多槽更新

預設視窗／設計解析度為 1920×1080；四張地圖由 12×8 擴為 24×14（3.5 倍格數），調整房間、路面與目標位置。

選單的「儲存遊戲／讀取遊戲」會先開啟槽位畫面。每槽顯示地點、遊戲日數／時段與 UTC 存檔時間；空白或無效槽不能讀取。事件完成僅寫入獨立自動槽，不會覆蓋手動槽。手動覆寫要先確認。標題新增讀檔入口；繼續會跳過損壞檔案，讀取最新有效存檔。舊版單槽檔案仍是槽 1。

## 跑步與室內素材

預設開啟跑步，右上角「跑步：開／關」可全程用滑鼠切換，或按住 Shift 暫時跑步。移動步距仍逐格經過相同碰撞規則；步行每格 0.11 秒，跑步每格 0.045 秒（約 2.4 倍速度）。偏好會保存。

住處為三間臥室、中央走道、客廳、餐廳、廚房與浴室。地板、牆壁及 12 類家具使用 `games/demo/assets/home-interior-atlas-v1.png`。原圖由內建 image_gen 生成；完整提示詞及格位對照記錄於 assets 目錄。家具維持原始長寬比，獨立配置占地碰撞，不能將所有圖片硬拉伸到格數。

舊內容版本的存檔載入後會回到目前地圖入口，保留金錢、物品與劇情，避免卡在新家具中。

## 整體視覺更新 v2

- 三房兩廳加入織紋地毯、窗簾、壁畫、茶几、書櫃與植栽；三間臥室使用不同地毯配色。
- 街道、商店、庭園加入石板路、草地、店面、商品架、收銀檯、長椅、花箱與噴泉。
- 男主角、晴、凜有對應的頭像與地圖 avatar；角色進度改為頭像卡片，對話顯示角色肖像，標題更新人物構圖。
- 素材清单、完整 image_gen 提示詞與原始 PNG 位於 `games/demo/assets/README.md`。
- `engine/art_library.gd` 統一處理圖集裁切範圍、透明邊界、等比例繪製與地面紋理比例。
- 美術新增仍受正常碰撞、滑鼠通關與存讀檔測試保護；四方向行走動畫、表情變體與 Live2D 尚未實作。


## 劇情演出更新

已加入獨立的多段對話播放器：打字效果、立繪淡入、對話紀錄、自動播放、已讀快轉、滑鼠文字框前進及隱藏／恢復。晴的咖啡事件提供選擇前後的短篇演出、示範背景音樂及提示音；收尾結束才提交道具／獎勵並自動存檔。

劇本可指定背景、表情圖片與音訊。新背景生成遇到圖片工具額度限制，因此目前沿用地圖及既有肖像，尚未新增專用 CG 或表情。示範音訊為程式合成的原創簡單音色，並非正式配樂。

格式、操作與驗證範圍見 [劇情演出說明](docs/dialogue.md)。執行 `python tools/dev.py check` 驗證。


## 分階段交付追蹤

[任務清單](TASKS.md) 是目前交付工作與確認狀態的依據。規劃文件不代表功能已完成。

預設內容入口配置在 `project.godot` 的 `story_engine/content_path`，共用執行程式不再固定讀取 demo。直接啟動 Godot 時可在 `--` 後傳入 `--game=內容檔案路徑` 覆寫入口（路徑含空白時將整個參數加引號）。`tools/dev.py play --game <名稱或 JSON 路徑>` 已包裝入口選擇；完整機器可讀診斷與建置仍列入 S2-05。

遊戲 ID 必須是 1–64 個英文字母、數字、底線或連字號，首字為英文字母或數字。不同遊戲使用不同 ID；profile、已讀／解鎖與存檔依 ID 命名。既有 demo 檔名保持相容。路線與結局已另於 S1-02 資料化；主題與主角已支援資料配置，格式見 docs/presentation.md。


## 路線與結局配置

角色路線使用明確事件清單，結局使用條件，紀念卡使用獨立解鎖條件；不再依角色 ID 拼接事件名稱或固定三階段／六事件。HUD 的進度是已完成路線事件數，與劇情條件中的 `stage` 數值分開。角色多於畫面容量時可捲動查看。

詳見 [路線契約](docs/routes.md) 與 [規格／任務對照](docs/spec-status.md)。三角色 1／2／4 事件案例屬測試 fixture，並非已交付第二款遊戲；此測試不等於 S3 第二款遊戲交付。


## 主題與模組更新

主角 ID、肖像／地圖角色資源、標題圖層、UI 配色、字型、牆壁及物件圖示均可在內容配置。avatars 支援明確圖集引用或獨立圖片；語言按內容提供的語系切換。設定、已讀與解鎖由獨立 profile_store 處理。

- [配置範例](docs/presentation.md)
- [模組與操作 API](docs/architecture.md)
- [第三批驗收](docs/acceptance/003-presentation.md)

主題、地圖 renderer、profile 存取已由 main 拆出；既有滑鼠通關繼續回歸。主題 fixture 是整合測試，非第二款正式示範內容包。


## 選擇遊戲與拆檔

```powershell
python tools/dev.py list
python tools/dev.py play --game demo
python tools/dev.py play --game theme_preview
python tools/dev.py validate --game demo
python tools/dev.py check --game demo
```

`theme_preview` 是紫色 Amber Letters 配置預覽，使用現有素材與測試內容，不算 S3 的第二款正式遊戲。`play` 啟動前會驗證資料並匯入素材；`validate` 不需要 Godot。`check --game` 驗證並載入指定內容後執行共用引擎／demo 回歸，**不是任意內容包的通關證明**。`ui-smoke` 仍只支援 demo。

新增事件請編輯 `games/demo/events/` 並登記於 Manifest.sources.events；翻譯位於 `games/demo/locales/`。詳見 [內容包格式](docs/content-pack.md)。


## 結構驗證與來源診斷

開發依賴新增 `jsonschema==4.23.0`，新環境請重新執行 `python -m pip install -r requirements-dev.txt`。本機工作區另支援 `.tools/python_libs` 作為套件安裝位置。

`schemas/manifest.schema.json` 驗證 Manifest，`schemas/game.schema.json` 驗證合併後內容。未知欄位、錯誤型別及必要欄位缺漏先被拒絕，避免語意驗證器發生 KeyError。拆檔結構錯誤會附原始檔案與 JSON 路徑，範例：`events/a2.json#/a2/time_cost`。詳見 [Schema 契約](docs/schema.md)。


## 素材與翻譯品質檢查

新增 Pillow 開發依賴，請使用 requirements-dev.txt 安裝。`validate` 會讀取 PNG／JPEG／WebP、檢查 PCM WAV 完整性、圖集格位與裁切邊界，並比較所有語系的鍵與格式參數。`check` 與 `play` 在 Godot 匯入後還會檢查原生圖片、音訊及字型資源。

`test-results/asset-probe.json` 記錄 Godot 資源檢查結果。音訊檢查不等於完整聆聽／逐幀解碼，字型可載入不等於涵蓋所有字形；影片與 Live2D 仍待 S4。細節見 [素材與語系契約](docs/assets-locales.md)。


## 建立新遊戲

```powershell
python tools/dev.py new --game my_story
python tools/dev.py test --game my_story
python tools/dev.py play --game my_story
```

`new` 產生獨立內容包、素材副本、雙語短流程、README 與正常操作通關路線；存在同名目錄時拒絕覆寫。已建立的 `first_story` 可直接試玩：`python tools/dev.py play --game first_story`。

`test` 讀取內容包自己的 `tests/walkthrough.json`，要求所有操作成功且最終狀態符合 expect；未提供路線的內容包會明確失敗。這與跑共用回歸的 `check` 不同。詳見 [新遊戲範本說明](docs/new-game.md)。
