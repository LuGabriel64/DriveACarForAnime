--[[
	AnimeNodes: pontos de captura no mapa (por jogador, 100% visuais no cliente).
	Cada Part marcada com a tag "AnimeSpawn" (workspace.Map.AnimeSpawns) vira: anel neon + coluna de luz +
	silhueta misteriosa flutuando. Ao chegar perto, abre a captura; depois some por NodeCooldown segundos
	SÓ PARA O JOGADOR (cada um vê os seus pontos). O servidor revalida tudo (distância, tier, cooldown).
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local AnimeFactory = require(Shared.AnimeModelFactory)
local EncounterUI = require(script.Parent.EncounterUI)
local Drive = require(script.Parent.DriveController)

local AnimeNodes = {}
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
	local biome = biomeId and Config.BiomeById[biomeId]
	local color = biome and biome.Color or Color3.new(1, 1, 1)
	local base = part.Position
	local folder = Instance.new("Folder"); folder.Name = part.Name

	neon(folder, "Ring", Vector3.new(0.5, 13, 13), CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, 0.15, Enum.PartType.Cylinder)
	neon(folder, "Beam", Vector3.new(3, 80, 3), CFrame.new(base + Vector3.new(0, 40, 0)), color, 0.78)

	local pool = {}
	for _, a in ipairs(Config.Animes) do if a.Biome == biomeId then table.insert(pool, a) end end
	local cfg = pool[math.random(1, math.max(#pool, 1))] or Config.Animes[1]
	local model = AnimeFactory.Build(cfg)
	AnimeFactory.Silhouette(model)
	model:ScaleTo(1.7)
	model.Parent = folder
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(10, 10, 16); hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency, hl.OutlineTransparency = 0, 0
	hl.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Adornee = model.PrimaryPart; bb.Size = UDim2.fromOffset(90, 90); bb.StudsOffsetWorldSpace = Vector3.new(0, 15, 0); bb.AlwaysOnTop = false; bb.MaxDistance = 400
	local q = Instance.new("TextLabel")
	q.BackgroundTransparency = 1; q.Size = UDim2.fromScale(1, 1); q.Font = Enum.Font.FredokaOne; q.Text = "?"; q.TextScaled = true; q.TextColor3 = color
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Parent = q
	q.Parent = bb; bb.Parent = model.PrimaryPart

	folder.Parent = fx
	nodes[part] = { Folder = folder, Model = model, Highlight = hl, Base = base, Seed = math.random() * 6.28, ReadyAt = 0, Shown = true }
end

function AnimeNodes.Init()
	fx = Instance.new("Folder"); fx.Name = "ClientNodes"; fx.Parent = workspace
	CollectionService:GetInstanceAddedSignal("AnimeSpawn"):Connect(build)
	CollectionService:GetInstanceRemovedSignal("AnimeSpawn"):Connect(function(part)
		local n = nodes[part]
		if n then n.Folder:Destroy(); nodes[part] = nil end
	end)
	for _, p in ipairs(CollectionService:GetTagged("AnimeSpawn")) do build(p) end

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local pos = Drive.GetPosition()
		local triggered = false
		for part, n in pairs(nodes) do
			local ready = t >= n.ReadyAt
			if ready and not n.Shown then n.Folder.Parent = fx; n.Shown = true end
			if not ready and n.Shown then n.Folder.Parent = nil; n.Shown = false end
			if n.Shown then
				local d = camPos and (camPos - n.Base).Magnitude or 0
				if d < 450 then
					n.Model:PivotTo(CFrame.new(n.Base + Vector3.new(0, 8 + math.sin(t * 2 + n.Seed) * 0.9, 0)) * CFrame.Angles(0, t * 1.3 + n.Seed, 0))
				end
				n.Highlight.Enabled = d < 220 -- limite de Highlights simultâneos do Roblox
				if pos and not triggered and not EncounterUI.IsBusy() and (pos - n.Base).Magnitude < Config.Capture.TriggerRadius then
					triggered = true
					task.spawn(function()
						local ok, err = EncounterUI.Begin(part.Name)
						n.ReadyAt = os.clock() + (ok and Config.Capture.NodeCooldown or (err == "Locked" and 8 or 3))
					end)
				end
			end
		end
	end)
end

return AnimeNodes
