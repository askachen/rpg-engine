# 第十八批：S4-07 音訊與完整設定

日期：2026-09-19。狀態：已由使用者回覆「請繼續」確認（2026-09-19）。S4-06 依使用者明確指示暫緩，不標記為完成。

交付：Music／SFX／Voice 分組與 Master 音量；獨立 voice 句型；視窗解析度／全螢幕、對話文字大小與預覽、打字速度、自動等待；舊 profile 預設補齊、錯誤值正規化與重新啟動恢復。見 [設定契約](../settings.md)。

驗證：

- `python tools/dev.py check --json`：146 項全部通過（151.83 秒）。完整報告與 JUnit：本機 `test-results/run-ae39a5f180284bb88951cdc5c3f294be/`。

- 設定專項 5 項測試通過：語音資料缺檔／型別／格式／影片混用，以及原生設定與跨程序重啟。後者包含滑鼠操作所有滑桿、全螢幕／解析度、音訊 bus／靜音、文字速度與字級、語音暫停／恢復／結束／清理及自動等待。
- `python -m pytest tests/test_isolation.py tests/test_settings.py -q`：6 項通過。首次完整回歸發現旧滑鼠輔助程式不會將設定頁底部「返回」捲入視窗，導致後续點擊失敗；已更新共用輔助程式並重測跨遊戲隔離。
- NVIDIA RTX 5070 / OpenGL 原生 GPU 測試 `settings_failures=[]`；實際 DisplayServer 全螢幕／視窗模式檢查通過。檢視 `test-results/settings-top.png`、`settings-bottom.png`。日誌 `test-results/settings-final-gpu.log`。這些本機產物不提交。

既有根憑證存放區訊息仍存在，GPU 最終測試沒有 SCRIPT ERROR。語音測試使用既有合成音訊作 fixture，未量測喇叭輸出。字級只作用於對話正文，不等於全 UI 大字模式；完整解析度／DPI 矩陣、長文排版與發行匯出仍待 S6／內容驗收。

試玩：`python tools/dev.py play`，在開頭選單或遊戲選單選「設定」，滑鼠捲動可看到全部項目；調整、關閉遊戲、重新啟動確認保留。下一項為 S4-08 正式畫廊。
