# 第九批驗收：S3-01／S3-02 獨立故事與共用測試

日期：2026-09-15。狀態：已驗證／待使用者確認。

## 交付

- 新增 games/fog_harbor：《霧港來信》，三張 26×15 格新配置地圖，諾亞、伊莉絲、瑪拉，4／2 個事件的兩條線性路線。
- 故事以修復訊號台與郵務整理為核心，包含拾取、消耗道具、購買、開關、時段及好感／完成事件 AND 條件；全新事件、角色、地圖 ID。
- 兩份正常操作情境：第一晚完成兩條線；先完成郵務再於第二晚完成訊號台。無狀態注入。
- demo 補上公開 tests/walkthrough.json，兩款故事現在皆可用同一 `dev.py test --game` 與 test_runner.gd 通關。
- 使用現有圖集的獨立副本、原始提示詞與來源說明；遊戲內容不依賴 games/demo 路徑。美術不是本批新繪製。
- 共用 engine/ 沒有修改；測試側新增 Viewport 滑鼠腳本及 pytest 回歸。

## 驗證

- `python tools/dev.py check --game fog_harbor --timeout 240 --json`：**75 passed in 100.02s**。

- fog_harbor 標準路線：167 步，餘額 25，iris stage 4／好感 40，mara stage 2／好感 20，道具均依劇情消耗。
- courier_first 路線與 demo 公開路線均通過同一 CLI；S3 專項 4 個測試通過。
- 真正 NVIDIA OpenGL 渲染器下，滑鼠走完三張地圖、買修理包、推進時間、完成兩位角色、取得紀念卡與自動存檔，`harbor_mouse_failures=[]`。
- 實際截圖輸出 test-results/harbor-title.png、harbor-quay.png、harbor-workshop.png、harbor-signal.png、harbor-ending.png；檢查地圖、角色進度與結局文字。

## 限制與下一批

S3-03 跨遊戲交替啟動、設定、存讀檔、畫廊、已讀資料隔離仍待專項驗證；本批不能將它勾選完成。兩條通關情境不代表所有任意操作均不會卡關。

畫面檢查發現大型地毯與互動物件重疊時，既有深度排序可能遮住標籤。本包將地毯移到不覆蓋互動區的位置；S4-01 需改善地面裝飾與互動物件的繪製層級。現有通用拾取／開關圖示仍是佔位美術，正式美術另行製作。

Godot 本機憑證存放區警告仍存在；無 SCRIPT ERROR，不將環境警告描述為畫面或劇情失敗。
