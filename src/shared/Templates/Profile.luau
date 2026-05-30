--!strict
local Template = {
	-- Economy
	Cash = 100,
	Lucky = 0,

	-- Pets / Index
	Pets = {} :: {
		[string]: {
			ID: string,
			Level: number,
			Exp: number,
			CurrentHP: number,
			Slots: number,
			Moves: { string },
			DisplayName: string,
		},
	},
	UnlockedPets = {} :: { [string]: boolean },

	-- Gamepasses / DevProducts
	Vip = false,
	DoubleCash = false,
	Gamepasses = {} :: { [string]: boolean },

	-- Miscelaneous
	Item = {} :: { [string]: number },
	UnlockedItems = {} :: { any },
	UnlockedSkins = {} :: { any },

	-- Onboarding
	FirstLogin = true,

	-- Flags
	HasIncense = false,

	-- Metrics
	Wins = 0,
	Losses = 0,
	CurrentZone = "",
	LastSafeZone = "",

	TotalFights = 0,
	TimeSpent = 0,

	RobuxSpent = 0,
	CashSpent = 0,
	ChestOpen = 0,
	SpinWheel = 0,

	-- Audio
	MusicVolume = 1,
	SoundVolume = 1,
	MusicEnabled = true,
	SoundEnabled = true,
}

--// DON'T FORGET TO ALSO UPDATE *NETWORK* / *EXTRA TYPES*

return { Template = Template }
