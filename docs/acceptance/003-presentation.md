# 第三批驗收：主題／主角配置與模組邊界

日期：2026-09-13。任務：S1-03、S1-04。狀態：已於 2026-09-13 由使用者回覆「了解. 繼續吧」確認。

## 交付

- protagonist、default_language、locale_names 與 presentation 內容設定。主角頭像、地圖角色及選項紀錄使用指定 ID。
- 肖像、角色、標題及物件圖示可使用明確圖集引用或獨立圖片；字型與 UI 配色可配置。標題構圖不再固定出現 demo 三人。
- 地圖材質 repeat／tint、牆壁與拾取／開關圖像由內容提供，移除 town／interior 的繪製特例。
- 新增 presentation_theme、world_renderer、profile_store；main 保留組裝、輸入與流程。模組責任、動態宿主契約、命令及錯誤碼已文件化。
- profile 存取獨立，保留原檔名、忽略無效欄位並以暫存檔替換；完整備份及版本復原未列入本批。

## 驗證

`python tools/dev.py check`：29 項通過，包含原正常滑鼠通關、舊 profile 相容、路線／演出／存讀檔回歸。

新增主題 fixture：移除 player ID 與 characters 圖集，改用 traveler／cast、Amber Letters 標題、紫色面板及 Godot SystemFont 資源；驗證主題與字型確實套用、圖像引用、選項發言者、事件完成及紀念卡可開啟。素材仍重用現有肖像以隔離配置機制，不作為正式角色設定。

新增無效主角／圖集、色碼、字型與圖層尺寸驗證；靜態腳本依賴檢查確認沒有 load／preload 循環，繪製模組不直接呼叫規則 act。此檢查不宣稱涵蓋所有動態依賴。

實際 GPU 渲染檢查：主題標題與地圖截图、原 demo 的標題／地圖／對話／選單。主題呈現無溢出，原玩法及素材配置保持。產物：test-results/theme-title.png、theme-world.png 及 ui-smoke 截圖。Windows 根憑證警告仍存在，無腳本錯誤。

## 範圍與下一階段

S1 所有任務已實作驗證，但本批待使用者確認。引擎仍非對外正式發行品質：內容仍是大型 JSON、介面布局不是任意可編輯、正式媒體畫廊／影片／Live2D、完整存檔可靠性與 Windows 發行驗收仍待後續階段。

下一階段 S2：Manifest 與拆檔載入、正式 Schema、素材／語系驗證、建立新遊戲及統一 CLI。
