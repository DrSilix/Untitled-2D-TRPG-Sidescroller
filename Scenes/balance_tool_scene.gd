extends Node2D

@onready var enemy = $Enemy

@onready var game_manager = $GameManager
@onready var camera_2d : Camera2D = $Camera2D

# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().create_timer(0.5).timeout

	camera_2d.position_smoothing_enabled = false
	camera_2d.reparent(self)
	camera_2d.global_position = Vector2(168, 96)
	await get_tree().create_timer(0.1).timeout
	camera_2d.position_smoothing_enabled = true
	
	var punk = game_manager.punk_player
	var biker = game_manager.biker_player
	var cyborg = game_manager.cyborg_player
	
	punk.visible = true
	cyborg.visible = true
	
	GetAttackStatsTest(biker, enemy, 1000, 0, false, 0, 0)
	GetAttackStatsTest(enemy, biker, 1000, 0, false, 0, 0)
	print("")
	GetAttackStatsTest(cyborg, enemy, 1000, 0, false, 0, 0)
	GetAttackStatsTest(enemy, cyborg, 1000, 0, false, 0, 0)
	print("")
	GetAttackStatsTest(punk, enemy, 1000, 0, false, 0, 0)
	GetAttackStatsTest(enemy, punk, 1000, 0, false, 0, 0)
	
func GetAttackStatsTest(attacker : BaseCharacter, defender : BaseCharacter, numberOfRuns : int, \
	attackToHitMod : int = 0, targetHasCover : bool = false, rangePenalty : int = 0, aimModifier : int = 0, \
	attackerHealthOverride : int = 0, defenderHealthOverride : int = 0):
	var min = {"toHit" : 999,
		"toAvoid" : 999,
		"damageToDeal" : 999,
		"damageToResist" : 999,
		"finalDamage" : 999}
	var max = {"toHit" : 0,
		"toAvoid" : 0,
		"damageToDeal" : 0,
		"damageToResist" : 0,
		"finalDamage" : 0}
	var avg = {"toHit" : 0,
		"toAvoid" : 0,
		"damageToDeal" : 0,
		"damageToResist" : 0,
		"finalDamage" : 0}
	var missCount = 0
	var resistCount = 0
	var hitCount = 0
	
	var _avgCount = {"toHit" : 0,
		"toAvoid" : 0,
		"damageToDeal" : 0,
		"damageToResist" : 0,
		"finalDamage" : 0}
	
	if attackerHealthOverride > 0: attacker.currentHealth = attackerHealthOverride
	if defenderHealthOverride > 0: defender.currentHealth = defenderHealthOverride
	if targetHasCover: defender.chanceToHitModifier = -2
	attacker.aimModifier = aimModifier
	
	
	for i in range(numberOfRuns):
		var result = EvalTestCase(attacker, defender, attackToHitMod, rangePenalty)
		for key in ["toHit", "toAvoid", "damageToDeal", "damageToResist", "finalDamage"]:
			if result[key] < min[key] and key in ["toHit", "toAvoid"]: min[key] = result[key]
			if result[key] < min[key] and key in ["damageToDeal", "damageToResist", "finalDamage"]:
				min[key] = result[key] if result[key] > -1 else min[key]
			if result[key] > max[key]: max[key] = result[key]
			if result[key] > -1:
				avg[key] += result[key]
				_avgCount[key] += 1
		if result["didMiss"]: missCount += 1
		if result["didResist"] and not result["didMiss"]: resistCount += 1
		if result["finalDamage"] > 0: hitCount += 1
				
	
	print(attacker.name, " vs. ", defender.name, " - ", numberOfRuns)
	for key in ["toHit", "toAvoid", "damageToDeal", "damageToResist", "finalDamage"]:
		var alignedKey = key
		if key in ["toHit", "toAvoid"]: alignedKey += "\t\t"
		if key == "finalDamage": alignedKey += "\t"
		print (alignedKey, "\tmin=", min[key], "\tmax=", max[key], "\tavg=", (avg[key]/_avgCount[key]), \
		"\trange=", max[key]-min[key])
	print("misses=", missCount, "(", (float(missCount)/numberOfRuns) * 100, "%)", \
		"\tresists=", resistCount, "(", (float(resistCount)/numberOfRuns) * 100, "%)", \
		"\thits=", hitCount, "(", (float(hitCount)/numberOfRuns) * 100, "%)")
	
	if attackerHealthOverride > 0: attacker.currentHealth = attacker.maxHealth
	if defenderHealthOverride > 0: defender.currentHealth = defender.maxHealth
	if targetHasCover: defender.chanceToHitModifier = 0
	attacker.aimModifier = 0

func EvalTestCase(attacker : BaseCharacter, defender : BaseCharacter, toHitMod : int, rangePenalty : int):
	var toHit = attacker.RollToHit(rangePenalty)
	var toAvoid = defender.RollToAvoidAttack(toHitMod)
	var damageToResist = -1
	var damageToDeal = -1
	var finalDamage = -1
	if toAvoid < toHit:
		damageToDeal = attacker.CalculateDamageToDeal(toHit - toAvoid)
		damageToResist = defender.RollToResistDamage()
		if damageToResist < damageToDeal:
			finalDamage = damageToDeal - damageToResist
	var result = {
		"toHit" : toHit,
		"toAvoid" : toAvoid,
		"didMiss" : toAvoid >= toHit,
		"damageToDeal" : damageToDeal,
		"damageToResist" : damageToResist,
		"didResist" :  damageToResist >= damageToDeal,
		"finalDamage" : finalDamage
	}
	return result


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
