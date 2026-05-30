--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExtraTypes = require(ReplicatedStorage.Shared.Modux.ExtraTypes)
local lync = require(script.lync)

type Packet<T> = lync.Packet<T>
type DataKeyPayload = ExtraTypes.DataKeyPayload

local Network = {}
setmetatable(Network, { __index = lync })
Network.__index = Network

-- Codec compartilhado para as keys individuais (reutilizado em Packages e Types)
Network.Packages = {
	-- Pacote completo: enviado no login ou quando múltiplas keys mudam de uma vez
	Data = Network.packet(
		"Data",
		Network.struct({
			Cash = Network.int(0, 4294967295),
			Lucky = Network.int(0, 100),

			Vip = Network.bool,
			DoubleCash = Network.bool,
			Gamepasses = Network.map(Network.string(10), Network.bool),

			Pets = Network.map(
				Network.string(36),
				Network.struct({
					Id = Network.string(20),
					Level = Network.int(0, 1000),
					Exp = Network.int(0, 4294967295),
					CurrentHP = Network.int(0, 65535),
					Slot = Network.int(0, 6),
				})
			),

			Item = Network.map(Network.string(32), Network.int(0, 65535)),
			UnlockedItems = Network.map(Network.int(0, 65535), Network.bool),
			UnlockedSkins = Network.map(Network.int(0, 65535), Network.bool),

			FirstLogin = Network.bool,
			HasIncense = Network.bool,

			Wins = Network.int(0, 1000000),
			Losses = Network.int(0, 1000000),
			CurrentZone = Network.string(15),
			LastSafeZone = Network.string(15),

			TotalFights = Network.int(0, 1000000),
			TimeSpent = Network.f32,

			RobuxSpent = Network.int(0, 1000000),
			CashSpent = Network.int(0, 1000000),
			ChestOpen = Network.int(0, 100000),
			SpinWheel = Network.int(0, 100000),

			MusicVolume = Network.int(0, 1),
			SoundVolume = Network.int(0, 1),
			SoundEnabled = Network.bool,
			MusicEnabled = Network.bool,
		})
	),
	
	ZoneNotification = Network.packet(
		"ZoneNotification",
		Network.struct({
			Message = Network.string(20),
		})
	),

	-- Pacote de key única: 1 byte de tag + N bytes do valor
	-- Payload: { key = "Cash", Cash = 1000 }
	DataKey = Network.packet(
		"DataKey",
		Network.tagged("key", {
			Cash = Network.struct({ Cash = Network.int(0, 4294967295) }),
			Lucky = Network.struct({ Lucky = Network.int(0, 100) }),
			DoubleCash = Network.struct({ DoubleCash = Network.bool }),
			Vip = Network.struct({ Vip = Network.bool }),
			Gamepasses = Network.struct({ Gamepasses = Network.map(Network.string(10), Network.bool) }),

			Pets = Network.struct({
				Pets = Network.map(
					Network.string(36),
					Network.struct({
						Id = Network.string(20),
						Level = Network.int(0, 1000),
						Exp = Network.int(0, 4294967295),
						CurrentHP = Network.int(0, 65535),
						Slot = Network.int(0, 6),
					})
				),
			}),

			Item = Network.struct({ Item = Network.map(Network.string(32), Network.int(0, 65535)) }),
			UnlockedItems = Network.struct({ UnlockedItems = Network.map(Network.int(0, 65535), Network.bool) }),
			UnlockedSkins = Network.struct({ UnlockedSkins = Network.map(Network.int(0, 65535), Network.bool) }),

			FirstLogin = Network.struct({ FirstLogin = Network.bool }),
			HasIncense = Network.struct({ HasIncense = Network.bool }),

			Wins = Network.struct({ Wins = Network.int(0, 1000000) }),
			Losses = Network.struct({ Losses = Network.int(0, 1000000) }),
			CurrentZone = Network.struct({ CurrentZone = Network.string(15) }),
			LastSafeZone = Network.struct({ LastSafeZone = Network.string(15) }),

			TotalFights = Network.struct({ TotalFights = Network.int(0, 1000000) }),

			RobuxSpent = Network.struct({ RobuxSpent = Network.int(0, 1000000) }),
			CashSpent = Network.struct({ CashSpent = Network.int(0, 1000000) }),
			ChestOpen = Network.struct({ ChestOpen = Network.int(0, 100000) }),
			SpinWheel = Network.struct({ SpinWheel = Network.int(0, 100000) }),

			TimeSpent = Network.struct({ TimeSpent = Network.f32 }),

			MusicVolume = Network.struct({ MusicVolume = Network.int(0, 1) }),
			SoundVolume = Network.struct({ SoundVolume = Network.int(0, 1) }),
			SoundEnabled = Network.struct({ SoundEnabled = Network.bool }),
			MusicEnabled = Network.struct({ MusicEnabled = Network.bool }),
		})
	) :: Packet<DataKeyPayload>,
}

Network.start()

return Network
