local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Modux.Types)

local Extend: (self: any, id: string) -> any = function(self: any, id: string)
    self._extend = id
    return self
end

return Extend