return {
	STAGE_2 = {
		dalmatian = {
			Id = "dalmatian",
			DisplayName = "Dalmatian",
			Description = "The evolved form of Dog, very spotted and energetic.",
			Rarity = "Uncommon",
			Elements = { "Earth" },
			BaseStats = { HP = 120, Attack = 90, Defense = 80, Special = 60, Speed = 100, Energy = 120, Level = 15, Exp = 0 },
			Growth = { HP = 6, Attack = 4.5, Defense = 4, Special = 3, Speed = 5, Energy = 15, Level = 0, Exp = 0 },
			CaptureRate = 50, EssenceYield = 15,
			MoveSet = { { Level = 1, MoveId = "bonk" }, { Level = 15, MoveId = "drum_rush" } },
			Evolution = nil,
			ModelName = "dalmatian",
			Icon = nil,
		},
		
		--[[ TEMPLATE PARA NOVOS PETS
		template_pet = {
			Id = "template_pet",
			DisplayName = "Template Pet",
			Description = "...",
			Rarity = "Common",
			Elements = { "Earth" },
			BaseStats = { HP = 100, Attack = 50, Defense = 50, Special = 50, Speed = 50, Energy = 100, Level = 1, Exp = 0 },
			Growth = { HP = 5, Attack = 2, Defense = 2, Special = 2, Speed = 2, Energy = 10, Level = 0, Exp = 0 },
			CaptureRate = 100, EssenceYield = 5,
			MoveSet = { { Level = 1, MoveId = "bonk" } },
			Evolution = nil,
			ModelName = "template_pet",
			Icon = nil,
		},
		]]
	},
}