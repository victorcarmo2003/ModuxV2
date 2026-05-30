--!strict
local AnimalDatabase = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type AnimalElements =
	"Water"
	| "Fire"
	| "Wind"
	| "Earth"
	| "Nature"
	| "Light"
	| "Shadow"
	| "Tech"
	| "Psychic"
	| "Fighter"
	| "Plant"
	| "Love"
	| "Sand"

export type Stats = {
	HP: number,
	Attack: number,
	Defense: number,
	Special: number,
	Speed: number,
	Energy: number,
	Level: number,
	Exp: number,
}

export type MoveLearn = {
	Level: number,
	MoveId: string,
}

export type Requirements = {
	Level: number,
}

export type Evolution = {
	Level: number?,
	To: string,
	Requirements: Requirements,
}

export type AnimalType = {
	Id: string,
	DisplayName: string,
	Description: string,
	Rarity: string,
	Elements: {},
	BaseStats: {
		HP: number,
		Attack: number,
		Defense: number,
		Special: number,
		Speed: number,
		Energy: number,
		Level: number,
		Exp: number,
	},
	Growth: {
		HP: number,
		Attack: number,
		Defense: number,
		Special: number,
		Speed: number,
		Energy: number,
		Level: number,
		Exp: number,
	},
	CaptureRate: number,
	EssenceYield: number,
	MoveSet: {
		Level: number,
		MoveId: string,
	},
	Level: number,
	MoveId: string,
}

local Stage1 = require(script.Stage1)
local Stage2 = require(script.Stage2)
local Stage3 = require(script.Stage3)

local Animals = {
	STAGE_1 = Stage1.STAGE_1,
	STAGE_2 = Stage2.STAGE_2,
	STAGE_3 = Stage3.STAGE_3,
}

local RarityWeights: { [Rarity]: number } = {
	Common = 60,
	Uncommon = 28,
	Rare = 10,
	Epic = 4,
	Legendary = 1,
	Mythic = 0.25,
	Secret = 0.05,
}

function AnimalDatabase.Get(id: string): AnimalType?
	for stage, animalList in pairs(Animals) do
		for name, Animal in animalList do
			if name == id then
				return Animal
			end
		end
	end
	warn(`[AnimalDatabase] Animal not founded in database {id}`)
	return nil
end

function AnimalDatabase.GetAll(): { [string]: AnimalType }
	local allList = {}
	for stage, animalList in Animals do
		print(stage, animalList)
		for name, Animal in animalList do
			print(name, Animal)
			allList[name] = Animal
		end
	end
	print(allList)
	return allList
end

function AnimalDatabase.IsValid(id: string): boolean
	for stage, animalList in Animals do
		for name, Animal in animalList do
			if Animal.Id == id then
				return true
			end
		end
	end
	return false
end

function AnimalDatabase.GetByRarity(rarity: Rarity): { AnimalType }
	local results = {}
	for stage, animalList in Animals do
		for name, Animal in animalList do
			if Animal.Rarity == rarity then
				table.insert(results, Animal)
			end
		end
	end
	return results
end

function AnimalDatabase.GetByElement(Element: AnimalElements | { Elements: { AnimalElements } }): { AnimalType }
	local searchElements: { [AnimalElements]: boolean } = {}
	if typeof(Element) == "string" then
		searchElements[Element] = true
	elseif typeof(Element) == "table" and Element.Elements then
		for _, elem in Element.Elements do
			searchElements[elem] = true
		end
	end

	local results = {}
	for stage, animalList in Animals do
		for name, Animal in animalList do
			for _, animalElem in Animal.Elements do
				if searchElements[animalElem] then
					table.insert(results, Animal)
					break
				end
			end
		end
	end
	return results
end

function AnimalDatabase.GetRarityWeight(rarity: Rarity): number
	return RarityWeights[rarity] or 0
end

function AnimalDatabase.GetEncounterPool(allowedRarities: { Rarity }?): { AnimalType }
	local allowed = {}
	local pool = {}

	if allowedRarities then
		for _, rarity in allowedRarities do
			allowed[rarity] = true
		end
	end

	for stage, animalList in Animals do
		for name, Animal in animalList do
			if not allowedRarities or allowed[Animal.Rarity] then
				table.insert(pool, Animal)
			end
		end
	end

	return pool
end

return AnimalDatabase
