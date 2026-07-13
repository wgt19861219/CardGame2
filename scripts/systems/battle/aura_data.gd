class_name AuraData
extends RefCounted

## 光环数据（Step 1.1 阶段3 通用机制）：持续范围影响。
## owner 周围 radius 内的 target_camp 单位受 buff 影响（友军增益/敌军减益）。

enum TargetCamp { ALLY, ENEMY }

var buff: BattleBuff
var radius: float = 0.0
var target_camp: int = TargetCamp.ALLY

func _init(aura_buff: BattleBuff = null, aura_radius: float = 0.0, camp: int = TargetCamp.ALLY) -> void:
	buff = aura_buff
	radius = aura_radius
	target_camp = camp
