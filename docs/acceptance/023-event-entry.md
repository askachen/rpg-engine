# 第二十三批：S5-02～04／S5-12A 合併驗收

日期：2026-09-20。狀態：已驗證／待使用者確認。依效率要求合併開發，重用 numeric_lab；没有增加新遊戲或美術副本。

交付：日期六種比較；map／target／具名 zone 條件及互動上下文；候選／觸發／提交重檢；可省略 character 的完整事件、inspect 事件入口與延後耗物；真正新局的 opening_event。既有 NPC 回應仍包含 candidates。契約見 [事件入口](../event-entry.md)。

驗證：

- 本批只跑一次完整回歸：`python tools/dev.py check --game numeric_lab --json`，191 項全部通過；完整命令 198.65 秒，日誌及 JUnit 位於本機 `test-results/run-ca78aa8dd1a24596892aee5d46d0285a/`。
- 完整回歸後，補回既有 candidates 回應欄位並縮短物件標籤，只重跑受影響的 `tests/test_entries.py tests/test_numeric.py tests/test_story_contract.py`：42 項通過。
- 同一條普通操作 walkthrough：開場→拾取→訓練／測驗→跨到 Day 2→工作→空探索→買茶→課程耗物→Day 3→存讀檔。最終 money=9，INT=2／FIT=1／CHA=1，六個完成事件。無測試注入代替通關。
- 獨立負例覆蓋日期前／等於／後、NPC 日期排程、同 NPC 換圖、區域邊界、缺／錯 target、開場取消／讀檔不重播、耗物延後／取消／失敗回滾、提交前離開入口。
- 原生滑鼠及 RTX 5070 OpenGL 演出：`numeric_mouse_failures=[]`；檢視 `test-results/entry-opening.png`。既有 root certificate store 訊息仍在，沒有 SCRIPT ERROR。

12A 僅代表通用 P0 整合案例；真實 Homestay 正式內容未提供，不能代替該團隊的匯入驗收。探索目前為明確點擊入口，無進區域自動觸發；P1／P2 仍待開發。下一批可合併 S5-05～07（條件樹／計數、非線性提示、庫存）。
