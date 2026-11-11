--[[
	EggNodes: OVOS GRÁTIS na estrada (visual 100% no cliente, por jogador).
	Cada Part com tag "RoadEgg" (workspace.Map.EggNodes) vira um ovo gigante girando, com anel e coluna de luz.
	Passou por cima (de carro ou a pé) => EggHatchUI.FromRoad. Depois o ovo some por RoadCooldown s SÓ para você.
	Ovos de biomas acima do tier do seu carro aparecem com cadeado e não são coletados.
	Com StreamingEnabled, ovos distantes entram/saem pelos sinais de tag (só existem perto do jogador).
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local EggVisuals = require(script.Parent.EggVisuals)
local EggHatchUI = require(script.Parent.EggHatchUI)
local Drive = require(script.Parent.DriveController)

local lp = Players.LocalPlayer
local EggNodes = {}
local nodes, fx = {}, nil

local function neon(parent, name, size, cf, color, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = Enum.Material.Neon; p.Transparency = transparency
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function build(part)
	if nodes[part] then return end
	local biomeId = part:GetAttribute("BiomeId")
	local egg = Config.Eggs[biomeId]
	local biome = Config.BiomeById[biomeId]
	if not egg or not biome then return end
	local base = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	local folder = Instance.new("Folder"); folder.Name = part.Name
	neon(folder, "Ring", Vector3.new(0.4, 14, 14), CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), egg.Color, 0.1, Enum.PartType.Cylinder)
	local beam = neon(folder, "Beam", Vector3.new(4, 70, 4), CFrame.new(base + Vector3.new(0, 35, 0)), egg.Color, 0.8)
	local model = EggVisuals.Build(biomeId, 1.3)
	model.Parent = folder

	local bb = Instance.new("BillboardGui")
	bb.Adornee = model.PrimaryPart; bb.Size = UDim2.fromOffset(180, 64); bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0); bb.MaxDistance = 300
	local function lbl(y, h, text, color, size)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, h); l.Position = UDim2.fromOffset(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextSize = size; l.TextColor3 = color; l.Text = text
		local s = Instance.new("UIStroke"); s.Thickness = 3; s.Parent = l
		l.Parent = bb
		return l
	end
	local top = lbl(0, 34, "FREE EGG!", Color3.fromRGB(255, 230, 80), 30)
	lbl(34, 24, egg.Name, egg.Color, 20)
	bb.Parent = model.PrimaryPart

	folder.Parent = fx
	nodes[part] = { Folder = folder, Model = model, Beam = beam, Top = top, Base = base, BiomeTier = biome.Tier,
		Seed = math.random() * 6.28, ReadyAt = 0, Shown = true }
end

-- posição de quem coleta: o carro se estiver dirigindo, senão o corpo
local function subjectPos()
	if Drive.IsDriving() then return Drive.GetPosition() end
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

function EggNodes.Init()
	fx = Instance.new("Folder"); fx.Name = "ClientEggs"; fx.Parent = workspace
	CollectionService:GetInstanceAddedSignal("RoadEgg"):Connect(build)
	CollectionService:GetInstanceRemovedSignal("RoadEgg"):Connect(function(part)
		local n = nodes[part]
		if n then n.Folder:Destroy(); nodes[part] = nil end
	end)
	for _, p in ipairs(CollectionService:GetTagged("RoadEgg")) do build(p) end

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local pos = subjectPos()
		local tier = lp:GetAttribute("CarTier") or 1
		local triggered = false
		for part, n in pairs(nodes) do
			local ready = t >= n.ReadyAt
			if ready and not n.Shown then n.Folder.Parent = fx; n.Shown = true end
			if not ready and n.Shown then n.Folder.Parent = nil; n.Shown = false end
			if n.Shown then
				local locked = n.BiomeTier > tier
				n.Top.Text = locked and ("🔒 TIER " .. n.BiomeTier) or "FREE EGG!"
				local d = camPos and (camPos - n.Base).Magnitude or 0
				if d < 450 then
					n.Model:PivotTo(CFrame.new(n.Base + Vector3.new(0, 1.2 + math.sin(t * 2.2 + n.Seed) * 0.8, 0)) * CFrame.Angles(0, t * 1.4 + n.Seed, math.sin(t * 3 + n.Seed) * 0.12))
					n.Beam.Transparency = 0.75 + math.sin(t * 3 + n.Seed) * 0.08
				end
				if not locked and pos and not triggered and not EggHatchUI.IsBusy() and (pos - n.Base).Magnitude < Config.EggRules.RoadRadius then
					triggered = true
					n.ReadyAt = t + 2 -- trava enquanto o servidor responde
					task.spawn(function()
						local ok, err = EggHatchUI.FromRoad(part.Name)
						n.ReadyAt = os.clock() + (ok and Config.EggRules.RoadCooldown or (err == "Cooldown" and 8 or 3))
					end)
				end
			end
		end
	end)
end

return EggNodes
