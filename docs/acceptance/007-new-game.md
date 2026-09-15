# 第七批驗收：新遊戲產生器

日期：2026-09-14。S2-04 已由使用者要求繼續開發 S2-05 確認。以下為當批歷史紀錄；S2-05 最新結果見 008-cli.md。

交付 tools/new_game.py、new／test CLI 入口，以及實際生成的 games/first_story。新包包含獨立素材副本、雙語兩事件短流程、Manifest、正常操作通關路線及說明。

驗證：`python tools/dev.py test --game first_story` 回報 0 個錯誤；`python tools/dev.py check` 共 58 項通過。新增產生器輸出驗證、拒絕覆寫／不合法 ID、正常路線及版本 1 存讀檔位置回歸。修正 demo 舊版地圖遷移條件，改由 demo 自己配置，避免影響新遊戲。

實際 renderer 下 starter_mouse_test 透過 Viewport 滑鼠事件完成新遊戲、拾取、初次對話、購買、送茶與自動存檔，無失敗。畫面已檢查，產物 test-results/starter-complete.png。仍有既有 Windows 根憑證警告，無腳本錯誤。

限制：範本不是第二款正式示範遊戲，不是完成影音／美術的商用品質。建立工具仍使用隨引擎提供的 demo 作為素材及共通文字來源；已建立包則沒有 demo 資產路徑相依。CLI 的 JSON 診斷、完整協定與 build 仍待 S2-05。

下一批完成 S2-05 的 CLI 契約與報告，再進入第二款遊戲的重用驗證。
