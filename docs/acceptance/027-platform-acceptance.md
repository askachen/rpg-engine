# 第二十七批：S7-03／04 平台與效能驗收

日期：2026-09-20。合併開發，沿用 numeric_lab／fog_harbor；S7-01／02 由使用者本次繼續開發確認。本批完成後 S7 全部已實作，S7-03／04 待使用者確認；S8 尚未開始。

## 交付與修正

- `tools/platform_check.py matrix`：96 組 GPU 解析度、雙語、字級、DPI 像素尺寸模型；實際像素輸入、長文捲動、最後選項、多槽存檔與畫廊返回。
- `tools/verify_windows_matrix.py`：兩款真正 EXE 的六種 client pixel 尺寸，Win32 滑鼠推進時段與存檔、正常時間每秒 FPS。
- `tools/platform_check.py stress`：大內容 loader／候選查詢、40 次換圖／對話／影片／存讀檔、Godot 與 Windows 程序記憶體、穩態幀時間。
- 修正長事件標題把選項頁撐出畫面的問題；即時診斷僅保留 256 筆，離線 trace 保留完整；事件標記於狀態更新時計算，繪圖讀取快取。
- pytest 加入代表矩陣與生命週期，headless 明確不列為 GPU 效能通過。

執行指令、測試負載、失敗門檻與限制見 [平台驗收契約](../platform-acceptance.md)。

## 本機結果

硬體：Intel Core i5-9400F 2.90 GHz／6 執行緒、NVIDIA GeForce RTX 5070；Godot 4.7.2 Compatibility／OpenGL 3.3。這是回歸基準，不能推論為所有 PC 的最低規格保證。

| 驗證 | 結果 |
| --- | --- |
| 完整 GPU UI 矩陣 | 96／96 通過，六種尺寸各有雙語最大字級截圖 |
| numeric_lab 正式 EXE | 6／6 通過；每秒 FPS 樣本最低 371 |
| fog_harbor 正式 EXE | 6／6 通過；每秒 FPS 樣本最低 283 |
| 場景啟動／大內容載入 | 511.8／37.2 ms |
| 1,000 額外事件候選查詢 p95 | 38.0 ms |
| 存讀檔 p95／含淡入淡出換圖 p95 | 105.7／370.8 ms |
| GPU 幀時間 p95 | 9.6 ms |
| 40 循環後節點／Resource／孤立節點 | 42／29／0，與暖機後相同 |
| Godot 靜態配置增長 | 5.12 MiB，門檻 32 MiB |
| Windows private bytes 增長／峰值 | 35.43／369.43 MiB，增長門檻 128 MiB |

原生 Windows DPI 為 192（200%），Godot 為 system-aware。96 組的 100／125／150／200% 是像素尺寸模型，不是改變作業系統縮放。**未宣稱跨不同 DPI 螢幕熱切換已驗收**；啟動時採系統 DPI，更換縮放後重啟。GPU p95 使用儀器化遊戲 runner；正式 EXE 的數據是每秒 FPS，兩者分開記錄。

本機原始證據（`test-results` 不提交，重跑可重新產生）：

- `platform-568d9704647e4961ada5693cee5cf208/result.json`：96 組及截圖。該次報告的 DPI 範圍字串仍是舊措辭，本紀錄以上述實際範圍為準；工具已改成精確措辭。
- `platform-af0f6bdc69c448528fcd465fbe2666fe/result.json`：40 循環、時間、程序記憶體原始樣本。
- `windows-matrix-6dd22490fe2c4dc3803fb09ae5fdfa8b/result.json`：numeric_lab。
- `windows-matrix-d205718d32e846429ca1922985dc9c1c/result.json`：fog_harbor。

正式產物：

- `builds/numeric_lab-0.7.1-3bfa9e18714ef127-windows.zip`
- `builds/fog_harbor-0.7.1-c4516054e5d4ae0a-windows.zip`

## 整批回歸與遠端驗證

本批一次完整 `python tools/dev.py check --game numeric_lab --timeout 600 --json` 通過，含 fresh import、資源載入、通關與全引擎 pytest。報告位於 `test-results/run-8e120a3147684cb28a12a73bcc51e8a9/`。遠端 CI 於推送後驗證。

## 邊界

本批完成 S7 的 Windows 平台驗收；不是 Steam 商店審核、Steam SDK 整合或 S8 團隊交付驗收。新增內容仍需執行其通關、資源完整性與排版測試。Live2D、S5-10／11 等已列出的延後項目未在本批實作。
