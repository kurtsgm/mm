# 哥布林 3D 模型

`goblin.tscn` 是本專案原創、程序建模後預先烘焙的完整立體模型，沒有使用 billboard、外部模型或付費服務。大地圖與戰鬥均透過 `MonsterModelCatalog` 使用此場景。

第一版走可辨識的風格化奇幻造型：橄欖綠皮膚、尖耳、獠牙、黃眼、耳環、皮甲、鉚釘肩甲、砍刀與小盾。採用簡化幾何與 PBR 材質，尚非寫實雕刻及蒙皮骨架資產。

## 查看

在專案根目錄執行：

```sh
./run.sh res://presentation/monsters/goblin_preview.tscn
```

- 拖曳：環繞視角；滾輪：縮放。
- `Space`：揮砍；`H`：受擊；`W`：切換行走；`R`：自動環繞。
- `1` / `2` / `3`：正面 / 側面 / 背面。也可直接點擊畫面按鈕。

正常啟動遊戲時，哥布林遭遇已自動使用 3D 模型，無須開啟設定。

## 製作與動畫

```sh
godot --headless --path . --script tools/build_goblin.gd
godot --headless --path . --import
```

模型朝向為 **+Z**，原點在鞋底，靜止高度為 **2 世界單位**。網格在建置時按關節與材質合併，多隻怪物共用網格及基礎材質；受擊疊色材質為每隻獨立建立。

`presentation/monsters/monster_model.gd` 驅動身體、頭、手臂、前臂與腿部的剛性關節：待機呼吸、行走、揮砍、受擊後恢復。這些動作由 Godot 節點變換實現，並非可匯出的骨骼動畫片段。大地圖層負責移動與轉向；戰鬥層負責事件觸發與存活顯示，動畫不改變根節點腳底位置。

新增其他種類時，在 `MonsterModelCatalog` 註冊場景。尚未製作 3D 模型的種類繼續走現有 sprite 呈現流程。

## 驗證

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

涵蓋網格厚度與完整索引、尺寸與腳底、動畫中斷/恢復、共用網格但獨立紅閃、群體移動/轉向/清理、3D 與 sprite 混合遭遇。另以實際 OpenGL 畫面檢查正面、側面、背面、大地圖、戰鬥揮砍及受擊。
