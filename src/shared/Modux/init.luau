local ScriptChangeService = game:GetService("ScriptChangeService")
local Constructor = require(script.src.Core.Constructor)
local Conteiner = require(script.src.Core.Conteiner)
local Import = require(script.src.Core.Import)
local Types = require(script.Types)
local Loader = require(script.src.Loader)

export type Mode = "Singleton" | "Transient"
export type Type = "Service" | "Controller" | "Component"

export type Modux = {
	Service: Types.ServiceFn,
	Controller: Types.ControllerFn,
	Component: Types.ComponentFn,
	Start: () -> (),
}

local function createClass(ID: string, Mode: Mode, Type: Type): any
	local newClass: any = Constructor.New(ID, Type)
	newClass.Import = Import
	Conteiner.Register(ID, newClass, Mode, Type)
	return newClass
end

local Service: any = function(ID: string, Mode: Mode?): any
	Mode = Mode or "Singleton"
	local newService = createClass(ID, Mode :: Mode, "Service")
	return newService
end

local Controller: any = function(ID: string, Mode: Mode?): any
	Mode = Mode or "Singleton"
	local newController = createClass(ID, Mode :: Mode, "Controller")
	return newController
end

local Component: any = function(ID: string, Mode: Mode?): any
	Mode = Mode or "Transient"
	local newComponent = createClass(ID, Mode :: Mode, "Component")
	return newComponent
end

local function Start()
	local directories = {} :: Loader.directories
	local Shared = game.ReplicatedStorage.Shared :: Folder & { ModuleScript }

	table.insert(directories, Shared)

	if game:GetService("RunService"):IsServer() then
		local Server = game.ServerScriptService:WaitForChild("Server") :: Folder & { ModuleScript }
		table.insert(directories, Server)
	else
		local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
		local Client = PlayerScripts:WaitForChild("Client") :: Folder & { ModuleScript }
		table.insert(directories, Client)
	end

	print(`[Modux] Started!`)
	print(directories)
	Loader.Load(directories)
	print(`[Modux] Loaded`)
end

local Modux: Modux = {
	Service = Service,
	Controller = Controller,
	Component = Component,
	Start = Start,
}

return Modux
