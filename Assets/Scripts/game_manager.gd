extends Node

@export var combatArea : Area2D
@export var player : BaseCharacter
@export var enemy1 : BaseCharacter

var spawnAreas : Array

func _ready():
    #Handling Enemy Spawn
    combatArea.connect("body_entered", _on_CombatArea_body_entered,)
    var spawns = combatArea.find_children("EnemySpawn*")
    for spawn in spawns:
        spawnAreas.append(SpawnArea.new(spawn, spawn.get_child(0)))

func BeginCombat():
    pass

#Handle combat area enter
func _on_CombatArea_body_entered(body):
    if body.is_in_group("Player"):
        player.isInputDisabled = true
        player.HaltActions()
        print(spawnAreas[0].moveTarget.name)
        enemy1.MoveTo(spawnAreas[0].moveTarget.global_position)


class SpawnArea:
    var spawnArea : Sprite2D
    var moveTarget : Sprite2D

    func _init(spawn, target):
        spawnArea = spawn
        moveTarget = target