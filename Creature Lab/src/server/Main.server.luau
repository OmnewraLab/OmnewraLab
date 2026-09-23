--!strict
-- Creature Lab · main game loop (server-authoritative)
-- Loop: creatures on pads make Energy -> spend Energy to hatch more -> fuse pairs into higher tiers -> repeat.
-- Return hooks: offline income, daily streak, weekly featured species, Lab Surge every 15 min, boosting friends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabWorld = require(script.Parent:WaitForChild("LabWorld"))

-- Remotes -------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(className: string, name: string): Instance
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local StateEvent = remote("RemoteEvent", "State") :: RemoteEvent       -- server -> client snapshot
local NotifyEvent = remote("RemoteEvent", "Notify") :: RemoteEvent     -- server -> client toast
local ActionFn = remote("RemoteFunction", "Action") :: RemoteFunction  -- client -> server requests

LabWorld.build()

-- Session state --------------------------------------------------------
local owns: { [Player]: { DoubleEnergy: boolean, BiggerLab: boolean, VIPGlow: boolean } } = {}
local lastAction: { [Player]: number } = {}
local boostCooldown: { [string]: number } = {} -- "visitorId:ownerId" -> os.time when allowed again
local surgeEndsAt = 0
local nextSurgeAt = os.time() + Config.SURGE_INTERVAL

local function ownsPass(player: Player, id: number): boolean
	if id == 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and result == true
end

local function padCount(player: Player): number
	local o = owns[player]
	return Config.BASE_PADS + ((o and o.BiggerLab) and Config.PADS_PASS_BONUS or 0)
end

-- Highest-tier creatures fill the pads first.
local function activeCreatures(player: Player, data: DataService.Data): { DataService.Creature }
	local sorted = table.clone(data.creatures)
	table.sort(sorted, function(a, b)
		return a.tier > b.tier
	end)
	local active = {}
	for i = 1, math.min(padCount(player), #sorted) do
		active[i] = sorted[i]
	end
	return active
end

local function ratePerSecond(player: Player, data: DataService.Data): number
	local featured = Config.featuredSpecies(os.time())
	local rate = 0
	for _, c in ipairs(activeCreatures(player, data)) do
		local r = Config.Tiers[c.tier].rate
		if c.species == featured then
			r *= Config.FEATURED_BONUS
		end
		rate += r
	end
	local o = owns[player]
	if o and o.DoubleEnergy then
		rate *= 2
	end
	if os.time() < surgeEndsAt then
		rate *= Config.SURGE_MULT
	end
	return rate
end

local function dayIndex(t: number): number
	return math.floor(t / 86400)
end

local function snapshot(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local counts = {}
	for t = 1, Config.MAX_TIER do
		counts[t] = 0
	end
	for _, c in ipairs(data.creatures) do
		counts[c.tier] += 1
	end
	local today = dayIndex(os.time())
	StateEvent:FireClient(player, {
		energy = data.energy,
		rate = ratePerSecond(player, data),
		hatchCost = Config.hatchCost(data.hatches),
		counts = counts,
		total = #data.creatures,
		pads = padCount(player),
		featured = Config.featuredSpecies(os.time()),
		surgeEndsAt = surgeEndsAt,
		nextSurgeAt = nextSurgeAt,
		dailyReady = data.dailyDay < today,
		dailyStreak = data.dailyStreak,
		tutorialDone = data.tutorialDone,
		serverTime = os.time(),
	})
end

local function rerender(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local o = owns[player]
	LabWorld.render(player, activeCreatures(player, data), (o ~= nil) and o.VIPGlow)
	snapshot(player)
end

local function leaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local power = Instance.new("NumberValue")
	power.Name = "Lab Power"
	power.Parent = ls
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Value = "Spark"
	best.Parent = ls
	ls.Parent = player
end

local function updateLeaderstats(player: Player, data: DataService.Data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	(ls:FindFirstChild("Lab Power") :: NumberValue).Value = math.floor(ratePerSecond(player, data))
	local top = 1
	for _, c in ipairs(data.creatures) do
		top = math.max(top, c.tier)
	end
	(ls:FindFirstChild("Best") :: StringValue).Value = Config.Tiers[top].name
end

-- Actions ----------------------------------------------------------------
local function hatch(player: Player, data: DataService.Data): (boolean, string)
	local cost = Config.hatchCost(data.hatches)
	if data.energy < cost then
		return false, ("Need %s Energy"):format(Config.short(cost - data.energy))
	end
	data.energy -= cost
	data.hatches += 1
	local tier = 1
	if math.random() < Config.HATCH_LUCKY_CHANCE then
		tier = 2
	end
	local species = Config.Species[math.random(1, #Config.Species)]
	table.insert(data.creatures, { id = data.nextId, tier = tier, species = species })
	data.nextId += 1
	data.tutorialDone = data.tutorialDone or data.hatches >= 3
	return true, (tier > 1 and "Lucky! " or "Hatched ") .. Config.Tiers[tier].name .. " " .. species
end

-- Fuse every matching pair, lowest tiers first, so one tap feels big.
local function fuseAll(data: DataService.Data): (boolean, string)
	local fused = 0
	local bestTier = 0
	for tier = 1, Config.MAX_TIER - 1 do
		local pool = {}
		for i, c in ipairs(data.creatures) do
			if c.tier == tier then
				table.insert(pool, i)
			end
		end
		local pairsCount = math.floor(#pool / 2)
		if pairsCount > 0 then
			local remove = {}
			for p = 1, pairsCount do
				local keep = data.creatures[pool[p * 2 - 1]]
				keep.tier = tier + 1
				remove[pool[p * 2]] = true
				fused += 1
				bestTier = math.max(bestTier, tier + 1)
			end
			local kept = {}
			for i, c in ipairs(data.creatures) do
				if not remove[i] then
					table.insert(kept, c)
				end
			end
			data.creatures = kept
		end
	end
	if fused == 0 then
		return false, "Need two creatures of the same tier to fuse"
	end
	return true, ("Fused %d! Best: %s"):format(fused, Config.Tiers[bestTier].name)
end

local function claimDaily(data: DataService.Data): (boolean, string)
	local today = dayIndex(os.time())
	if data.dailyDay >= today then
		return false, "Come back tomorrow for your next reward"
	end
	if data.dailyDay == today - 1 then
		data.dailyStreak += 1
	else
		data.dailyStreak = 1
	end
	data.dailyDay = today
	local reward = Config.DAILY_REWARDS[((data.dailyStreak - 1) % #Config.DAILY_REWARDS) + 1]
	data.energy += reward
	return true, ("Day %d streak: +%s Energy"):format(data.dailyStreak, Config.short(reward))
end

ActionFn.OnServerInvoke = function(player: Player, action: any)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.25 then
		return false, "Slow down"
	end
	lastAction[player] = now
	local data = DataService.get(player)
	if not data or type(action) ~= "string" then
		return false, "Not ready"
	end
	local ok, msg
	if action == "hatch" then
		ok, msg = hatch(player, data)
	elseif action == "fuse" then
		ok, msg = fuseAll(data)
	elseif action == "daily" then
		ok, msg = claimDaily(data)
	elseif action == "home" then
		LabWorld.teleportHome(player)
		return true, ""
	else
		return false, "Unknown action"
	end
	if ok then
		rerender(player)
		updateLeaderstats(player, data)
	end
	return ok, msg
end

-- Visitors boost each other's labs (both get income)
for _, prompt in ipairs(LabWorld.prompts()) do
	prompt.Triggered:Connect(function(visitor: Player)
		local owner = LabWorld.ownerOfPrompt(prompt)
		if not owner or owner == visitor then
			NotifyEvent:FireClient(visitor, "Visit a friend's lab to boost it")
			return
		end
		local key = visitor.UserId .. ":" .. owner.UserId
		if (boostCooldown[key] or 0) > os.time() then
			NotifyEvent:FireClient(visitor, "You boosted this lab recently")
			return
		end
		boostCooldown[key] = os.time() + Config.BOOST_COOLDOWN
		for _, p in ipairs({ visitor, owner }) do
			local d = DataService.get(p)
			if d then
				local gain = ratePerSecond(p, d) * Config.BOOST_SECONDS
				d.energy += gain
				d.totalEarned += gain
				NotifyEvent:FireClient(p, ("Lab boost! +%s Energy"):format(Config.short(gain)))
				snapshot(p)
			end
		end
	end)
end

-- Purchases --------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased or not owns[player] then
		return
	end
	for name, id in pairs(Config.GamePasses) do
		if id == passId then
			(owns[player] :: any)[name] = true
		end
	end
	rerender(player)
end)

MarketplaceService.ProcessReceipt = function(receipt: any)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if receipt.ProductId == Config.Products.EnergyHour then
		local gain = ratePerSecond(player, data) * 3600
		data.energy += gain
		data.totalEarned += gain
		NotifyEvent:FireClient(player, ("+%s Energy"):format(Config.short(gain)))
	end
	table.insert(data.receipts, receipt.PurchaseId)
	if #data.receipts > 50 then
		table.remove(data.receipts, 1)
	end
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Players ------------------------------------------------------------------
local function onJoin(player: Player)
	local data = DataService.load(player)
	owns[player] = {
		DoubleEnergy = ownsPass(player, Config.GamePasses.DoubleEnergy),
		BiggerLab = ownsPass(player, Config.GamePasses.BiggerLab),
		VIPGlow = ownsPass(player, Config.GamePasses.VIPGlow),
	}
	leaderstats(player)
	if not LabWorld.claim(player) then
		NotifyEvent:FireClient(player, "This server's labs are full")
	end

	-- offline income: a reason to come back
	local away = math.clamp(os.time() - data.lastSeen, 0, Config.OFFLINE_CAP_SECONDS)
	if away > 60 then
		local gain = ratePerSecond(player, data) * away * Config.OFFLINE_RATE
		if gain >= 1 then
			data.energy += gain
			data.totalEarned += gain
			task.delay(3, function()
				NotifyEvent:FireClient(player, ("While you were away your lab made %s Energy"):format(Config.short(gain)))
			end)
		end
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		LabWorld.teleportHome(player)
	end)
	if player.Character then
		LabWorld.teleportHome(player)
	end
	rerender(player)
	updateLeaderstats(player, data)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.release(player)
	LabWorld.release(player)
	owns[player] = nil
	lastAction[player] = nil
end)

game:BindToClose(function()
	for player in pairs(DataService.all()) do
		DataService.save(player)
	end
end)

-- Income tick (1 s), surge scheduler and autosave --------------------------
task.spawn(function()
	local saveTimer = 0
	while true do
		task.wait(1)
		local now = os.time()
		if now >= nextSurgeAt then
			surgeEndsAt = now + Config.SURGE_DURATION
			nextSurgeAt = now + Config.SURGE_INTERVAL
			for _, p in ipairs(Players:GetPlayers()) do
				NotifyEvent:FireClient(p, "LAB SURGE! 2x Energy for 60 seconds")
			end
		end
		for player, data in pairs(DataService.all()) do
			local gain = ratePerSecond(player, data)
			data.energy += gain
			data.totalEarned += gain
			snapshot(player)
		end
		saveTimer += 1
		if saveTimer >= 60 then
			saveTimer = 0
			for player in pairs(DataService.all()) do
				task.spawn(DataService.save, player)
			end
		end
	end
end)
