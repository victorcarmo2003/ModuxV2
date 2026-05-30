--!strict
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local ProfileController = Modux.Controller("ProfileController")

ProfileController:OnInit(function(self)
	local packages = self.Network.Packages
	packages.Data:on(function(data, sender: Player?, timestamp: number?)
		--print(data)
	end)

	packages.DataKey:on(function(payload, sender: Player?, timestamp: number?)
		--local keyname = payload.key
		--print(payload[keyname])
	end)
end)

return ProfileController
