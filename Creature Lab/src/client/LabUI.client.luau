--!strict
-- Creature Lab · player UI, built in code so the prototype needs no manual GUI work.
-- Mobile-first: big buttons bottom-centre, readable counter top-centre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateEvent = remotes:WaitForChild("State") :: RemoteEvent
local NotifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local ActionFn = remotes:WaitForChild("Action") :: RemoteFunction

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LabUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(236, 238, 241)
local PANEL = Color3.fromRGB(17, 20, 24)
local ACCENT = Color3.fromRGB(94, 234, 212)

local function round(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or INK
	l.Text = text
	l.Parent = parent
	return l
end

-- Top: energy counter ------------------------------------------------------
local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 10)
top.Size = UDim2.fromOffset(280, 64)
top.BackgroundColor3 = PANEL
top.BackgroundTransparency = 0.15
top.Parent = gui
round(top, 16)
local energyLabel = label(top, "0", 30, ACCENT)
energyLabel.Size = UDim2.new(1, 0, 0, 38)
energyLabel.Position = UDim2.fromOffset(0, 4)
local rateLabel = label(top, "+0/s", 14)
rateLabel.Font = Enum.Font.GothamMedium
rateLabel.Size = UDim2.new(1, 0, 0, 18)
rateLabel.Position = UDim2.fromOffset(0, 40)

local infoLabel = label(gui, "", 14, Color3.fromRGB(138, 146, 157))
infoLabel.Font = Enum.Font.GothamMedium
infoLabel.AnchorPoint = Vector2.new(0.5, 0)
infoLabel.Position = UDim2.new(0.5, 0, 0, 80)
infoLabel.Size = UDim2.fromOffset(420, 20)

-- Surge banner
local surge = label(gui, "", 22, Color3.fromRGB(252, 211, 77))
surge.AnchorPoint = Vector2.new(0.5, 0)
surge.Position = UDim2.new(0.5, 0, 0, 104)
surge.Size = UDim2.fromOffset(420, 30)
surge.Visible = false

-- Bottom: action buttons ---------------------------------------------------
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.fromOffset(460, 70)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.Parent = bar

local function button(text: string, color: Color3, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 64)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.fromRGB(10, 12, 15)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = bar
	round(b, 14)
	return b
end
local hatchBtn = button("Hatch", ACCENT, 170)
local fuseBtn = button("Fuse all", Color3.fromRGB(196, 181, 253), 130)
local dailyBtn = button("Daily", Color3.fromRGB(252, 211, 77), 130)

-- Left: collection counts --------------------------------------------------
local coll = Instance.new("Frame")
coll.Position = UDim2.fromOffset(12, 140)
coll.Size = UDim2.fromOffset(170, 250)
coll.BackgroundColor3 = PANEL
coll.BackgroundTransparency = 0.2
coll.Parent = gui
round(coll, 12)
local collList = Instance.new("UIListLayout")
collList.Padding = UDim.new(0, 2)
collList.Parent = coll
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 10)
pad.Parent = coll
local tierRows: { TextLabel } = {}
for t, tier in ipairs(Config.Tiers) do
	local row = label(coll, "", 14, tier.color)
	row.Font = Enum.Font.GothamMedium
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Size = UDim2.new(1, -10, 0, 26)
	row.LayoutOrder = t
	tierRows[t] = row
end

-- Home button (top-left)
local homeBtn = Instance.new("TextButton")
homeBtn.Position = UDim2.fromOffset(12, 96)
homeBtn.Size = UDim2.fromOffset(110, 36)
homeBtn.BackgroundColor3 = PANEL
homeBtn.TextColor3 = INK
homeBtn.Font = Enum.Font.GothamMedium
homeBtn.TextSize = 14
homeBtn.Text = "My lab"
homeBtn.Parent = gui
round(homeBtn, 10)

-- Toasts --------------------------------------------------------------------
local toast = label(gui, "", 18)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -96)
toast.Size = UDim2.fromOffset(460, 40)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.1
toast.Visible = false
round(toast, 12)
local toastToken = 0
local function showToast(text: string)
	if text == "" then
		return
	end
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	toast.TextTransparency = 0
	task.delay(2.6, function()
		if my == toastToken then
			toast.Visible = false
		end
	end)
end

-- Tutorial hint for the first minute (the first 60 s decide whether players stay)
local hint = label(gui, "Tap HATCH to get your next creature, then FUSE two of the same kind!", 16, Color3.fromRGB(252, 211, 77))
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -140)
hint.Size = UDim2.fromOffset(560, 24)
TweenService:Create(hint, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.5 }):Play()

-- State ---------------------------------------------------------------------
local state: any = nil
local shownEnergy = 0

StateEvent.OnClientEvent:Connect(function(s)
	state = s
	hatchBtn.Text = ("Hatch  %s"):format(Config.short(s.hatchCost))
	hatchBtn.BackgroundTransparency = s.energy >= s.hatchCost and 0 or 0.45
	rateLabel.Text = ("+%s Energy/s  ·  %d/%d pads"):format(Config.short(s.rate), math.min(s.total, s.pads), s.pads)
	infoLabel.Text = ("Featured this week: %s (+25%%)"):format(s.featured)
	dailyBtn.Text = s.dailyReady and "Daily!" or ("Streak " .. s.dailyStreak)
	dailyBtn.BackgroundTransparency = s.dailyReady and 0 or 0.45
	for t, row in ipairs(tierRows) do
		local n = s.counts[t] or 0
		row.Text = ("%s  ×%d"):format(Config.Tiers[t].name, n)
		row.TextTransparency = n > 0 and 0 or 0.6
	end
	hint.Visible = not s.tutorialDone
end)

-- Smooth counter + surge countdown
task.spawn(function()
	while true do
		task.wait(0.05)
		if state then
			shownEnergy += (state.energy - shownEnergy) * 0.25
			energyLabel.Text = Config.short(shownEnergy) .. " Energy"
			-- os.time() is UTC on both client and server, so the countdown lines up
			if os.time() < state.surgeEndsAt then
				surge.Visible = true
				surge.Text = ("LAB SURGE  2x  ·  %ds"):format(state.surgeEndsAt - os.time())
			else
				surge.Visible = false
			end
		end
	end
end)

NotifyEvent.OnClientEvent:Connect(function(text: string)
	showToast(text)
end)

local function act(name: string)
	local ok, msg = ActionFn:InvokeServer(name)
	if msg and msg ~= "" then
		showToast(msg)
	end
	return ok
end
hatchBtn.Activated:Connect(function()
	act("hatch")
end)
fuseBtn.Activated:Connect(function()
	act("fuse")
end)
dailyBtn.Activated:Connect(function()
	act("daily")
end)
homeBtn.Activated:Connect(function()
	act("home")
end)

-- Shop shortcut (only shows once real pass ids are set in Config)
if Config.GamePasses.DoubleEnergy ~= 0 then
	local shop = button("2x", Color3.fromRGB(253, 186, 116), 70)
	shop.Activated:Connect(function()
		MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.DoubleEnergy)
	end)
end
