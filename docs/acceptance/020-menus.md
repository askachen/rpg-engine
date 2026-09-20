# 第二十批：S4-09 背包、商店與基本選單

日期：2026-09-20。狀態：已驗證／待使用者確認。S4-08 已由使用者回覆「請繼續」確認。S4-06 仍依使用者指示暫緩。

交付：獨立 inventory_view，背包名稱／說明／數量／對應物件使用；商店金錢／持有量／庫存／價格／不足原因；核心 shop_offer 共用交易檢查；角色進度收合；資料化雙語製作名單；離開按鈕與系統關窗確認。

驗證：

- `python tools/dev.py check --json`：155 項全部通過（175.41 秒）；完整日誌與 JUnit 位於本機 `test-results/run-af2f7f9f3657423a94b96f0312d04cfe/`。

- `python -m pytest tests/test_menus.py -q`：3 項通過，包括說明與名單翻譯診斷、原生滑鼠流程與確認後正常結束程序。
- 滑鼠流程验证鑰匙消耗與櫃子啟動、缺錢拒絕、拾取正常津貼後扣款／庫存更新、售罄拒絕且狀態不變、收合不改角色及取消離開不改單局。
- NVIDIA RTX 5070 / OpenGL：`menus_failures=[]`。檢視 `test-results/inventory.png`、`shop.png`；日誌 `test-results/menus-gpu.log`，為本機產物，不提交。

既有根憑證訊息仍存在；GPU 測試沒有 SCRIPT ERROR。資料格式、操作與範圍见 [背包與選單契約](../inventory-menus.md)。下一項為 S5-01 存檔 Schema 與版本政策。
