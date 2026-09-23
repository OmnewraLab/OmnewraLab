--!strict
-- Creature Lab · shared tuning values (read by server and client)
-- Change numbers here to rebalance the game; no other file needs editing.

local Config = {}

-- Economy -------------------------------------------------------------
Config.START_ENERGY = 30
Config.HATCH_COST_BASE = 25          -- first hatch costs this much Energy
Config.HATCH_COST_GROWTH = 1.12      -- each hatch costs 12% more than the last
Config.HATCH_LUCKY_CHANCE = 0.08     -- free random bonus: 8% chance to hatch one tier higher (free, so no odds rule applies, but we still show it)

Config.BASE_PADS = 6                 -- creatures that generate Energy at once
Config.PADS_PASS_BONUS = 3           -- extra pads from the "Bigger Lab" game pass
Config.MAX_TIER = 8

-- Offline progress (reason to come back)
Config.OFFLINE_CAP_SECONDS = 8 * 3600  -- earn for up to 8 hours away
Config.OFFLINE_RATE = 0.5              -- at half speed

-- Lab Surge: a server-wide 2x event every 15 minutes (a moment worth clipping)
Config.SURGE_INTERVAL = 15 * 60
Config.SURGE_DURATION = 60
Config.SURGE_MULT = 2

-- Visiting friends (co-play is a discovery signal)
Config.BOOST_SECONDS = 60            -- a boost gives BOTH players 60s of their own income
Config.BOOST_COOLDOWN = 20 * 60      -- per visitor, per lab

-- Daily streak rewards (day 1..7, then loops)
Config.DAILY_REWARDS = { 50, 120, 250, 400, 650, 1000, 2000 }

-- Featured species of the week gets +25% output (weekly reason to return)
Config.FEATURED_BONUS = 1.25

-- Monetisation (fair, no paid random items) ------------------------------
-- TODO: create these in the Creator Dashboard, then paste the real ids here.
Config.GamePasses = {
	DoubleEnergy = 0, -- 2x Energy forever
	BiggerLab = 0,    -- +3 pads
	VIPGlow = 0,      -- cosmetic rainbow glow on your lab sign
}
Config.Products = {
	EnergyHour = 0,   -- instantly receive 1 hour of your current income
}

-- Creatures ------------------------------------------------------------
export type Tier = { name: string, rate: number, color: Color3, size: number }

Config.Tiers = {
	{ name = "Spark",    rate = 1,    color = Color3.fromRGB(125, 211, 252), size = 1.4 },
	{ name = "Glimmer",  rate = 3,    color = Color3.fromRGB(94, 234, 212),  size = 1.6 },
	{ name = "Pulse",    rate = 8,    color = Color3.fromRGB(190, 242, 100), size = 1.8 },
	{ name = "Flare",    rate = 20,   color = Color3.fromRGB(252, 211, 77),  size = 2.0 },
	{ name = "Nova",     rate = 50,   color = Color3.fromRGB(253, 186, 116), size = 2.2 },
	{ name = "Quasar",   rate = 125,  color = Color3.fromRGB(249, 168, 212), size = 2.4 },
	{ name = "Nebula",   rate = 300,  color = Color3.fromRGB(196, 181, 253), size = 2.7 },
	{ name = "Singular", rate = 750,  color = Color3.fromRGB(255, 255, 255), size = 3.0 },
} :: { Tier }

-- Species are cosmetic families; one is featured each week.
Config.Species = { "Glowbug", "Mothling", "Voltfox", "Jellyfloat", "Embercat", "Frostling", "Moonowl", "Sproutle" }

function Config.hatchCost(hatches: number): number
	return math.floor(Config.HATCH_COST_BASE * Config.HATCH_COST_GROWTH ^ hatches)
end

-- Week number since Unix epoch, used to rotate the featured species for everyone at once.
function Config.featuredSpecies(now: number): string
	local week = math.floor(now / (7 * 24 * 3600))
	return Config.Species[(week % #Config.Species) + 1]
end

-- Short numbers for UI: 1500 -> 1.5K
function Config.short(n: number): string
	local units = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while math.abs(n) >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, units[i])
end

return Config
