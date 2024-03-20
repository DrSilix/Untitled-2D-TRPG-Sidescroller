extends Node

var rng = RandomNumberGenerator.new()

func GetRoll (dice : int):
    var successes = 0
    for i in dice:
        successes += 1 if rng.randi_range(1, 6) >= 5 else 0
    return successes