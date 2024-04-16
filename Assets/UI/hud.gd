extends Control

@onready var player_choose_action: Control = $"../PlayerChooseAction"

@onready var attacker_info_panel: Control = $AttackerInfoPanel
@onready var attacker_name: Label = $AttackerInfoPanel/Name
@onready var attacker_health_bar: ProgressBar = $AttackerInfoPanel/HealthBar
@onready var attacker_ap_bar: ProgressBar = $AttackerInfoPanel/APBar
@onready var attacker_cover_icon: TextureRect = $AttackerInfoPanel/CoverIcon
@onready var attacker_aim_icon: TextureRect = $AttackerInfoPanel/AimIcon
@onready var attacker_ammo_bar: ProgressBar = $AttackerInfoPanel/AmmoIcon/AmmoBar
@onready var attacker_stats: Control = $AttackerInfoPanel/Stats
@onready var attacker_data_1: Label = $AttackerInfoPanel/Stats/data1
@onready var attacker_data_2: Label = $AttackerInfoPanel/Stats/data2
@onready var attacker_data_3: Label = $AttackerInfoPanel/Stats/data3
@onready var attacker_clickable_area: Button = $AttackerInfoPanel/ClickableArea

@onready var defender_info_panel: Control = $DefenderInfoPanel
@onready var defender_name: Label = $DefenderInfoPanel/Name
@onready var defender_range: Label = $DefenderInfoPanel/Range
@onready var defender_chance: Label = $DefenderInfoPanel/Chance
@onready var defender_health_bar: ProgressBar = $DefenderInfoPanel/HealthBar
@onready var defender_cover_icon: TextureRect = $DefenderInfoPanel/CoverIcon

var cachedChanceCalculations : Dictionary
var _currentAttacker : BaseCharacter
var _currentDefender : BaseCharacter
var _currentAttackType : String

func _ready():
	player_choose_action.connect("hud_combat_state_changed", _on_hud_state_change)

func ResetHUD():
	_on_hud_state_change(null, null, "")
	
func _on_hud_state_change(attacker : BaseCharacter, defender : BaseCharacter, attackType : String):
	if _currentAttacker: _currentAttacker.disconnect("character_stats_changed", UpdateAttackerInfo)
	if _currentDefender: _currentDefender.disconnect("character_stats_changed", UpdateDefenderInfo)
	_currentAttacker = attacker
	_currentDefender = defender
	_currentAttackType = attackType
	if not attacker and not defender:
		attacker_info_panel.visible = false
		defender_info_panel.visible = false
		cachedChanceCalculations = {}
	if attacker:
		_currentAttacker.connect("character_stats_changed", UpdateAttackerInfo)
		UpdateAttackerInfo()
	else:
		attacker_info_panel.visible = false
		defender_info_panel.visible = false
		return
	if defender:
		_currentDefender.connect("character_stats_changed", UpdateDefenderInfo)
		UpdateDefenderInfo()
	else:
		defender_info_panel.visible = false

func UpdateAttackerInfo():
	print("attacker HUD updated")
	attacker_info_panel.visible = true
	attacker_name.text = _currentAttacker.characterAlias
	attacker_health_bar.value = ceil((_currentAttacker.currentHealth as float / _currentAttacker.maxHealth) * 100)
	attacker_ap_bar.value = _currentAttacker.currentActionPoints
	attacker_cover_icon.visible = true if _currentAttacker.hasCover > 0 else false
	attacker_aim_icon.visible = true if _currentAttacker.aimModifier != 0 else false
	var goodColor = Color("#91ff7e")
	var badColor = Color("#d31f41")
	attacker_aim_icon.self_modulate = goodColor if _currentAttacker.aimModifier > 0 else badColor
	attacker_ammo_bar.value = ceil((_currentAttacker.currentWeaponAmmo as float / _currentAttacker.maxWeaponAmmo) * 100)
	attacker_data_1.text = "\n" + str(_currentAttacker.weaponSkill) + "\n" \
			+ str(_currentAttacker.weaponDamage) + "\n" \
			+ str(_currentAttacker.weaponAccuracy)
	attacker_data_2.text = str(_currentAttacker.currentHealth) + "/" + str(_currentAttacker.maxHealth) + "\n" \
			+ str(_currentAttacker.getHealthPenalty()) + "\n" \
			+ str(_currentAttacker.armor) + "\n" \
			+ str(_currentAttacker.moveSpeed)
	var coverText = "YES" if _currentAttacker.hasCover > 0 else "NO"
	var aimPlus = "+" if _currentAttacker.aimModifier > 0 else ""
	attacker_data_3.text = coverText + "\n" \
			+ aimPlus + str(_currentAttacker.aimModifier) + "\n" \
			+ str(_currentAttacker.currentWeaponAmmo) + "/" + str(_currentAttacker.maxWeaponAmmo) + "\n" \
			+ str(_currentAttacker.grenadeAmmo)

func UpdateDefenderInfo():
	print("defender HUD updated")
	defender_info_panel.visible = true
	defender_name.text = _currentDefender.characterAlias
	var distancePenalty = _currentAttacker.CalculateDistancePenalty(_currentDefender)
	defender_range.text = (
			"SHORT" if distancePenalty == 0
			else "MEDIUM" if distancePenalty == -2
			else "LONG" if distancePenalty == -4
			else "EXTRM"
	)
	defender_range.text += "(" + str(distancePenalty) + ")"
	defender_health_bar.value = ceil((_currentDefender.currentHealth as float / _currentDefender.maxHealth) * 100)
	defender_cover_icon.visible = true if _currentDefender.hasCover > 0 else false
	var chanceToHitDefender = 0
	var ap = _currentAttacker.currentActionPoints
	if cachedChanceCalculations.has(_currentDefender.name + _currentAttackType + str(ap)):
		print("found cached chance calc for " + _currentDefender.name)
		chanceToHitDefender = cachedChanceCalculations[_currentDefender.name + _currentAttackType + str(ap)]
	else:
		print("creating cached chance calc for " + _currentDefender.name)
		chanceToHitDefender = CalculateHitChance(_currentAttacker, _currentDefender, _currentAttackType)
		cachedChanceCalculations[_currentDefender.name + _currentAttackType + str(ap)] = chanceToHitDefender
	defender_chance.text = str(chanceToHitDefender) + "%"

func CalculateHitChance(attacker : BaseCharacter, defender : BaseCharacter, attackType : String) -> int:
	var successCount = 0
	for i in range(1000):
		if TestForSingleAttackSuccess(attacker, defender, attackType):
			successCount += 1
	return successCount/10

func TestForSingleAttackSuccess(attacker : BaseCharacter, defender : BaseCharacter, attackType : String) -> bool:
	var toHit = attacker.RollToHit(attacker.CalculateDistancePenalty(defender))
	var defenderToAvoidPenalty = 0 if attackType != "shootburst" else -2
	var toAvoid = defender.RollToAvoidAttack(defenderToAvoidPenalty)
	if toAvoid < toHit:
		var damageToDeal = attacker.CalculateDamageToDeal(toHit - toAvoid)
		var damageToResist = defender.RollToResistDamage()
		if damageToResist < damageToDeal:
			return true
	return false

func _on_clickable_area_gui_input() -> void:
	if attacker_stats.visible:
		attacker_stats.visible = false
		attacker_clickable_area.size.y = 40
	else:
		attacker_stats.visible = true
		attacker_clickable_area.size.y = 90
