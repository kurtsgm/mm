class_name StateImageCatalog
extends RefCounted
# 暈倒/死亡時「取代頭像」的共用圖（不分臉）：倒下身體（分男女）、墓碑。
# 性別以角色名對照（不動存檔）；素材尚未放入時 override_texture 回 null → 卡片退回頭像+shader。

const _DOWN_MALE := "res://content/portraits/states/down_male.png"
const _DOWN_FEMALE := "res://content/portraits/states/down_female.png"
const _TOMBSTONE := "res://content/portraits/states/tombstone.webp"

const _FEMALE_NAMES := { "Cordelia": true, "Sira": true, "Cassia": true }

static func gender_for(c: Character) -> String:
	if c != null and _FEMALE_NAMES.has(c.name):
		return "female"
	return "male"

# 該持久狀態（PortraitState.Face）要顯示的共用圖路徑；非暈倒/死亡回 ""。
static func state_path(c: Character, face: int) -> String:
	if face == PortraitState.Face.UNCONSCIOUS:
		return _DOWN_FEMALE if gender_for(c) == "female" else _DOWN_MALE
	if face == PortraitState.Face.DEAD:
		return _TOMBSTONE
	return ""

# 取代頭像的共用圖 Texture2D；非暈倒/死亡或素材缺 → null。
static func override_texture(c: Character, face: int) -> Texture2D:
	var path := state_path(c, face)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
