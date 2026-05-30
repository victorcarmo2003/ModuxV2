--!strict
local RunService = game:GetService("RunService")
local Conteiner = require(script.Parent.Core.Conteiner)
local Promise = require(script.Parent.Promise)
local ComponentManager = require(script.Parent.Components.ComponentManager)

local Loader = {}
local isLoaded = false
local connections = {}

export type directories = { { [number]: { [number]: ModuleScript } } & Folder }

local function requireAllIn(directories: directories)
	for _, dir in directories do
		for _, desc in dir:GetDescendants() do
			if desc:IsA("ModuleScript") then
				local success, result = pcall(require, desc)
				if not success then
					local modulePath = desc:GetFullName()
					error(`\n[Modux Loader Error] {modulePath}\n Error: {result}`, 0)
				end
			end
		end
	end
end

local function safeResume(thread: thread)
	if coroutine.status(thread) == "suspended" then
		task.spawn(thread)
	end
end

local function runPhase(phaseName: string, singletons: { any }, predicate: (obj: any) -> boolean, fn: (obj: any) -> any)
	local mainThread = coroutine.running()
	local pending = 0

	for _, obj in singletons do
		if predicate(obj) then
			pending += 1
			task.spawn(function()
				local start = os.clock()
				local result = fn(obj)

				if Promise.is(result) then
					result:await()
				end

				local duration = os.clock() - start
				if duration > 0.05 then
					print(`[Modux Profiler] {obj.ID}:{phaseName} took {string.format("%.4f", duration)}s`)
				end

				pending -= 1
				if pending == 0 then
					safeResume(mainThread)
				end
			end)
		end
	end

	if pending > 0 then
		coroutine.yield()
	end
end

-- Resolve all lazy imports declared via :Import() at the top of each module.
-- Runs after requireAllIn + Seal(), so every module is already registered.
local function resolveImports(singletons: { any })
	for _, obj in singletons do
		if obj._imports then
			for _, dep in obj._imports do
				local resolved = Conteiner.Resolve(obj, dep.id, dep.scopeKey)
				obj[dep.id] = resolved
			end
		end
	end
end

local function resolveExtend(singletons: { any })
	for _, obj in singletons do
		if obj._extend then
			local resolved = Conteiner.Resolve(obj, obj._extend)
			setmetatable(obj, { __index = resolved })
		end
	end
end

function Loader.Load(directories: directories)
	if isLoaded then
		return
	end
	isLoaded = true

	-- 1. Require all modules (Import() calls only queue dependencies here)
	requireAllIn(directories)
	Conteiner.Seal()

	-- Collect all singletons
	local singletons = {}
	for _, reg in Conteiner._all do
		if reg.ScopeType == "Singleton" then
			table.insert(singletons, reg.Object)
		end
	end

	-- 2. Resolve lazy imports agora que todos os módulos estão registrados
	resolveImports(singletons)
	resolveExtend(singletons)

	-- 3. Execute OnInit (parallel, wait for all)
	runPhase("OnInit", singletons, function(obj)
		return obj._onInit ~= nil
	end, function(obj)
		return obj._onInit(obj)
	end)

	-- 4. Execute OnStart (parallel, wait for all)
	runPhase("OnStart", singletons, function(obj)
		return obj._onStart ~= nil
	end, function(obj)
		return obj._onStart(obj)
	end)

	-- 5. Connect OnSimulation
	for _, obj in singletons do
		if obj._onSimulation then
			for _, sim in obj._onSimulation do
				local conn = RunService.Heartbeat:Connect(function(dt)
					sim.Callback(obj, dt)
				end)
				table.insert(connections, conn)
			end
		end
	end
	-- 6. Iniciar Sistema de Componentes
	ComponentManager.Start()
end

return Loader
