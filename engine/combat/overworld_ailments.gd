class_name OverworldAilments
extends Object

# 地表（非戰鬥）中毒外滲：只有 POISON 生效，每跳扣 potency 但不致死（HP 下限 1），
# remaining 倒數歸零即解。回傳事件字串供 message log。

static func tick_poison(members: Array) -> Array:
	var events: Array = []
	for c in members:
		if not c.is_conscious():
			continue
		var kept: Array[StatusEffect] = []
		for s in c.statuses:
			if s.kind == StatusEffect.Kind.POISON:
				c.hp = maxi(1, c.hp - s.potency)
				events.append("%s 因中毒失去了 %d 點 HP。" % [c.name, s.potency])
				s.remaining -= 1
				if s.remaining > 0:
					kept.append(s)
			else:
				kept.append(s)
		c.statuses = kept
	return events
