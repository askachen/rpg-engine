# 第六批驗收：素材與語系檢查

日期：2026-09-14。S2-03 已於 2026-09-14 由使用者回覆「繼續吧」確認。

交付 tools/content_quality.py、engine/asset_probe.gd；validate 執行素材／語系靜態與 Python 解碼檢查，play／check 加上 Godot 原生資源檢查。依賴新增 Pillow，記錄於 requirements-dev.txt。

新增圖集裁切越界／不存在格位、媒體欄位類型錯誤、翻譯鍵缺漏／額外鍵、格式參數不一致、損壞 PNG、截斷 PCM WAV 的反例，以及合法格式寬度／具名參數換序、default_language 備援與原生 probe 的正反例。

`python tools/dev.py check`：55 項測試通過，保留原正常滑鼠通關、演出、存讀檔、Schema 與內容包測試。這批沒有修改畫面布局或重新生成素材。

檢查範圍：圖片實際讀取、PCM WAV 完整性、原生音訊資源／時長、字型資源型別、圖集区域與翻譯 token。完整媒體播放／影片／Live2D／字形覆蓋不在本批完成項目。細節見 docs/assets-locales.md。

下一批 S2-04：建立新遊戲指令，產生最小可玩內容、測試路線與說明；S2-05 的完整機器可讀 CLI 仍待後續整合。
