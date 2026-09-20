# S7 平台與效能驗收契約

S7-03／04 使用既有 numeric_lab／fog_harbor。沒有新增範例遊戲，也沒有另寫一套玩法規則。所有報告與截图位於 `test-results/`；失败保留原生日誌，回傳非零退出碼。

## 解析度、語系、DPI

```powershell
python tools/platform_check.py matrix
```

原生 Godot GPU 執行，共 **96 組**：

| 維度 | 取值 |
| --- | --- |
| 視窗尺寸基準 | 1280×720、1920×1080、2560×1440、3840×2160、1920×1200、2560×1080 |
| DPI 像素尺寸模型 | 100%、125%、150%、200% |
| 語系 | 繁中、英文 |
| 對話字級 | 22、36 |

視窗設為基準尺寸乘上縮放比例，最高測到 7680×4320 像素；確認實際視窗沒有被夾小。1920×1080 邏輯畫布保持比例，非 16:9 使用留黑邊。滑鼠事件以**實際像素座標**送進 viewport，交由 Godot 自行反轉留黑邊／縮放變換，而非直接呼叫按鈕 callback。

每組驗證：開頭選單、設定捲動／返回、新遊戲、長對話／長事件標題／長選項、大字、最後一個選項、存檔第六槽、覆寫確認、畫廊返回。長文須能捲到末尾，必要控制不得超出邏輯畫面。GPU 執行另保留六種比例的雙語大字截图。每幀布局測試不等於各種內容都已人工排版；新增遊戲仍應檢查自己的翻譯、美術及特殊 UI。

### 真正 Windows EXE 的驗證

```powershell
python tools/verify_windows_matrix.py builds/<game>-<version>-<digest>-windows.zip
```

支援 numeric_lab／fog_harbor，需一般使用者權限的 Windows 互動桌面。驗證包內雜湊後，啟動 EXE，讀取 Windows 回報的 DPI 與感知模式，以原生 Win32 視窗調整六種實際 client pixel 尺寸。每種尺寸都透過滑鼠推進時段、存檔／覆寫，檢查檔案內時段確實變化，以驗證原生輸入座標。

**DPI 邊界明確區分**：96 組矩陣中的 DPI 是物理像素模型，沒有改使用者桌面設定。實機驗收另記錄目前桌面的真正 DPI，本機為 192 DPI（200%）。鎖定的 Godot 4.7.2 採 `PROCESS_SYSTEM_DPI_AWARE`，可參考 [官方 Windows display server 實作](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/display_server_windows.cpp)。本契約支援啟動時的系統 DPI，不宣稱已支援／驗收跨不同 DPI 螢幕的熱切換；更換系統縮放後需重新啟動遊戲。原生感知模式、目前 DPI、像素尺寸與模擬涵蓋範圍都列在 JSON，不能混為一談。

## 效能、資源生命週期

```powershell
python tools/platform_check.py stress --cycles 40
```

使用既有內容的記憶體副本建立合成負載：兩張 200×200 地圖、每張 600 個畫面外家具、額外 1,000 個事件。這是效能 fixture，不是通關或劇情可達性證據。額外事件實際參與 20 次候選查詢，內容也序列化後重新交給原生 loader 載入。

6 次暖機後，執行 40 次真正淡入淡出換圖、對話建立／取消、Theora decoder 建立／播放／釋放、存檔／等待／讀檔。JSON 數值語義一致性允許序列化前後的整數／浮點表示差異。再執行 1,500 次行動確認診斷紀錄有界，另確認離線全紀錄模式保留超過 256 筆。

資源檢查涵蓋暖機後 Godot 節點／Resource／孤立節點數、引擎靜態配置量，以及**真正 Godot 程序**的 Windows private bytes（不是 console 啟動器）。程序記憶體每 100 ms 取樣。這些指標可以抓到本次負載的持續增長，並不等於已證明所有內容永遠不洩漏。

GPU 效能測試以正常時間步長、無錄影、無 Engine.time_scale 加速量測 180 幀；儀器化 runner 使用鎖定 Godot 編輯器執行檔運行遊戲場景。正式 EXE 的 `verify_windows_matrix` 另外使用原生 `--print-fps`，每種尺寸暖機 1.5 秒、取樣 3 秒，至少兩筆每秒 FPS，最低需達 30。**Movie Maker／headless 數字不可當作 GPU 效能驗收**。

| 指標 | 失敗門檻 |
| --- | --- |
| 場景啟動 | > 5,000 ms |
| 大內容 loader | > 2,000 ms |
| 1,000 事件候選查詢 p95 | > 100 ms |
| 存讀檔組合 p95 | > 250 ms |
| 含淡入淡出的換圖 p95 | > 1,000 ms |
| 穩態幀時間 p95 | > 33.4 ms |
| 暖機後 Godot 靜態配置增長 | > 32 MiB |
| Windows private bytes 增長 | > 128 MiB |
| 節點／孤立節點增長 | > 0 |
| Resource 數增長 | > 24（允許延遲載入的有限快取） |
| 正式 EXE 每秒 FPS 樣本 | < 30 |

這是本階段的回歸預算，不是 Steam 最低硬體規格。每次報告記錄 CPU、執行緒數、GPU、OS、Godot 版本與原始樣本；不同硬體的通過與否應各自保留。不可為通過測試而靜默放寬門檻。

## 自動化與改動

```powershell
python -m pytest tests/test_platform.py -q
python tools/platform_check.py matrix --headless
python tools/platform_check.py stress --headless --cycles 10
```

CI／完整回歸使用 8 組代表布局與 10 個生命週期，完整 96 組與 GPU 效能由明確指令執行。headless 報告固定 `performance_verified: false`；它只驗證布局、狀態與資源釋放。工具偵測腳本錯誤會提前終止，不等到長逾時。

引擎修正：遊戲中的 `core.history` 僅保留最後 256 筆，`step` 仍單調遞增；新遊戲重設序號。離線 `test_runner` 設 `history_limit=0`，仍輸出完整情境紀錄。這不刪除持久 action 計數／事件完成記錄。地圖事件標記於 `show_game()` 狀態更新時計算，繪圖只讀取結果；長事件標題加入換行，避免選項頁被撐出畫面。
