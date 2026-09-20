# 第二十二批：S5-01 通用能力值與數值變數

日期：2026-09-20。狀態：已驗證／待使用者確認。僅完成 S5-01；S5-02～12 仍待開發，S4-06 Live2D 仍暫緩。

交付：stats／variables 宣告與多檔來源、整數／有限小數、預設與 initial 覆寫、add／set、eq/ne/lt/lte/gt/gte、超界拒絕且整組效果回滾；玩家面板、翻譯、條件文字與開發狀態；新欄位基本存檔驗證及缺欄位回填。見 [正式契約](../numeric-state.md)。

獨立 numeric_lab 透過普通拾取、移動、NPC 訓練兩次及測驗，驗證數值門檻、取消、耗時、扣款、加減／設定與存讀檔。它是通用能力範例，不是 Homestay 真實內容匯入。

驗證：

- `python tools/dev.py check --game numeric_lab --json`：179 項全數通過（pytest 193.67 秒）；完整日誌、通關結果與 JUnit 位於本機 `test-results/run-83b2b4113261456e88bfc35a4372651f/`，整體 201.11 秒。
- 新增數值測試涵蓋非法預設／界線／初值／引用／operator／布林／小數／非有限值、來源檔案路徑、六種比較、交易回滾、取消、重複提交、損壞存檔、缺 ID 回填與舊遊戲相容。
- 原生滑鼠從新局訓練到結局，查看可見數值、隱藏變數、存讀槽位、開發狀態及英文名稱；RTX 5070／OpenGL `numeric_mouse_failures=[]`，人工檢視本機 `test-results/numeric-status.png`。既有 root certificate store 訊息仍存在，無 SCRIPT ERROR。

限制：浮點 eq 為精確比較；只新增全域數值，不提供角色專屬 stats。隱藏欄位不是保密機制；完整版本遷移／復原留待 S6，非線性提示留待 S5-06。下一項為 S5-02 日期比較。
