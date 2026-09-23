--!strict
-- Creature Lab · player data: load, cache, autosave. DataStore calls are wrapped in pcall.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local STORE_NAME = "CreatureLab_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

export type Creature = { id: number, tier: number, species: string }
export type Data = {
	energy: number,
	totalEarned: number,
	hatches: number,
	creatures: { Creature },
	nextId: number,
	lastSeen: number,
	dailyDay: number,   -- day index of last claim
	dailyStreak: number,
	receipts: { string }, -- recent processed purchase ids (idempotency)
	tutorialDone: boolean,
}

local DataService = {}
local cache: { [Player]: Data } = {}
local loadedOk: { [Player]: boolean } = {}

local function default(): Data
	return {
		energy = Config.START_ENERGY,
		totalEarned = 0,
		hatches = 0,
		creatures = { { id = 1, tier = 1, species = Config.Species[1] } }, -- start with one producing creature
		nextId = 2,
		lastSeen = os.time(),
		dailyDay = 0,
		dailyStreak = 0,
		receipts = {},
		tutorialDone = false,
	}
end

-- Fill in any fields added in later versions so old saves keep working.
local function reconcile(saved: any): Data
	local d = default()
	if type(saved) ~= "table" then
		return d
	end
	for k, v in pairs(saved) do
		(d :: any)[k] = v
	end
	return d
end

function DataService.load(player: Player): Data
	local key = "u_" .. player.UserId
	local data: Data? = nil
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			data = reconcile(result)
			loadedOk[player] = true
			break
		end
		warn(("[Data] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end
	if not data then
		-- Never overwrite a real save with defaults: play on, but don't save this session.
		data = default()
		loadedOk[player] = false
	end
	cache[player] = data :: Data
	return data :: Data
end

function DataService.get(player: Player): Data?
	return cache[player]
end

function DataService.save(player: Player)
	local data = cache[player]
	if not data or not loadedOk[player] then
		return
	end
	-- In Studio, saving needs Game Settings > Security > "Enable Studio Access to API Services".
	if RunService:IsStudio() and not game:GetService("ServerStorage"):GetAttribute("AllowStudioSaves") then
		return
	end
	data.lastSeen = os.time()
	local key = "u_" .. player.UserId
	local ok, err = pcall(function()
		store:UpdateAsync(key, function()
			return data
		end)
	end)
	if not ok then
		warn(("[Data] save failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	cache[player] = nil
	loadedOk[player] = nil
end

function DataService.all(): { [Player]: Data }
	return cache
end

return DataService
