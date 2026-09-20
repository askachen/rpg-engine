# Numeric Lab：S5-01 數值範例

```powershell
python tools/dev.py play --game numeric_lab
python tools/dev.py test --game numeric_lab --json
```

滑鼠撿零用錢，點小晴訓練兩次，再對話完成測驗。每次訓練花 2 元及一時段，INT +1、focus +0.25；INT >= 2 且 focus = 0.5 時可測驗，FIT 設為 1 並扣除 focus 0.5。

地圖下方「能力狀態」可查看智力／體能／魅力／專注。internal_note 為隱藏變數，initial 指定為 9，開發者狀態頁可見。名稱提供繁中與英文。

- numbers/stats.json、numbers/variables.json：宣告型別、上下限及顯示。
- events/welcome.json：重複訓練／取消；events/tea_time.json：數值門檻及加減／設定效果。
- tests/walkthrough.json：普通走路、互動與存讀檔，驗證錢／數值／完成事件／時段，不注入狀態。
- [完整契約](../../docs/numeric-state.md)。使用既有範本素材；此為功能驗證，不是 Homestay 匯入或 S5 全階段驗收。
