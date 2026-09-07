# 原創探索配樂

## 城鎮配樂：橡鎮晨光 / Morning in Oaktown

`oak_town_morning.ogg` 是橡鎮的原創程序化器樂曲，由
`tools/compose_oak_town.py` 合成；沒有使用第三方錄音或取樣素材。

- 溫暖木質民謠；G 大調、6/8 拍、附點四分音符 = 72 BPM。
- 木吉他分解和弦、直笛主旋律、手風琴回應與間奏、撥弦低音提琴感低音、沙鈴／木框鼓、少量鐘琴。
- 4 小節吉他引子 → 16 小節主題 → 16 小節副段 → 8 小節手風琴間奏 → 16 小節主題變奏 → 4 小節回接。
- 64 小節，約 106.67 秒；44.1 kHz stereo / Vorbis。
- 尾音與短殘響回捲至曲首，OGG 匯入啟用原生循環。
- 沿用 `oak_town` ID，`town_oak` 地圖自動播放。

使用下方相同 Python 環境，執行：

```sh
/tmp/mm-music-venv/bin/python tools/compose_oak_town.py
godot --headless --path . --editor --import
```

`MELODY_A` / `MELODY_B` 為主副旋律，`VERSE` / `BRIDGE` 為和聲；
`INTRO` / `INTERLUDE` / `OUTRO` 為引子、間奏與回接和聲。
合成工具共用 `compose_oak_wild.py` 的純函式（頻率、包絡、濾波），不會重建野外曲。
樂器為程序化合成音色，並非真人演奏或錄音。

## 野外配樂：橡境行旅 / The Oakmarch Wayfarer

`oak_wild_bard.ogg` 是橡境野外探索用的原創程序化器樂曲，由
`tools/compose_oak_wild.py` 合成；沒有使用第三方錄音或取樣素材。

- D Dorian 調式、6/8 拍、附點四分音符 = 78 BPM，64 小節，約 98.46 秒。
- 魯特琴感雙弦撥奏、木笛主旋律、豎琴點綴、柔和弓弦與低音手鼓。
- 8 小節撥弦引子 → 16 小節主題 → 16 小節明亮副段 → 8 小節器樂間奏 → 16 小節裝飾變奏。
- 尾音與殘響回捲至曲首，OGG 匯入設定開啟原生循環，避免依靠 finished 訊號重播造成間隙。
- 44.1 kHz stereo / Vorbis；播放沿用 `oak_wild`，所有使用此 ID 的野外地圖自動套用。

重新編曲與輸出（需要 Python 3）：

```sh
python3 -m venv /tmp/mm-music-venv
/tmp/mm-music-venv/bin/pip install -r tools/requirements-music.txt
/tmp/mm-music-venv/bin/python tools/compose_oak_wild.py
godot --headless --path . --editor --import
```

修改 `MELODY_A` / `MELODY_B` 可改主旋律；`VERSE` / `BRIDGE` 控制和聲。
合成音色以聲部形象為設計目標，並非真人樂器錄音。
