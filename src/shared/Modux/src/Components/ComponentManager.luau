--!strict
local CollectionService = game:GetService("CollectionService")
local Conteiner = require(script.Parent.Parent.Core.Conteiner)
local Registry = require(script.Parent.ComponentRegistry)

local ComponentManager = {}

function ComponentManager.Start()
	for id, reg in Conteiner._all do
		if reg.Type == "Component" then
			local template = reg.Object
			if template._tag then
				-- Escutar novas instâncias
				CollectionService:GetInstanceAddedSignal(template._tag):Connect(function(instance)
					ComponentManager.Create(id, instance)
				end)

				-- Escutar remoções
				CollectionService:GetInstanceRemovedSignal(template._tag):Connect(function(instance)
					ComponentManager.Destroy(id, instance)
				end)

				-- Instanciar o que já existe no mapa
				for _, instance in CollectionService:GetTagged(template._tag) do
					task.spawn(ComponentManager.Create, id, instance)
				end
			end
		end
	end
end

function ComponentManager.Create(id: string, instance: Instance)
	local reg = Conteiner._all[id]
	if not reg then
		return
	end

	local template = reg.Object

	-- 1. Validar ClassName se especificado
	if template._className and not instance:IsA(template._className) then
		return
	end

	-- 2. Validar Filhos Obrigatórios
	if template._requiredChildren then
		for _, childName in template._requiredChildren do
			if not instance:FindFirstChild(childName) then
				return
			end
		end
	end

	-- Evitar duplicatas para a mesma instância e mesmo ID
	if Registry.Get(instance, id) then
		return
	end

	-- Criar uma nova instância clonada do Template
	local component = Conteiner.Resolve(nil, id)
	component.Instance = instance

	Registry.Add(instance, id, component)

	-- 3. Resolver Imports e Extends
	if component._imports then
		for _, dep in component._imports do
			component[dep.id] = Conteiner.Resolve(component, dep.id, dep.scopeKey)
		end
	end

	if component._extend then
		local resolved = Conteiner.Resolve(component, component._extend)
		setmetatable(component, { __index = resolved })
	end

	-- 4. Sincronizar Atributos
	if template._attributeSchema then
		component.Attributes = {}
		for attrName, defaultValue in template._attributeSchema do
			local currentVal = instance:GetAttribute(attrName)
			component.Attributes[attrName] = if currentVal ~= nil then currentVal else defaultValue

			-- Auto-update quando o atributo mudar no Studio/Script
			component:Cleanup(instance:GetAttributeChangedSignal(attrName):Connect(function()
				component.Attributes[attrName] = instance:GetAttribute(attrName)
			end))
		end
	end

	-- 5. Rodar Lifecycle
	if component._onInit then
		component._onInit(component)
	end

	if component._onStart then
		component._onStart(component)
	end
end

function ComponentManager.Destroy(id: string, instance: Instance)
	local component = Registry.Get(instance, id)
	if component then
		-- Primeiro roda o OnDestroy do usuário
		if component._onDestroy then
			component._onDestroy(component)
		end

		-- Depois limpa tudo que foi registrado no :Cleanup()
		if component._doCleanup then
			component:_doCleanup()
		end

		Registry.Remove(instance, id)
	end
end

return ComponentManager
