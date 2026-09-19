# 第十九批：S4-08 正式畫廊

日期：2026-09-19。狀態：已驗證／待使用者確認。S4-07 已由使用者回覆「請繼續」確認；S4-06 繼續暫緩。

交付：獨立 gallery_view、紀念卡／CG／影片分類與縮圖、鎖定隱藏、CG 放大、影片暫停／音量／重播／返回、持久化解鎖及全程滑鼠操作；霧港兩個既有紀念項目分別提供 CG 與技術測試片示範。兩份 Schema、素材引用／格式診斷及語系同步更新。

驗證：

- `python tools/dev.py check --json`：152 項全部通過（160.67 秒）。完整日誌與 JUnit 位於本機 `test-results/run-64a19b50c30643dba8748d2fb3c33b4e/`。

- `python -m pytest tests/test_gallery.py -q`：6 項通過，包含 5 種負面資料及原生滑鼠／跨程序重啟驗證。
- 未解鎖項目隱藏縮圖，直接呼叫檢視也不能繞過；分類只顯示符合種類的項目，空分類有提示。
- 自然播完、暫停、音量、返回釋放播放器、重播替換播放器均通過。新遊戲與重啟保留解鎖；瀏覽前後 core.state、active_event 與完整 profile 不變。
- NVIDIA RTX 5070 / OpenGL 實測 `gallery_failures=[]`，截圖確認 CG 比例及影片底部控制列。日誌：`test-results/gallery-final-gpu.log`；截圖：`gallery-cg.png`、`gallery-video.png`，均為本機驗收產物，不提交。

既有根憑證訊息仍存在，GPU 測試無 SCRIPT ERROR。資料、試玩與限制見 [畫廊契約](../gallery.md)。下一項為 S4-09 背包、商店與基本選單。
