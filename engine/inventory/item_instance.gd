class_name ItemInstance
extends RefCounted

# 一件裝備實例：base_id + quality + ilvl + 已 roll 定的 affixes（或 unique_id）。
# base 解析走注入的 static resolver（避免 engine 直接依賴 presentation ItemCatalog）。
static var base_resolver: Callable = Callable()

var base_id: String = ""
var quality: int = Quality.Q.COMMON
var ilvl: int = 1
var affixes: Array = []      # [{id, kind, mods:{ItemStat.S:int}, on_hit?, resist?}, ...]
var unique_id: String = ""

func base_def() -> ItemDef:
	if base_resolver.is_valid():
		return base_resolver.call(base_id)
	return null

func _unique() -> Dictionary:
	return UniqueCatalog.entry(unique_id) if unique_id != "" else {}

func display_name() -> String:
	var u := _unique()
	if not u.is_empty():
		return String(u["name"])
	var def := base_def()
	var base_name: String = def.display_name if def != null else base_id
	var pre := ""
	var suf := ""
	for a in affixes:
		if int(a["kind"]) == AffixCatalog.PREFIX and pre == "":
			pre = AffixCatalog.name_of(String(a["id"]))
		elif int(a["kind"]) == AffixCatalog.SUFFIX and suf == "":
			suf = AffixCatalog.name_of(String(a["id"]))
	return pre + base_name + suf

func total_attack() -> int:
	var def := base_def()
	var base_atk: int = def.attack if def != null else 0
	return base_atk + total_stat(ItemStat.S.ATTACK)

func total_armor() -> int:
	var def := base_def()
	var base_arm: int = def.armor if def != null else 0
	return base_arm + total_stat(ItemStat.S.ARMOR)

# 只加詞綴/unique 的 stat（不含 base attack/armor；後者已在 total_attack/armor 併入）
func total_stat(stat: int) -> int:
	var total := 0
	var u := _unique()
	if not u.is_empty():
		total += int((u["mods"] as Dictionary).get(stat, 0))
	for a in affixes:
		var mods: Dictionary = a.get("mods", {})
		total += int(mods.get(stat, 0))
	return total

func weapon_on_hit() -> Dictionary:
	var u := _unique()
	if not u.is_empty():
		return u.get("on_hit", {})
	for a in affixes:
		var oh: Dictionary = a.get("on_hit", {})
		if not oh.is_empty():
			return oh
	return {}

func resist_bonus() -> Dictionary:
	var out: Dictionary = {}
	var u := _unique()
	if not u.is_empty():
		_merge_resist(out, u.get("resist", {}))
	for a in affixes:
		_merge_resist(out, a.get("resist", {}))
	return out

func _merge_resist(acc: Dictionary, src: Dictionary) -> void:
	for elem in src:
		acc[elem] = int(acc.get(elem, 0)) + int(src[elem])

func sell_value() -> int:
	var def := base_def()
	var base_val: int = def.value if def != null else 0
	return int(round(base_val * Quality.value_mult(quality)))

func to_dict() -> Dictionary:
	# affix mods 的 int key 於 JSON 會變字串；存/讀都在 from_dict 統一還原
	var ax: Array = []
	for a in affixes:
		var mods_out: Dictionary = {}
		for stat in a.get("mods", {}):
			mods_out[str(stat)] = int(a["mods"][stat])
		var entry: Dictionary = {"id": a["id"], "kind": int(a["kind"]), "mods": mods_out}
		if not (a.get("on_hit", {}) as Dictionary).is_empty():
			entry["on_hit"] = a["on_hit"]
		if not (a.get("resist", {}) as Dictionary).is_empty():
			entry["resist"] = a["resist"]
		ax.append(entry)
	return {"base_id": base_id, "quality": quality, "ilvl": ilvl, "affixes": ax, "unique_id": unique_id}

static func from_dict(d: Dictionary) -> ItemInstance:
	var it := ItemInstance.new()
	it.base_id = String(d.get("base_id", ""))
	it.quality = int(d.get("quality", Quality.Q.COMMON))
	it.ilvl = int(d.get("ilvl", 1))
	it.unique_id = String(d.get("unique_id", ""))
	var ax: Array = []
	for a in d.get("affixes", []):
		var mods_in: Dictionary = {}
		for stat_key in a.get("mods", {}):
			mods_in[int(str(stat_key))] = int(a["mods"][stat_key])
		var entry: Dictionary = {"id": String(a["id"]), "kind": int(a["kind"]), "mods": mods_in}
		if a.has("on_hit"):
			entry["on_hit"] = a["on_hit"]
		if a.has("resist"):
			entry["resist"] = a["resist"]
		ax.append(entry)
	it.affixes = ax
	return it
