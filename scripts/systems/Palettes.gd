extends RefCounted

## Colour palettes (2026-11-15, user: "explore different colour schemas …
## select four which I can cycle through. Right now there are no warm
## colours so I'm thinking we should work with layers. Back layer, ie the
## ground should be grim dark. Houses should be more saturated towards a
## warm tone and characters should be bright. Only compatible colours, even
## if they don't follow same gradients.")
##
## Every palette grades three layers (LayerGrade.gd applies them):
##   back   — the ground and the land: mountains, trees, lakes, the glade.
##            A grim-dark gradient map: luminance → dark / mid / light.
##   middle — houses and works: the city, tower, mines, pens, fields, the
##            hag's hut, the temple, the lair, the camp. Pulled toward a
##            warm, saturated ramp — lamplight against the gloom.
##   front  — the dragon and every NPC: bright and clear, a light tint only.
## (A fourth, "land" — the trees — is derived from back unless a palette
## names it: GameManager._land_from.)
## Each layer: the ramp (dark, mid, light), how strongly the ramp replaces
## the original colour (`mix`), then saturation and exposure on top.
## The four are designed as sets: the warm middle always sits opposite the
## cold back on the colour wheel, so the layers stay compatible even though
## their gradients differ.
##
## DEFAULT: the palette a run starts with (Peat & Lantern, the user's pick).
const DEFAULT := 2

## No class_name on purpose (editor rescan caveat): callers preload this.

const PALETTES: Array[Dictionary] = [
	{
		"name": "Ashen Hearth",
		"blurb": "slate and lichen, hearths of rust and ochre",
		"back": {"dark": Color("1b211f"), "mid": Color("46513f"), "light": Color("8f9478"),
			"mix": 0.62, "sat": 0.75, "exp": 0.92},
		"middle": {"dark": Color("2a1a12"), "mid": Color("94532d"), "light": Color("e8b06a"),
			"mix": 0.38, "sat": 1.18, "exp": 1.0},
		"front": {"dark": Color("1e1c22"), "mid": Color("8c8478"), "light": Color("fff4e2"),
			"mix": 0.12, "sat": 1.12, "exp": 1.1},
	},
	{
		"name": "Blood Moon",
		"blurb": "bruised violet dusk, crimson and brass",
		"back": {"dark": Color("19161f"), "mid": Color("403a4c"), "light": Color("857d8f"),
			"mix": 0.66, "sat": 0.7, "exp": 0.9},
		"middle": {"dark": Color("2b0f12"), "mid": Color("a23b2b"), "light": Color("f0b878"),
			"mix": 0.4, "sat": 1.2, "exp": 1.0},
		"front": {"dark": Color("1d1a20"), "mid": Color("8f8086"), "light": Color("fff0e8"),
			"mix": 0.12, "sat": 1.12, "exp": 1.1},
	},
	{
		"name": "Peat & Lantern",
		"blurb": "bog-brown moor, amber lanterns",
		"back": {"dark": Color("1b1c15"), "mid": Color("47472f"), "light": Color("918c62"),
			"mix": 0.6, "sat": 0.78, "exp": 0.92},
		# buildings brighter (user, 2026-11-15: "I like the peat and lantern,
		# but buildings need to be brighter" … "brighter still"): a light
		# ramp, high exposure, the art's own colours largely kept
		"middle": {"dark": Color("4a3418"), "mid": Color("d89a44"), "light": Color("fff0c4"),
			"mix": 0.3, "sat": 1.12, "exp": 1.45},
		"front": {"dark": Color("1c1d1a"), "mid": Color("8a8a7c"), "light": Color("fbf7e8"),
			"mix": 0.1, "sat": 1.12, "exp": 1.1},
	},
	{
		"name": "Frostbitten",
		"blurb": "teal steel and frost, copper candlelight",
		"back": {"dark": Color("131b21"), "mid": Color("33464f"), "light": Color("7d939a"),
			"mix": 0.64, "sat": 0.72, "exp": 0.9},
		"middle": {"dark": Color("2a160e"), "mid": Color("b25d30"), "light": Color("f2b680"),
			"mix": 0.4, "sat": 1.18, "exp": 1.0},
		"front": {"dark": Color("1a1d21"), "mid": Color("838a90"), "light": Color("f4f8ff"),
			"mix": 0.12, "sat": 1.1, "exp": 1.1},
	},
]
