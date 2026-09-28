class_name CrewAppearance
extends RefCounted

# Identity-derived finishes keep legacy crew saves stable without new save fields.
const SUITS: Array[Color] = [Color("52615e"), Color("485b70"), Color("756650"), Color("6c4d50"), Color("747c80"), Color("496766")]

static func palette(identity: String, faction: String, hostile: bool) -> Dictionary:
	var seed := identity.hash()
	var suit: Color = SUITS[posmod(seed, SUITS.size())]
	if faction == "police": suit = suit.lerp(Color("344958"), 0.8)
	elif faction == "pirate": suit = suit.lerp(Color("51433c"), 0.6)
	var armor := Color("626b6b") if hostile else Color("79878a")
	armor = armor.lerp(suit, 0.12 + float(posmod(seed / SUITS.size(), 4)) * 0.06)
	return {"suit": suit, "armor": armor}
