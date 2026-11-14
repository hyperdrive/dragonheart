extends RefCounted

class_name Damage

## One damage model for every actor (2026-11-14, user: "a consistent HP
## system with different damage types"). Everything that hurts calls
##
##     target.take_damage(amount, Damage.Type.X, "source")
##
## on a BaseNPC or the Dragon; HP falls, and the actor dies at 0 — nothing
## else kills (fire used to kill on burnout regardless of HP; claws used
## to be a pure kill lottery).
##
##   WEAPON       swords, spears, claws, arrows, contact blows. The dragon's
##                scales turn some of it (−2 per Scales level above 1).
##   DRAGON_FIRE  the breath: one ignition burns for burn_duration and deals
##                FIRE_PER_BURN in total, so a 50–60 HP commoner still dies
##                to one burn; bosses need several.
##   MAGIC        lightning, spectral swords, the hag's cloud of claws.
##                Scales don't help; the wizard's shield still absorbs.
##   ENVIRONMENT  the world itself (drowning, falling rock, burning fields) —
##                reserved for terrain hazards.
##
## Per-actor multipliers: BaseNPC.damage_taken = {Damage.Type.X: 0.5, …}
## (missing = 1.0). The dragon's claws deal CLAW damage per hit; their old
## instant "maul" survives as a bonus chance on ordinary soldiers/goblins
## (BaseNPC.can_be_mauled) — tough foes only ever take the claw damage.

enum Type { WEAPON, DRAGON_FIRE, MAGIC, ENVIRONMENT }

## Total fire damage of one ignition (spread over the burn).
const FIRE_PER_BURN := 60
## One dragon claw strike (E).
const CLAW := 16

static func type_name(t: Type) -> String:
	return ["weapon", "dragon fire", "magic", "environment"][t]

## Apply a multiplier; any non-zero hit stays at least 1.
static func scaled(amount: int, mult: float) -> int:
	if amount <= 0 or mult <= 0.0:
		return 0
	return maxi(1, int(round(float(amount) * mult)))
