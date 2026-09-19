# 正式畫廊（S4-08）

開頭選單與遊戲選單皆可開啟畫廊。分類為全部、紀念卡、CG 圖片、影片；未解鎖項目保留鎖定按鈕，不顯示標題或縮圖。CG 點開後等比例放大檢視；影片可暫停／恢復、調整本次音量、重新播放或返回。返回清單保留分類；返回清單或關閉檢視會釋放播放器。

## 資料格式

舊版 character、title、text、conditions 紀念卡保持相容。加上 media 即成為 CG／影片項目：

```json
{
  "harbor_memory": {
    "character": "mara",
    "title": "harbor_memory_title",
    "text": "harbor_memory_caption",
    "conditions": [{"kind": "completed", "id": "last_dispatch", "value": true}],
    "media": {
      "kind": "image",
      "path": "res://games/my_game/assets/harbor.png",
      "thumbnail": "res://games/my_game/assets/harbor-cover.png"
    }
  }
}
```

kind 為 image 或 video；影片 path 使用 `.ogv`。thumbnail 必須是圖片，可與 CG 相同，也可由作者指定封面，不會自動抽取影片影格。兩個路徑都必須在 assets 登記並通過既有素材檢查；title／text 是語系鍵。character 沿用既有必要欄位。

## 解鎖與狀態

回到遊戲畫面且沒有進行中的事件時，檢查每張卡片的 AND conditions；滿足後將 ID 加入該遊戲 profile。這涵蓋完成事件、拾取／等待等操作及讀檔／新遊戲回到地圖；事件中的暫存分支效果不觸發解鎖。解鎖只增加，不因讀取舊存檔或新遊戲撤銷。既有存檔只需繼續進入地圖，就可補登已滿足的條件。

開頭選單只顯示 profile 已解鎖的內容，不用未開始遊戲的狀態推算條件。空條件項目會在第一次進入地圖時解鎖。

`gallery_view.gd` 僅讀取內容與 profile，不呼叫 core.act、不重播事件、不提交獎勵，也不增加對話已讀。即使直接呼叫 show_card，仍檢查解鎖。影片透過獨立 story_video 播放器呈現，走 Master 音量；本次滑桿不寫入 profile。自然播放完成留在檢視頁，可按重新播放或返回。

## 範例與驗證

《霧港來信》的 signal_memory 顯示港口 CG，完成 light_beacon 解鎖；letter_memory 播放既有投影機技術測試片，完成 last_dispatch 解鎖。影片不是正式劇情動畫，說明文字會標示。其他內容包繼續展示舊紀念卡。

`tests/gallery_flow.gd` 用既有通關路線經正式 core 規則準備解鎖，再以滑鼠檢查鎖定／分類／CG／影片／暫停／音量／自然結束／重播／返回。另一個 Godot 程序重新載入 profile 並開始新遊戲，再次確認畫廊可看且單局狀態與 profile 前後相同。既有跨遊戲隔離測試另驗證不同遊戲的解鎖不串用。

目前圖片採大畫面等比例檢視，不提供自由縮放／拖曳；影片沒有 seek 或循環開關。分類依媒體種類，不提供自訂多層標籤。縮圖為作者指定，沒有另外產生低解析度快取；大量項目的分頁、記憶體與發行效能仍待後續驗收。長標題／字幕需由內容作者確認排版。畫廊不是素材加密或 DRM。
