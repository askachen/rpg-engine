# Cozy Home 素材展示

48 個內建素材，分成客廳／臥室、建築／燈具、廚衛／商店三個 30×30 展間。
這是比例與素材展示，不是住宅設計；素材按目錄順序排放，便於尋找。

```powershell
python tools/dev.py play --game asset_showroom
python tools/dev.py test --game asset_showroom --json
```

用滑鼠點地板走動、右上角切換跑步，點上方出口標籤換展間。向下走可查看後排素材。
入口保留範本兩事件故事：撿零用錢、與小晴對話、買茶，再對話完成。
自動路線以普通移動、互動與購買完成故事，並往返全部展間；不注入遊戲狀態。

## 在自己的遊戲使用

```powershell
python tools/asset_pack.py install --game YOUR_GAME
python tools/asset_pack.py place bed_double --id bedroom_bed --at 4 5
```

把 place 輸出 value 放進指定 map collection，並執行 validate。
目錄與原始檔在 `asset_packs/cozy_home/`；離線 `index.html` 可按名稱與 ID 搜尋。
本包的素材副本不依賴展示以外的遊戲。共用 engine 仍為執行依賴。
