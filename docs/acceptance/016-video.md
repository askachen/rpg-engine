# 第十六批：S4-05 影片流程

日期：2026-09-19。狀態：已由使用者回覆「請繼續」確認（2026-09-19）。S4-04 已由使用者回覆「請繼續」確認。

交付：獨立 Theora 播放器、JSON video 句型、保持比例、自然結束／循環、滑鼠暫停／音量／跳過／取消與返回劇情；MP4 轉檔及損壞媒體診斷。霧港閒聊新增投影機分支與有聲測試短片。

驗證結果：

- `python -m pytest tests/test_video.py -q`：10 項通過，包含負面資料、截斷／位元損壞／錯誤標頭、轉檔與拒絕覆寫，以及原生滑鼠測試。
- `python tools/dev.py check --json`：129 項通過（149.13 秒）。本機報告：`test-results/run-4f5a966e4b1e466181d03f02e6d60a86/`。
- 既有霧港 conversation.json 31 步規則回歸通過；影片分支另由 video_mouse 驗證。
- NVIDIA RTX 5070 / OpenGL 實際渲染：`video_failures=[]`，檢視 `test-results/video-loop.png` 確認彩色畫面、4:3 留黑與控制列。日誌 `test-results/video-final-gpu.log`；測試產物不提交。
- 原生流程確認暫停時播放位置不動、循環不推進、取消不提交、跳過後返回文字及最後只提交一次；缺失影片仍可跳過。音量驗證屬性與 bus，未量測喇叭輸出。

既有根憑證訊息及刻意缺檔測試警告仍會出現；沒有 SCRIPT ERROR。完整格式、工具依賴、失敗復原與限制見 [影片契約](../video.md)。發行效能／匯出驗收仍屬 S6；下一批為 S4-06 Live2D 技術驗證。
