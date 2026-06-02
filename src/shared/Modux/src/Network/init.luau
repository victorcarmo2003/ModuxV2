--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Modux.Types)
local lync = require(script.lync)

type Packet<T> = lync.Packet<T>
type DataTemplate = Types.DataTemplate
type DataKeyPayload = Types.DataKeyPayload

local Network = {}
setmetatable(Network, { __index = lync })
Network.__index = Network

-- Codec compartilhado para as keys individuais (reutilizado em Packages e Types)
Network.Packages = {
	-- Pacote completo: enviado no login ou quando múltiplas keys mudam de uma vez
	Data = Network.packet(
		"Data",
		Network.struct({
			Gems = Network.int(0, 4294967295),
			Gamepasses = Network.map(Network.string(10), Network.bool),

			Item = Network.map(Network.string(32), Network.int(0, 65535)),
			UnlockedItems = Network.map(Network.int(0, 65535), Network.bool),
			UnlockedClasses = Network.map(Network.int(0, 65535), Network.bool),
			Badgets = Network.map(Network.int(0, 65535), Network.bool),

			FirstLogin = Network.bool,

			Wins = Network.int(0, 65536),
			DayCount = Network.int(0, 65536),
			CurrentZone = Network.string(15),
			CurrentClass = Network.string(32),
			TimeSpent = Network.f32,

			RobuxSpent = Network.int(0, 1000000),
			GemsSpent = Network.int(0, 1000000),
			ChestOpen = Network.int(0, 100000),
			SpinWheel = Network.int(0, 100000),

			MusicVolume = Network.int(0, 1),
			SoundVolume = Network.int(0, 1),
			SoundEnabled = Network.bool,
			MusicEnabled = Network.bool,
		})
	) :: Packet<DataTemplate>,

	-- Pacote de key única: 1 byte de tag + N bytes do valor
	-- Payload: { key = "Gems", Gems = 1000 }
	DataKey = Network.packet(
		"DataKey",
		Network.tagged("key", {
			Gems = Network.struct({ Gems = Network.int(0, 4294967295) }),
			Gamepasses = Network.struct({ Gamepasses = Network.map(Network.string(10), Network.bool) }),

			Item = Network.struct({ Item = Network.map(Network.string(32), Network.int(0, 65535)) }),
			UnlockedItems = Network.struct({ UnlockedItems = Network.map(Network.int(0, 65535), Network.bool) }),
			UnlockedClasses = Network.struct({ UnlockedClasses = Network.map(Network.int(0, 65535), Network.bool) }),
			Badgets = Network.struct({ Badgets = Network.map(Network.int(0, 65535), Network.bool) }),

			FirstLogin = Network.struct({ FirstLogin = Network.bool }),

			Wins = Network.struct({ Wins = Network.int(0, 65536) }),
			DayCount = Network.struct({ DayCount = Network.int(0, 65536) }),
			CurrentZone = Network.struct({ CurrentZone = Network.string(15) }),
			CurrentClass = Network.struct({ CurrentClass = Network.string(32) }),

			TimeSpent = Network.struct({ TimeSpent = Network.f32 }),

			RobuxSpent = Network.struct({ RobuxSpent = Network.int(0, 1000000) }),
			GemsSpent = Network.struct({ GemsSpent = Network.int(0, 1000000) }),
			ChestOpen = Network.struct({ ChestOpen = Network.int(0, 100000) }),
			SpinWheel = Network.struct({ SpinWheel = Network.int(0, 100000) }),

			MusicVolume = Network.struct({ MusicVolume = Network.int(0, 1) }),
			SoundVolume = Network.struct({ SoundVolume = Network.int(0, 1) }),
			SoundEnabled = Network.struct({ SoundEnabled = Network.bool }),
			MusicEnabled = Network.struct({ MusicEnabled = Network.bool }),
		})
	) :: Packet<DataKeyPayload>,

	ZoneNotification = Network.packet(
		"ZoneNotification",
		Network.struct({
			Message = Network.string(20),
		})
	),

	SecondsCycle = Network.packet(
		"SecondsCycle",
		Network.struct({
			Message = Network.int(0, 420),
		})
	),
	DayCycle = Network.packet(
		"DayCycle",
		Network.struct({
			Message = Network.int(0, 10000),
		})
	),
}

Network.start()

return Network
