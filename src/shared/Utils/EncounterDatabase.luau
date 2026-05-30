--!strict
local EncounterDatabase = {
	Zone1 = {
		Elements = { "Nature", "Wind", "Earth" },
		Name = "Green Hills",
		LevelRange = NumberSequence.new(3, 15),
		RecommendedLevel = NumberRange.new(1, 20),
		RarityChances = {
			Common = 80,
			Uncommon = 15.85,
			Rare = 3,
			Epic = 1,
			Legendary = 0.1,
			Mythic = 0.05,
		},
	},
	Zone2 = {
		Elements = { "Sand", "Water" },
		Name = "Sand and Shores",
		RecommendedLevel = NumberRange.new(25, 50),
		LevelRange = NumberSequence.new(25, 40),
		RarityChances = {
			Common = 50,
			Uncommon = 25,
			Rare = 15,
			Epic = 5,
			Legendary = 3.5,
			Mythic = 1.5,
		},
	},
}

return EncounterDatabase
