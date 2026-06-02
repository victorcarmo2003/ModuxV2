--!strict
local CollectionService = game:GetService("CollectionService")
local Container = require(script.Parent.Parent.Core.Container)
local Composition = require(script.Parent.Parent.Core.Composition)
local Lifecycle = require(script.Parent.Parent.Core.Lifecycle)
local TickScheduler = require(script.Parent.Parent.Core.TickScheduler)
local SimulationScheduler = require(script.Parent.Parent.Core.SimulationScheduler)
local Registry = require(script.Parent.ComponentRegistry)

local ComponentManager = {}
local connections = {}

function ComponentManager.Start()
	for id, registered in Container._all do
		if registered.Type ~= "Component" then
			continue
		end
		local template = registered.Object
		if not template._tag then
			continue
		end

		table.insert(connections, CollectionService:GetInstanceAddedSignal(template._tag):Connect(function(instance)
			ComponentManager.Create(id, instance)
		end))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(template._tag):Connect(function(instance)
			ComponentManager.Destroy(id, instance)
		end))
		for _, instance in CollectionService:GetTagged(template._tag) do
			task.spawn(ComponentManager.Create, id, instance)
		end
	end
end

function ComponentManager.Create(id: string, instance: Instance)
	local registered = Container.Get(id)
	if not registered or registered.Type ~= "Component" then
		return
	end

	local template = registered.Object
	if template._className and not instance:IsA(template._className) then
		return
	end
	for _, childName in template._requiredChildren or {} do
		if not instance:FindFirstChild(childName) then
			return
		end
	end
	if Registry.Get(instance, id) then
		return
	end

	local component = Container.Resolve(nil, id)
	component.Instance = instance
	Registry.Add(instance, id, component)
	Composition.ResolveImports(component)

	if template._attributeSchema then
		component.Attributes = {}
		for attributeName, defaultValue in template._attributeSchema do
			local currentValue = instance:GetAttribute(attributeName)
			component.Attributes[attributeName] = if currentValue ~= nil then currentValue else defaultValue
			component:Cleanup(instance:GetAttributeChangedSignal(attributeName):Connect(function()
				component.Attributes[attributeName] = instance:GetAttribute(attributeName)
			end))
		end
	end

	Lifecycle.Run(component, "_onInit")
	Lifecycle.Run(component, "_onStart")
	for _, tick in component._onTick or {} do
		component:Cleanup(TickScheduler.Register(component, tick))
	end
	for _, simulation in component._onSimulation or {} do
		component:Cleanup(SimulationScheduler.Register(component, simulation))
	end
end

function ComponentManager.Destroy(id: string, instance: Instance)
	local component = Registry.Get(instance, id)
	if not component then
		return
	end
	Lifecycle.Run(component, "_onDestroy")
	if component._doCleanup then
		component:_doCleanup()
	end
	Registry.Remove(instance, id)
end

function ComponentManager.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, entry in Registry.Snapshot() do
		ComponentManager.Destroy(entry.id, entry.instance)
	end
	Registry.Clear()
end

return ComponentManager
