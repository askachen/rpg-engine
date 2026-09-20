# 建立最小可玩遊戲

```powershell
python tools/dev.py new --game my_story
python tools/dev.py validate --game my_story
python tools/dev.py test --game my_story
python tools/dev.py play --game my_story
```

從引擎根目錄執行。ID 使用 1–64 個英文字母、數字、底線或連字號，首字為英文字母或數字。目錄若存在就拒絕建立，不支援覆寫或刪除既有專案；失敗稿保留供檢查，不自動遞迴清除。

## 產物

- game.json Manifest 與拆分的 maps／characters／events／items／shops／routes／endings／gallery／locales。
- 1 個房間、男主角、1 位 NPC、2 個事件、零用錢拾取、熱茶購買與送禮。
- 個別遊戲 ID 對應自己的 profile、已讀與存檔。
- assets 中有原始 PNG 及提示詞副本，不引用 games/demo 資產路徑；仍需要共用 engine。
- tests/walkthrough.json 與啟動／編輯 README。

產生器目前從隨引擎提供的 demo 取用共通翻譯、主題及原始美術，建立全新的短流程；不要刪掉這些範本來源再執行 new。建立完成後的新內容包不需 demo 資料即可載入。正式範本封裝與授權清單仍需在 S8 整理。

## 試玩

左鍵撿零用錢 → 點小晴並接受初次事件 → 點櫃台買熱茶 → 再找小晴並接受送茶。初次事件推進到晚上，故事結束時持有金額 10、熱茶 0；事件完成會自動存檔。可使用右上角等待按鈕回到需要時段，取消選項不會完成事件。

已生成 `first_story` 可直接使用 `python tools/dev.py play --game first_story`。它是功能範本，不是完成美術與長篇內容的正式遊戲，也不取代 S3 的第二款獨立故事验收。

## 自動通關

`test` 讀取該包 tests/walkthrough.json 的非空 steps 與 expect。steps 是 core 支援的正常操作，橋接不注入金錢、道具或完成旗標；expect 是最終 state 欄位與預期值，例如：

```json
{
  "steps": [{"op": "interact", "target": "coins"}],
  "expect": {"money": 20}
}
```

上例只驗證拾取，完整產生路線則一路走到兩個事件完成。修改地圖／劇情後需同步更新路線。任何一步回報失敗、最終值不符或結束時仍有活動事件都使指令非零退出。沒有路線也不能假裝通過。詳細操作／狀態寫入 JSON 報告 artifacts.walkthrough 所指向的 test-results/run-*/result.json。

通關只證明指定路線。真正滑鼠通關另由 starter_mouse_test 回歸已生成範本，不把 core 操作測試宣稱為滑鼠測試。

## 相容性修正

新增 save_migration.reposition_before_version 可配置的舊地圖遷移門檻。demo 配置為 4，保留既有遷移行為；新遊戲預設沒有此設定，因此版本 1 存檔不會被錯認為 demo 舊版並移回入口。這只是既有遷移規則的隔離，完整版本遷移仍在 S6。
