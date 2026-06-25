class_name Resistance
extends Object

# 帶號抗性：正 = 吃得少、負 = 被克制（吃得多）、0/缺項 = 中性、≥100 = 免疫。
static func apply(raw_damage: int, resist_pct: int) -> int:
	return maxi(0, int(floor(raw_damage * (100 - resist_pct) / 100.0)))
