--!strict
-- Creature Lab · builds the world in code (no manual map work needed for the prototype):
-- a ring of lab plots around the spawn, each with glowing pads that show the owner's creatures.
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local LabWorld = {}

local PLOT_COUNT = 8
local RING_RADIUS = 70
local PAD_SPACING = 7

type Plot = { model: Model, base: BasePart, sign: TextLabel, pads: { BasePart }, owner: Player? }
local plots: { Plot } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

function LabWorld.build()
	local folder = Instance.new("Folder")
	folder.Name = "Labs"
	folder.Parent = workspace

	-- central hub + spawn
	part({ Name = "Hub", Size = Vector3.new(40, 1, 40), Position = Vector3.new(0, 0, 0), Color = Color3.fromRGB(28, 33, 39), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = Vector3.new(0, 10, 0), Color = Color3.fromRGB(94, 234, 212), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 3
	light.Color = core.Color
	light.Parent = core
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1, 12)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local center = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
		local model = Instance.new("Model")
		model.Name = "Lab" .. i
		model.Parent = folder

		local base = part({ Name = "Base", Size = Vector3.new(30, 1, 30), Color = Color3.fromRGB(22, 26, 31), Material = Enum.Material.SmoothPlastic, Parent = model })
		base.CFrame = CFrame.lookAt(center, Vector3.zero) -- face the hub
		-- walkway to the hub
		local mid = center * 0.62
		local path = part({ Name = "Path", Size = Vector3.new(6, 0.6, RING_RADIUS - 35), Color = Color3.fromRGB(40, 46, 54), Material = Enum.Material.SmoothPlastic, Parent = model })
		path.CFrame = CFrame.lookAt(mid, Vector3.zero)

		-- owner sign
		local post = part({ Name = "Sign", Size = Vector3.new(10, 5, 0.6), Color = Color3.fromRGB(17, 20, 24), Parent = model })
		post.CFrame = base.CFrame * CFrame.new(0, 3.5, -13)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.Parent = post
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(236, 238, 241)
		label.Text = "Empty lab"
		label.Parent = gui

		-- creature pads in a 3 x 3 grid (up to 9 with the Bigger Lab pass)
		local pads = {}
		for r = 0, 2 do
			for c = 0, 2 do
				local pad = part({ Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), Color = Color3.fromRGB(40, 46, 54), Material = Enum.Material.Metal, Parent = model })
				pad.CFrame = base.CFrame * CFrame.new((c - 1) * PAD_SPACING, 0.7, (r - 1) * PAD_SPACING + 2) * CFrame.Angles(0, 0, math.rad(90))
				table.insert(pads, pad)
			end
		end

		-- boost prompt (visitors help each other)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Boost this lab"
		prompt.ObjectText = "Visitor boost"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 14
		prompt.Parent = post

		table.insert(plots, { model = model, base = base, sign = label, pads = pads, owner = nil })
	end
end

function LabWorld.claim(player: Player): number?
	for i, p in ipairs(plots) do
		if p.owner == nil then
			p.owner = player
			p.sign.Text = player.DisplayName .. "'s Lab"
			return i
		end
	end
	return nil
end

function LabWorld.release(player: Player)
	for _, p in ipairs(plots) do
		if p.owner == player then
			p.owner = nil
			p.sign.Text = "Empty lab"
			for _, pad in ipairs(p.pads) do
				local old = pad:FindFirstChild("Creature")
				if old then
					old:Destroy()
				end
			end
		end
	end
end

function LabWorld.plotOf(player: Player): Plot?
	for _, p in ipairs(plots) do
		if p.owner == player then
			return p
		end
	end
	return nil
end

function LabWorld.ownerOfPrompt(prompt: ProximityPrompt): Player?
	for _, p in ipairs(plots) do
		if prompt:IsDescendantOf(p.model) then
			return p.owner
		end
	end
	return nil
end

function LabWorld.prompts(): { ProximityPrompt }
	local list = {}
	for _, p in ipairs(plots) do
		local pr = p.model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if pr then
			table.insert(list, pr :: ProximityPrompt)
		end
	end
	return list
end

-- Show the active creatures as glowing, bobbing orbs above the pads.
function LabWorld.render(player: Player, active: { { tier: number, species: string } }, vipGlow: boolean)
	local p = LabWorld.plotOf(player)
	if not p then
		return
	end
	for i, pad in ipairs(p.pads) do
		local old = pad:FindFirstChild("Creature")
		if old then
			old:Destroy()
		end
		local c = active[i]
		if c then
			local tier = Config.Tiers[c.tier]
			local orb = part({ Name = "Creature", Shape = Enum.PartType.Ball, Size = Vector3.one * tier.size, Color = tier.color, Material = Enum.Material.Neon, CanCollide = false })
			orb.CFrame = CFrame.new(pad.Position + Vector3.new(0, 2.2 + tier.size / 2, 0))
			orb.Parent = pad
			local glow = Instance.new("PointLight")
			glow.Color = tier.color
			glow.Range = 6 + c.tier
			glow.Parent = orb
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(120, 30)
			tag.StudsOffset = Vector3.new(0, tier.size / 2 + 1, 0)
			tag.AlwaysOnTop = false
			tag.MaxDistance = 40
			tag.Parent = orb
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamMedium
			t.TextScaled = true
			t.TextColor3 = tier.color
			t.Text = tier.name .. " " .. c.species
			t.Parent = tag
			-- gentle bob so the lab feels alive
			TweenService:Create(orb, TweenInfo.new(1.6 + (i % 3) * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = orb.CFrame + Vector3.new(0, 0.8, 0) }):Play()
		end
	end
	p.sign.TextColor3 = vipGlow and Color3.fromHSV((os.clock() * 0.1) % 1, 0.5, 1) or Color3.fromRGB(236, 238, 241)
end

function LabWorld.teleportHome(player: Player)
	local p = LabWorld.plotOf(player)
	local char = player.Character
	if p and char and char:FindFirstChild("HumanoidRootPart") then
		(char :: Model):PivotTo(p.base.CFrame * CFrame.new(0, 4, 10))
	end
end

return LabWorld
