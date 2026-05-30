--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Modux.src.Components.ComponentRegistry)
local Constructor = {}
Constructor.__index = Constructor
Constructor._imports = {}
Constructor._onInit = nil
Constructor._onStart = nil
Constructor._onSimulation = {}
Constructor._onDestroy = nil
Constructor._tag = nil
Constructor._className = nil
Constructor._attributeSchema = nil
Constructor._requiredChildren = nil
Constructor._cleanupTasks = {}

export type Type = "Service" | "Controller" | "Component"

export type Constructor = typeof(setmetatable({}, Constructor))

function Constructor:OnInit(cb: (self: any) -> ())
	self._onInit = cb
	return self
end

function Constructor:OnStart(cb: (self: any) -> ())
	self._onStart = cb
	return self
end

function Constructor:OnSimulation(cb: (self: any) -> (), frequency: Enum.StepFrequency?, priority: number?)
	table.insert(self._onSimulation, {
		Callback = cb,
		Frequency = frequency,
		Priority = priority,
	})
	return self
end

function Constructor:OnDestroy(cb: (self: any) -> ())
	self._onDestroy = cb
	return self
end

function Constructor:Tag(tag: string)
	self._tag = tag
	return self
end

function Constructor:ClassName(className: string)
	self._className = className
	return self
end

function Constructor:AttributeDefaults(schema: { [string]: any })
	self._attributeSchema = schema
	return self
end

function Constructor:Children(children: { string })
	self._requiredChildren = children
	return self
end

-- Retorna todos os componentes ativos de um determinado ID (ex: "Zombie")
function Constructor:GetAllComponents(id: string)
	return Registry.GetAll(id)
end

-- Retorna o componente específico de uma instância
function Constructor:GetComponent(instance: Instance, id: string)
	return Registry.Get(instance, id)
end

function Constructor:Cleanup(task: any)
	table.insert(self._cleanupTasks, task)
	return task
end

function Constructor:_doCleanup()
	for _, task in self._cleanupTasks do
		if typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		elseif typeof(task) == "Instance" then
			task:Destroy()
		elseif typeof(task) == "function" then
			task()
		elseif typeof(task) == "table" then
			if typeof(task.Destroy) == "function" then
				task:Destroy()
			elseif typeof(task.Disconnect) == "function" then
				task:Disconnect()
			end
		end
	end
	table.clear(self._cleanupTasks)
end

function Constructor.New(ID: string, Type: Type)
	local SRC = ReplicatedStorage.Shared.Modux.src
	local Network = require(SRC.Network)
	local Promise = require(SRC.Promise)
	local Signal = require(SRC.Signal)
	local GlobalClock = require(script.Parent.GlobalClock)
	local Import = require(script.Parent.Import)
	local Extend = require(script.Parent.Extend)

	local self = setmetatable({}, Constructor)
	self.ID = ID
	self.Type = Type
	self.Import = Import
	self.Extend = Extend
	self.Network = Network
	self.Promise = Promise
	self.Signal = Signal
	self.GlobalClock = GlobalClock
	self.Attributes = {}
	self._onInit = nil
	self._onStart = nil
	self._onSimulation = {}
	self._onDestroy = nil
	self._tag = nil
	self._className = nil
	self._attributeSchema = nil
	self._requiredChildren = nil
	self._cleanupTasks = {}
	return self
end

return Constructor
