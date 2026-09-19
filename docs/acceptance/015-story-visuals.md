# 第十五批：S4-04 圖片與逐格動畫演出

日期：2026-09-18。狀態：已由使用者回覆「請繼續」確認（2026-09-18）。S4-03 已由使用者回覆「請繼續」確認。

## 交付

- 獨立 story_visual 模組與 line.visual 資料格式；背景、CG、靜態圖片及逐格圖層，位置／大小依 1920×1080 設計座標配置並等比例顯示。
- loop、一次播放後 hold／hide、對話紀錄／隱藏時暫停、恢復、換句／快轉／取消清理。動畫結束不推進 core，也不提交獎勵。
- 兩份 Schema 與語意驗證：圖層 ID、範圍、圖片／圖集引用、影格與 fps、循環結束規則及新舊格式不可混用。
- 霧港閒聊使用新港口背景／風景 CG 與瑪拉表情圖集，實際展示眨眼、左右位置與尺寸、不同表情及兩種非循環結尾。
- 素材以內建 imagegen 生成、原像素保留；原始 PNG、完整提示詞、圖集取樣配置與來源說明一併納入 repo。

## 驗證

- `python -m pytest tests/test_story_visual.py -q`：11 項通過，含 10 個負面資料案例及原生滑鼠／動畫生命週期驗證。
- 原生測試發現縮小 TextureRect 時受到原圖最小尺寸限制，已修正屬性設定順序；現在能按作者給定尺寸縮小角色。
- `python tools/dev.py test --game fog_harbor --scenario games/fog_harbor/tests/conversation.json --json`：31 步既有分支路線通過，演出不改變玩法規則。
- NVIDIA RTX 5070 / OpenGL：`visual_failures=[]`。檢視 visual-blink／visual-expression／visual-cg 截圖，確認實際背景、表情、位置大小及無角色 CG。日誌與截圖位於本機 `test-results/visual-gpu.log`、`test-results/visual-*.png`，不提交。
- `python tools/dev.py check --json`：119 項全部通過。完整 pytest／JUnit 報告位於本機 `test-results/run-90163fe651f5445b90dfff333d9c4f45/`，涵蓋原有故事、存讀檔隔離、分支、滑鼠與新圖片動畫。

環境仍有既有根憑證讀取訊息；離線播放及 GPU 測試成功，沒有 SCRIPT ERROR。

## 限制與後續

背景原圖為 1672×941，表情圖集為 1254×1254；不是原生 4K 美術。生成的眨眼輪廓仍可能有細微差異，可用正式美術替換。圖片／動畫以句為生命週期，不支援跨句保留或平移縮放補間；目前採用隱藏文字框時暫停動畫的規則。完整解析度矩陣與發行效能仍在 S6。

資料格式與操作見 [圖片演出契約](../story-visuals.md)。下一批：S4-05 影片流程。此功能不代表已支援影片或 Live2D。
