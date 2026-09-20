# 通用能力值與數值變數（S5-01）

Godot core 是唯一玩法規則；Python 只檢查格式、引用、型別與宣告值。stats 與 variables 是單局全域數值，不借用角色好感度、道具或布林 flags。

## 定義

可在 game.json 定義，或用 sources.stats／sources.variables 引用片段：

```json
{
  "stats": {
    "INT": {"name": "stat_INT", "type": "integer", "min": 0, "max": 100}
  },
  "variables": {
    "focus": {"name": "focus", "type": "number", "min": 0, "max": 1, "visible": true},
    "internal_note": {"name": "internal_note", "type": "integer", "default": 7}
  }
}
```

- ID 為英文字母開頭，後續可有字母、數字、底線，最多 64 字元；每個集合有自己的命名空間。
- name 是所有語系均須提供的翻譯鍵。type 必填：integer 或 number。
- 初值優先順序：initial.stats/variables.ID → default → 0。定義的 default 即使被 initial 覆蓋也必須合法。
- min／max 可省略，邊界包含等號；min 不可大於 max。整數定義的界線、初值與運算輸入須為整數。
- 所有數值須有限且絕對值不超過 9007199254740991；不接受布林、字串、NaN、Infinity。Godot 正規化整數為 int、小數為 float，保持存讀檔型別一致。
- number 使用浮點運算，eq 為精確比較，無 epsilon 容錯；需要精確十進位累計時，以 integer 最小單位建模。
- stats 預設顯示、variables 預設隱藏，可用 visible 覆寫。隱藏只控制玩家狀態面板；開發者頁顯示全部值，條件提示也可能顯示引用的數值。

## 比較及效果

條件可用於事件、選項、NPC 排程、可見性及畫廊等既有 conditions 位置；仍為平面 AND。

```json
[
  {"kind": "stat", "id": "INT", "op": "gte", "value": 2},
  {"kind": "variable", "id": "focus", "op": "eq", "value": 0.5}
]
```

op 必填，可為 eq/ne/lt/lte/gt/gte。未知 ID 或錯誤型別／operator 不合法；執行時未知 ID 即使 ne 也不會通過。門檻可超出 min/max，但須符合型別與安全數值範圍；驗證器不保證門檻可達。

```json
[
  {"kind": "money", "value": -2},
  {"kind": "stat", "id": "INT", "op": "add", "value": 1},
  {"kind": "variable", "id": "focus", "op": "add", "value": 0.25},
  {"kind": "stat", "id": "FIT", "op": "set", "value": 1}
]
```

FIT 須先依 INT 的方式宣告。效果只支援 add／set，負 add 代表減少。每個數值效果執行後須合法，不截斷、不容許先超界再抵銷；失敗回滾整組效果，包括較早的扣錢／道具／數值。失敗事件不完成、不耗時，保留既有重試／取消流程；取消丟棄 pending effects，重複完成回呼不會再給獎勵。

## UI、存檔及測試

有可見數值時，地圖下方與選單提供「能力狀態」，純滑鼠開啟／返回，面板可捲動。numeric_status 翻譯鍵可覆寫標題，缺省時繁中為「能力狀態」，其他語言備援 Attributes；欄位名稱使用作者翻譯。側欄條件顯示名稱、比較符號、門檻及目前值。非線性進度與 ! 留待 S5-06。

存檔包含 state.stats／state.variables；缺集合或新增 ID 時補目前初值，已有非法值／未知 ID／錯誤集合型別則拒絕且現局不變。槽位預覽共用驗證。無數值定義的舊遊戲不強制加入空集合。刪除／改名 ID 或縮小範圍可能令舊存檔失效；本項不是任意版本遷移，完整政策仍在 S6-01／02。

CLI walkthrough 的 expect 可包含 stats／variables，即使 initial 省略集合；以完整集合比對。沒有任意數值注入命令，通關仍透過普通操作。

```powershell
python tools/dev.py play --game numeric_lab
python tools/dev.py test --game numeric_lab --json
python -m pytest tests/test_numeric.py -q
```

範例使用 NPC 訓練事件；日期比較是 S5-02、非 NPC 完整事件是 S5-04，尚未交付。
