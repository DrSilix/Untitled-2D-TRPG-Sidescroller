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

func _ready():
	player_choose_action.connect("hud_combat_state_changed", _on_hud_state_change)

func ResetHUD():
	_on_hud_state_change(null, null, "")
	
func _on_hud_state_change(attacker : BaseCharacter, defender : BaseCharacter, attackType : String):
	if not attacker and not defender:
		attacker_info_panel.visible = false
		defender_info_panel.visible = false
		cachedChanceCalculations = {}
	if attacker:
		attacker_info_panel.visible = true
		attacker_name.text = attacker.characterAlias
		attacker_health_bar.value = ceil((attacker.currentHealth as float / attacker.maxHealth) * 100)
		attacker_ap_bar.value = attacker.currentActionPoints
		attacker_cover_icon.visible = true if attacker.hasCover > 0 else false
		attacker_aim_icon.visible = true if attacker.aimModifier != 0 else false
		var goodColor = Color("#91ff7e")
		var badColor = Color("#d31f41")
		attacker_aim_icon.self_modulate = goodColor if attacker.aimModifier > 0 else badColor
		attacker_ammo_bar.value = ceil((attacker.currentWeaponAmmo as float / attacker.maxWeaponAmmo) * 100)
		attacker_data_1.text = "\n" + str(attacker.weaponSkill) + "\n" \
				+ str(attacker.weaponDamage) + "\n" \
				+ str(attacker.weaponAccuracy)
		attacker_data_2.text = str(attacker.currentHealth) + "/" + str(attacker.maxHealth) + "\n" \
				+ str(attacker.getHealthPenalty()) + "\n" \
				+ str(attacker.armor) + "\n" \
				+ str(attacker.moveSpeed)
		var coverText = "YES" if attacker.hasCover > 0 else "NO"
		var aimPlus = "+" if attacker.aimModifier > 0 else ""
		attacker_data_3.text = coverText + "\n" \
				+ aimPlus + str(attacker.aimModifier) + "\n" \
				+ str(attacker.currentWeaponAmmo) + "/" + str(attacker.maxWeaponAmmo) + "\n" \
				+ str(attacker.grenadeAmmo)
	else:
		attacker_info_panel.visible = false
		defender_info_panel.visible = false
		return
	if defender:
		defender_info_panel.visible = true
		defender_name.text = defender.characterAlias
		var distancePenalty = attacker.CalculateDistancePenalty(defender)
		defender_range.text = (
				"SHORT" if distancePenalty == 0
				else "MEDIUM" if distancePenalty == -2
				else "LONG" if distancePenalty == -4
				else "EXTRM"
		)
		defender_range.text += "(" + str(distancePenalty) + ")"
		defender_health_bar.value = ceil((defender.currentHealth as float / defender.maxHealth) * 100)
		defender_cover_icon.visible = true if defender.hasCover > 0 else false
		var chanceToHitDefender = 0
		var ap = attacker.currentActionPoints
		if cachedChanceCalculations.has(defender.name + attackType + str(ap)):
			print("found cached chance calc for " + defender.name)
			chanceToHitDefender = cachedChanceCalculations[defender.name + attackType + str(ap)]
		else:
			print("creating cached chance calc for " + defender.name)
			chanceToHitDefender = CalculateHitChance(attacker, defender, attackType)
			cachedChanceCalculations[defender.name + attackType + str(ap)] = chanceToHitDefender
		defender_chance.text = str(chanceToHitDefender) + "%"
	else:
		defender_info_panel.visible = false

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
