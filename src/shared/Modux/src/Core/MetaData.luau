--!strict
local Constructor = require(script.Parent.Constructor)
local Metadata = {} :: Metadata
Metadata._registry = {}

export type Object = Constructor.Constructor
export type RegisterType = "Service" | "Controller" | "Component"
export type RegisteredObject = {
    ID: string,
    Type: RegisterType,
    Object: Object
}
export type Metadata = {
    _registry: { [string]: RegisteredObject },

    Inject: () -> (),
    Register: (RegisterType, Object) -> (),
    GetRegistry: () -> { [string]: RegisteredObject },
    Clear: () -> (),
    New: () -> Metadata,
}

function Metadata.GetRegistry() 
    return Metadata._registry
end

function Metadata.Register(Type, Object) 
    assert(type(Object) == "table", `[Modux - MetaData] Object must be a table, got {type(Object)}`)
    assert(type(Type) == "string", `[Modux - MetaData] Type must be a string, got {type(Type)}`)
    local id = Object.ID
    assert(type(id) == "string", `[Modux - MetaData] Object must have an ID of type string, got {type(id)}`)

    if Metadata._registry[id] then
        error(`[Modux - MetaData] Object with ID {id} is already registered.`)
    end

    Metadata._registry[id] = {
        ID = id,
        Type = Type,
        Object = Object
    }
end

function Metadata.Clear() 
    table.clear(Metadata._registry)
end

return Metadata
