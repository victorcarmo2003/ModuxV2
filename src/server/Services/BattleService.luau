local Modux = require(game.ReplicatedStorage.Shared.Modux)
local BattleService = Modux.Service("BattleService")
BattleService:Extend("ZoneService")

BattleService:OnInit(function(self) 
end)

BattleService:OnStart(function(self) end)

return BattleService
