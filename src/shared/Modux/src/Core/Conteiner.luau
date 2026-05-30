--!strict
local Conteiner = {}
Conteiner._all = {} :: { [string]: Registered }
Conteiner._sealed = false

export type Mode = "Singleton" | "Transient"
export type Type = "Service" | "Controller" | "Component"
export type Registered = {
	Object: any,
	ScopeType: Mode,
	Type: Type,
}

function Conteiner.Register(id: string, object: any, Mode: Mode, Type: Type)
	if Conteiner._sealed then
		error(`[Modux - MetaData] Cannot bind object with ID {id} because the container is sealed.`)
	end
	if Conteiner._all[id] then
		error(`[Modux - MetaData] Object with ID {id} is already registered.`)
	end

	if Mode == "Transient" then
		Conteiner._all[id] = {
			Object = object,
			ScopeType = Mode,
			Type = Type,
		}
		return
	end

	Conteiner._all[id] = {
		Object = object,
		ScopeType = Mode,
		Type = Type,
	}
end

function Conteiner.Resolve(self: any, ID: string, scopeKey: string?)
	local obj = Conteiner._all[ID]

	if not obj then
		error(`[Modux - MetaData] Object with ID {ID} is not registered.`)
	end

	if obj.ScopeType == "Transient" then
		-- Criamos uma cópia que herda tudo do Template original
		local template = obj.Object
		local copy = table.clone(template)
		-- Isolamento de tarefas de limpeza (Deep clone manual do _cleanupTasks)
		copy._cleanupTasks = {}
		-- Mantemos o metatable (que contém Constructor, etc)
		setmetatable(copy, getmetatable(template))
		return copy
	end

	--> Singleton
	return obj.Object
end



function Conteiner.Has(id: string): boolean
	return Conteiner._all[id] ~= nil
end

function Conteiner.Destroy(id: string)
	if not Conteiner._all[id] then
		error(`[Modux - MetaData] Object with ID {id} is not registered.`)
	end
	Conteiner._all[id] = nil
end

function Conteiner.Seal()
	Conteiner._sealed = true
end

function Conteiner.Clear()
	Conteiner._all = {}
	Conteiner._sealed = false
end

return Conteiner
