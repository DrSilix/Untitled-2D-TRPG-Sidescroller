extends Node
## Handles dice roll game mechanice
var rng = RandomNumberGenerator.new()
## carries out a simplified shadowrun style dice roll whereby a number of d6's
## are rolled and for each 5 or 6, one success is counted
## [param dice] number of d6 dice to roll
## [return int] sum of dice whose faces came up 5 or 6
func GetRoll (dice : int):
	var successes = 0
	for i in dice:
		successes += 1 if rng.randi_range(1, 6) >= 5 else 0
	return successes
