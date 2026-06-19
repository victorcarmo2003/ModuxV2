local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Modux.src.Network)

local GridCellCodec = Network.struct({
    position = Network.tuple(Network.int(1, 5), Network.int(1, 5)),
    occupied = Network.bool,
    occupant = Network.optional(Network.int(1, 5)),
})

local GridCodec = Network.map(Network.string(8), GridCellCodec)

local Netwotking = {
    GameInit = Network.packet("Init", Network.struct({
        PlayerGrid = GridCodec,
        
    }), {
        rateLimit = 1
    })
}

return Netwotking
