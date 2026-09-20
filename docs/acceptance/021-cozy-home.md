# 第二十一批：Cozy Home 內建地圖素材

日期：2026-09-20。使用者要求先擴充可供遊戲開發團隊使用的素材，因此本批優先交付素材包；S5-01 尚未開發，S4-06 Live2D 仍暫緩。

## 交付

- 3 張原始 RGBA PNG，1254×1254，共 48 個素材：建築 16、客廳／臥室 16、廚衛／商店 16。
- 使用 built-in imagegen 生成；完整 prompt 保存在原圖旁，未修改生成 PNG 像素。以手動隔離範圍內的 alpha 量測設定 atlas region，保留跨過名義格線的素材邊緣。
- `asset_packs/cozy_home/catalog.json`：固定 ID、來源範圍、尺寸、图層及碰撞預設；`index.html` 提供離線搜尋與裁切預覽。
- `tools/asset_pack.py list/install/place`：安裝獨立素材副本與 visuals、輸出既有 map JSON，不引入新 runtime 格式；拒絕視覺 ID／檔案衝突。
- `games/asset_showroom`：三個 30×30 展間，各展示 16 個素材；滑鼠走動、跑步、出口切換，保留範本雙事件故事以驗證一般遊戲流程。

## 驗證範圍

- `python tools/dev.py check --game asset_showroom --json`：161 項測試全數通過（pytest 194.15 秒，整體 202.03 秒）；完整日誌、素材探測、通關結果與 JUnit：本機 `test-results/run-bf49fef1823b499f91fbc0be8ea4afef/`。

- 目錄 48 個 ID 各在展示地圖出現一次；RGBA、非空 region、邊界及配置驗證。
- 獨立新遊戲安裝後可驗證；再次安裝不變動；修改的圖片或 visual ID 不被覆寫；拒絕非法目標路徑。
- 一般 Godot 通關路線完成撿錢、對話、買茶、結局與三展間往返，不注入金錢或完成旗標。
- 原生 OpenGL / RTX 5070 渲染三展間並人工檢查 `test-results/showroom_room.png`、`showroom_architecture.png`、`showroom_utility.png`。渲染 fixture 直接定位鏡頭，不作玩法可達性的證據。
- `python tools/dev.py build --game asset_showroom --json` 通過，產生 Godot 原始專案 ZIP；不是 Windows 執行檔。

## 限制

牆面是正面裝飾板而非自動拼接／轉角牆；門和燈是靜態素材。阻擋、出口、開鎖、燈光效果須由遊戲資料或功能另行設定。家具碰撞採完整格數外框，並非依圖片透明度或家具腳部計算。圖鑑及展示地圖可供核對比例；正式住宅配置仍由各遊戲設計。S7 素材權利／發行清單工作未因此完成。
