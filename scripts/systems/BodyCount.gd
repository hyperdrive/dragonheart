extends RefCounted

## The body count (2026-11-16, user: "introduce a body count. Every soldier,
## farmer, miner, adventurer and dragon slayer should be counted. When the
## dragon dies they should be listed with their name, age and occupation.
## Also if more than 10 people are killed spawn a small graveyard. For every
## 3rd person that is an adventurer, farmer or miner killed spawn a haunting
## ghost.")
##
## The rules and the names. GameManager.record_kill keeps the roll;
## BaseNPC.take_damage reports each death with its killing blow. Only the
## dragon's own dead count: her claws and breath ("dragon"), Greater Flame's
## ground fires ("greater_flame") and her rider's arrows ("rider"). People
## killed by wolves, invaders or goblins are not on her roll.
## No class_name on purpose (editor rescan caveat): callers preload this.

## npc_type → occupation as the roll names it. Archers and the usurper's
## invaders are soldiers too.
const COUNTED := {
	"soldier": "Soldier of the King's garrison",
	"archer": "Archer of the King's garrison",
	"invader": "Soldier of the usurper's army",
	"farmer": "Farmer",
	"miner": "Miner",
	"adventurer": "Adventurer",
	"dragon_slayer": "Dragon slayer",
}
const DRAGON_SOURCES: Array[String] = ["dragon", "greater_flame", "rider"]
## Every 3rd of these dead raises a ghost.
const HAUNTING: Array[String] = ["adventurer", "farmer", "miner"]
const GHOST_EVERY := 3
## More than this many dead: the graveyard.
const GRAVEYARD_AFTER := 10

const AGES := {
	"soldier": [17, 46], "archer": [16, 40], "invader": [18, 44],
	"farmer": [14, 68], "miner": [13, 52], "adventurer": [19, 38],
	"dragon_slayer": [24, 50],
}

const FIRST := ["Aldous", "Ambrose", "Ansel", "Bartholomew", "Bram", "Cedric",
	"Colm", "Cuthbert", "Dunstan", "Eamon", "Edric", "Edwin", "Elias", "Ewan",
	"Fenwick", "Gareth", "Godric", "Hal", "Hamlin", "Hugh", "Ivo", "Jory",
	"Kester", "Leofric", "Lewin", "Matthias", "Merrick", "Nyle", "Odo", "Osbert",
	"Oswin", "Piers", "Quentin", "Ralf", "Rowan", "Silas", "Simkin", "Tam",
	"Tobias", "Ulric", "Wat", "Wilfred", "Wystan", "Alder", "Benedict", "Caspar",
	"Dickon", "Emmet", "Finch", "Giles", "Hob", "Jasper", "Lambert", "Ned"]
const SURNAMES := {
	"farmer": ["Thatcher", "Barley", "Millward", "Hayes", "Cotter", "Furrow",
		"Ashby", "Fielding", "Plowright", "Oakes", "Brambling", "Haywood"],
	"miner": ["Delver", "Stone", "Coalby", "Pickering", "Flint", "Hollow",
		"Shaftoe", "Irons", "Gravel", "Blackmore", "Underhill", "Cragg"],
	"soldier": ["Pike", "Shield", "Marcher", "Holt", "Warden", "Steel",
		"Ridley", "Tanner", "Bowyer", "Hart", "Kingsley", "Gatewood"],
	"adventurer": ["the Bold", "Farwander", "Quickstep", "the Lucky",
		"Brightblade", "Roamer", "the Hopeful", "Swiftwater", "Wayfarer"],
	"dragon_slayer": ["the Unflinching", "the Lance", "Wyrmbane", "of the Sunlit Shield",
		"the Last", "Drakesworn", "the Vowed"],
}
const ARMY := {"archer": "soldier", "invader": "soldier"}

## A fresh identity for one of the dead: name, age, occupation.
static func identity(npc_type: String) -> Dictionary:
	var age_range: Array = AGES.get(npc_type, [18, 50])
	var family: String = ARMY.get(npc_type, npc_type)
	var surnames: Array = SURNAMES.get(family, SURNAMES["farmer"])
	var first: String = FIRST[randi() % FIRST.size()]
	var last: String = surnames[randi() % surnames.size()]
	var name := "%s %s" % [first, last]
	if npc_type == "dragon_slayer":
		name = "Sir " + name
	return {
		"name": name,
		"age": randi_range(int(age_range[0]), int(age_range[1])),
		"occupation": str(COUNTED.get(npc_type, npc_type.capitalize())),
		"type": npc_type,
	}

## How the dragon killed them, in the roll's words.
static func cause(source: String, type: int) -> String:
	if source == "rider":
		return "shot by your rider"
	if source == "greater_flame":
		return "burned in the Greater Flame"
	if type == Damage.Type.DRAGON_FIRE:
		return "burned"
	return "torn by your claws"

static func counts(npc_type: String, source: String) -> bool:
	return COUNTED.has(npc_type) and source in DRAGON_SOURCES
