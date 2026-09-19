# 影片演出契約（S4-05）

影片是對話 sequence 中獨立的一句，由 `engine/story_video.gd` 播放。支援 Ogg Theora `.ogv`，可附 Vorbis 音軌；MP4 必須先轉檔。這符合 [Godot 原生影片支援範圍](https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html)。Live2D 另屬 S4-06。

```json
{
  "id": "projection",
  "speaker": "mara",
  "text": "projection_caption",
  "video": {
    "path": "res://games/my_game/assets/projection.ogv",
    "loop": false,
    "volume": 0.3
  }
}
```

`path` 必須登記在 assets。loop、volume 必須明確指定；volume 範圍 0–1。text 是語系鍵。video 不可與同句 visual、background、portrait、bgm 或 sfx 混用。

## 播放與提交

- 保持影片比例，剩餘區域留黑；字幕與控制列覆蓋在畫面底部。
- 非循環影片自然結束後進入下一句；循環影片持續重播，玩家按「繼續／跳過影片」退出。
- 滑鼠可暫停／恢復、調整本段音量、跳過或取消整段對話。影片經 Master bus，最終音量也受全域設定影響。本段滑桿不寫入設定。
- 自動文字播放與已讀快轉不會自動跳過影片。自然播完才記錄此句已讀；手動跳過不記錄。
- 進入影片停止先前背景音樂與音效；結束後不自動恢復，下一句可明確指定 bgm。
- 播完／跳過僅推進演出；玩法效果仍在最後確認時一次提交。取消清除暫存選項效果並釋放播放器，重入從事件入口開始。
- 不能在演出中存檔；不提供 seek、跨句保留播放器或字幕時間軸。

## 轉檔與檢查

```powershell
python -m pip install -r requirements-dev.txt
python tools/video_tools.py convert input.mp4 games/my_game/assets/projection.ogv
python tools/video_tools.py check games/my_game/assets/projection.ogv
python tools/dev.py validate --game my_game --json
```

開發工具使用 imageio-ffmpeg 0.6.0 的 FFmpeg，或 `FFMPEG_BIN` 指定的執行檔。遊戲執行時不需要 FFmpeg。轉檔使用第一條影像／可選第一條音軌，輸出 Theora/Vorbis、偶數尺寸與正方形像素；目前預期來源為正方形像素，非方形像素來源請先正規化。拒絕覆寫既有輸出；失敗可能留下不完整輸出，修正後請指定新檔名或自行清理。

此獨立工具輸出 `{ "ok": true }` 或含 error 的 JSON，退出碼 0/1（參數用法錯誤為 2），不是 dev.py 的完整協定。轉檔上限 300 秒；全片解碼檢查上限 120 秒。

validate 檢查 Ogg 頁面、CRC、stream 順序／結尾及 Theora/Vorbis 類型，再以 FFmpeg 完整解碼。play/check 另做 Godot 原生資源載入。缺檔、截斷與損壞會阻止正常啟動；執行時載入失敗或三秒未取得影片紋理尺寸，顯示可跳過／取消的訊息。這不是所有解碼器停滯的完整偵測。

## 試玩與測試界線

`python tools/dev.py play --game fog_harbor` → 拾取鑰匙 → 調查舊置物櫃 → 再交談 →「看看投影機測試片」。先播放一次，再循環，退出後返回對話；最後確認才記錄話題旗標。

內附 640×480、1.25 秒彩色測試片與測試音，刻意驗證非 16:9 比例，並非正式劇情影片。`tests/test_video.py` 覆蓋資料錯誤、損壞媒體、MP4 轉檔與原生滑鼠流程；`tests/video_mouse.gd` 覆蓋自然結束、循環、暫停、音量值、比例、跳過、取消及返回提交。測試未量測實際喇叭音訊輸出。

JSON 通關橋接只測玩法規則，不等待影片，不能替代原生媒體測試。長片、最低硬體效能、各解析度與 Windows 匯出後播放仍需 S6 驗收。
