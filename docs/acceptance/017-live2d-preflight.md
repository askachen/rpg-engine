# 第十七批：S4-06 準備檢查（部分交付）

日期：2026-09-19。S4-05 已由使用者回覆「請繼續」確認。**S4-06 仍在開發中，不能標為完成或已驗證。**

本批交付 `tools/live2d_audit.py`、12 項準備檢查測試及 [Live2D 驗證計畫](../live2d.md)。離線工具輸出模型資源清單／hash 與缺件診斷，不執行 DLL、不下載 SDK、不改動正式遊戲的 renderer 或劇情格式。

`python -m pytest tests/test_live2d_audit.py -q`：12 項通過。案例包含缺圖／壞圖、錯誤 MOC 標頭、路徑越界、錯誤動作 JSON、重複表情、缺少動作／表情、DLL 標頭、模板版本與 CLI 退出碼。測試的 MOC／PE 均為合成標頭 fixture，沒有可運作模型或 DLL，且明確驗證 runtime_verified 始終為 false。

`python tools/live2d_audit.py`：退出碼 1，正確回報 model_missing、addon_missing、templates_missing；本機紀錄位於 `test-results/live2d-preflight.json`，不提交。

`python tools/dev.py check --json`：成功，141 項回歸測試通過；完整日誌與 JUnit 位於本機 `test-results/run-d65e8ec89a5541ff9f003a48f2aa31e4/`。此結果包含既有玩法與媒體功能，並不增加 Live2D 原生驗證證據。

目前需取得 SDK／模型路徑。原始碼編譯另缺可用 MSVC C++ workload；已有 Visual Studio 安裝不等於具備 C++ 工具。SDK 官方下載要求授權同意及下載者資料，因此已詢問使用者已有檔案的位置。沒有代填資料或下載其他來源的 Core。

尚未驗證：GDCubism 原生載入、真實模型透明疊加、動作／表情、隱藏／重入、Windows EXE。待依賴補齊後續做；不能把這批準備測試當作上述功能的替代證據。
