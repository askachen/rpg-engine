# 第十四批：S4-03 劇情執行契約

日期：2026-09-17。狀態：已由使用者回覆「請繼續」確認。S4-02 已由使用者回覆「請繼續」確認。

## 交付

- 事件內 nodes／next 分支；core.event_view 提供當前節點，根節點保持舊格式相容。
- 分支效果暫存，結尾一次交易；取消捨棄，失敗還原後可重選或離開，不會卡在無演出的 active_event。
- 獨立支線 repeatable，每輪重新檢查條件，完成 ID 不重複累積；線性 routes 禁止放入重複事件。
- event_candidates 提供完整優先序、同分 ID 排序與條件／路線／已完成等原因；開發者畫面顯示唯讀診斷。
- 通用滑鼠「離開對話」、中斷與重入清理、分支已讀範圍、演出退出後停止音訊及忽略舊回呼。
- Schema／翻譯／媒體驗證延伸到所有節點與選項；拒絕不存在、循環或不可達的節點及含副作用的取消選項。
- 霧港新增工作／天氣分支閒聊與公開 JSON 測試路線，既有主線條件滿足時仍優先。

## 驗證

- `python -m pytest tests/test_story_contract.py tests/test_objects.py -q`：23 項通過，涵蓋本批新增 10 個負面資料案例、原生交易／候選規則與滑鼠生命週期，以及上一批物件行為。
- 公開 CLI：`python tools/dev.py test --game fog_harbor --scenario games/fog_harbor/tests/conversation.json --json` 通過 31 步正常操作。包含取消後重入、兩條分支、重複事件、存讀檔，沒有直接注入單局狀態。
- NVIDIA RTX 5070 / OpenGL 實際滑鼠演練 `story_mouse_failures=[]`；檢視 `test-results/story-branch.png`，選项與離開按鈕正常顯示。本機日誌為 `test-results/story-gpu.log`。
- 修正既有 camera 測試的時序競爭：驗證鎖定輸入時不跨幀等待，避免把正常換圖當成輸入穿透；仍保留淡入期鎖定與轉場後恢復的斷言。
- `python tools/dev.py check --json`：108 項全部通過，包括既有兩款故事、跨遊戲存讀檔、地圖互動與對話播放模式。完整日誌／JUnit 位於 `test-results/run-b3d54f4177d24bd38f274e81efaacd1b/`（本機產物）。

環境仍輸出既有根憑證讀取訊息，離線規則與 GPU 流程成功，未出現 SCRIPT ERROR。

## 限制

分支無環，僅限同事件；條件讀已提交 state，不讀暫存效果。節點間重新建立演出，音訊需在新節點明確配置。沒有內建重複冷卻、次數計數器或演出中存檔。profile 已讀紀錄不隨取消回復。指定測試未證明任意內容均可通關，完整狀態探索仍屬 S5。

完整規則見 [劇情契約](../story-contract.md)。下一批：S4-04 圖片與動畫演出。
