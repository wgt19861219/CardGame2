class_name StageSweepLoot

## 扫荡掉落按次分组工具（stage_manager.sweep 的 waves/raid_bonus 构造下沉，
## LINT005 Logic 300 行守卫）。数据语义照源 stagedetail.lua readSweepReply :10-41：
## 每战一组 {exp,money,loots}，组内同 id 合并 amount=源服务器 _items 打包。


## 初始化 times 个空组槽。
static func init_wave_slots(times: int) -> Array[Array]:
	var per_wave: Array[Array] = []
	per_wave.resize(times)
	for i in range(times):
		per_wave[i] = []
	return per_wave


## 组内同 id 掉落合并 amount（重复掉落并数量，图标显示数量角标）。
static func merge(list: Array, item_id: int) -> void:
	for e in list:
		if int(e.get("id", 0)) == item_id:
			e["amount"] = int(e.get("amount", 1)) + 1
			return
	list.append({"id": item_id, "amount": 1})


## 组装 waves：times 组单战 {exp, money, loots}。
static func build_waves(times: int, single_exp: int, single_money: int, per_wave: Array[Array]) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	for t in range(times):
		waves.append({"exp": single_exp, "money": single_money, "loots": per_wave[t]})
	return waves


## Raid Bonus 配置打包（源 Stage 表 Raid Bonus ID/Amount/Type N 槽，Item 型 ×times）。
static func build_raid_bonus(stage_row: Dictionary, times: int) -> Array[Dictionary]:
	var raid_bonus: Array[Dictionary] = []
	for i in range(1, _raid_bonus_slot_max(stage_row) + 1):
		var b_id: int = int(stage_row.get("Raid Bonus ID " + str(i), 0))
		var b_amt: int = int(stage_row.get("Raid Bonus Amount " + str(i), 0))
		if String(stage_row.get("Raid Bonus Type " + str(i), "")) == "Item" and b_id != 0 and b_amt > 0:
			raid_bonus.append({"id": b_id, "amount": b_amt * times})
	return raid_bonus


## 探测配置实际使用的 Raid Bonus 槽位数（RAID_BONUS_SLOTS 上限探测，避免 magic slot 数）。
static func _raid_bonus_slot_max(stage_row: Dictionary) -> int:
	var n: int = 0
	while stage_row.has("Raid Bonus ID " + str(n + 1)):
		n += 1
	return n
