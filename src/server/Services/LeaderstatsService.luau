local Modux = require(game.ReplicatedStorage.Shared.Modux)
local LeaderstatsService = Modux.Service("LeaderstatsService")
LeaderstatsService:Extend("PlayerService")
LeaderstatsService:Import("ProfileService")

LeaderstatsService:OnInit(function(self) 
    
end)

LeaderstatsService:OnStart(function(self) 

end)

return LeaderstatsService
