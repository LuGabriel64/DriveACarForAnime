--[[
	BiomeEggs (Beta 1.3): desenha o OVO GIGANTE do fim de cada bioma (visual 100% no cliente).
	  * Cada Part com tag "BiomeEgg" (criada pelo Services.EscapeService em Map.BiomeEggs) vira um ovo enorme
	    girando, com anel, coluna de luz e placa ("GIANT EGG" / 🔒 TIER N / incubadora cheia).
	  * Beta 1.7: o prompt "GrabPrompt" (segurar F) vem do servidor; aqui ele só é LIGADO/DESLIGADO localmente (correndo,
	    sem ovo na mão, tier ok, incubadora com vaga). O visual do prompt é o Client.GrabPromptUI. O servidor confere tudo.
	  * Enquanto você foge com o ovo de um bioma, o ovo dele some (ele está em cima do seu carro — Client.EscapeFX).
	  * Com StreamingEnabled os ovos entram/saem pelos sinais de tag (só existem perto do jogador).
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local EggVisuals = require(script.Parent.EggVisuals)

local lp = Players.LocalPlayer
local BiomeEggs = {}
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
	local egg, biome = Config.Eggs[biomeId], Config.BiomeById[biomeId]
	if not egg or not biome then return end
	local base = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	local folder = Instance.new("Folder"); folder.Name = part.Name
	neon(folder, "Ring", Vector3.new(0.5, 30, 30), CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), egg.Color, 0.1, Enum.PartType.Cylinder)
	neon(folder, "Ring2", Vector3.new(0.6, 22, 22), CFrame.new(base + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), 0.5, Enum.PartType.Cylinder)
	local beam = neon(folder, "Beam", Vector3.new(7, 220, 7), CFrame.new(base + Vector3.new(0, 110, 0)), egg.Color, 0.78)
	local model = EggVisuals.Build(biomeId, 2.6)
	model.Parent = folder
	local light = Instance.new("PointLight"); light.Color = egg.Color; light.Range = 40; light.Brightness = 3; light.Parent = model.PrimaryPart

	local bb = Instance.new("BillboardGui")
	bb.Adornee = model.PrimaryPart; bb.Size = UDim2.fromOffset(190, 72); bb.StudsOffsetWorldSpace = Vector3.new(0, 12, 0) -- Beta 1.8: textos menores
	bb.MaxDistance = 700; bb.AlwaysOnTop = true; bb.LightInfluence = 0
	local function lbl(y, h, text, color, size)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, h); l.Position = UDim2.fromOffset(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextSize = size; l.TextColor3 = color; l.Text = text
		local s = Instance.new("UIStroke"); s.Thickness = 2.2; s.Parent = l
		l.Parent = bb
		return l
	end
	local top = lbl(0, 28, "GIANT EGG!", Color3.fromRGB(255, 230, 80), 25)
	lbl(28, 22, egg.Name, egg.Color:Lerp(Color3.new(1, 1, 1), 0.25), 18)
	local sub = lbl(50, 20, "Stop & hold F to grab!", Color3.fromRGB(255, 120, 90), 15)
	bb.Parent = model.PrimaryPart

	folder.Parent = fx
	nodes[part] = { Folder = folder, Model = model, Beam = beam, Top = top, Sub = sub, Base = base, Biome = biome,
		Seed = math.random() * 6.28, Prompt = part:FindFirstChild("GrabPrompt", true) }
end

local function unbuild(part)
	local n = nodes[part]
	if n then n.Folder:Destroy(); nodes[part] = nil end
end

function BiomeEggs.Init()
	fx = Instance.new("Folder"); fx.Name = "ClientBiomeEggs"; fx.Parent = workspace
	CollectionService:GetInstanceAddedSignal("BiomeEgg"):Connect(build)
	CollectionService:GetInstanceRemovedSignal("BiomeEgg"):Connect(unbuild)
	for _, p in ipairs(CollectionService:GetTagged("BiomeEgg")) do build(p) end

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local tier = lp:GetAttribute("CarTier") or 1
		local racing = (lp:GetAttribute("RaceState") or "Lobby") == "Racing"
		local escaping = lp:GetAttribute("EscapeState") == "Escaping"
		local carrying = escaping and lp:GetAttribute("EscapeBiome") or nil
		local full = (lp:GetAttribute("IncubatorUsed") or 0) >= (lp:GetAttribute("IncubatorSlots") or Config.Incubator.Slots)
		for part, n in pairs(nodes) do
			if not n.Prompt or not n.Prompt.Parent then n.Prompt = part:FindFirstChild("GrabPrompt", true) end
			local locked = n.Biome.Tier > tier
			local show = carrying ~= n.Biome.Id
			if show and n.Folder.Parent ~= fx then n.Folder.Parent = fx elseif not show and n.Folder.Parent then n.Folder.Parent = nil end
			if n.Prompt then n.Prompt.Enabled = show and racing and not escaping and not locked and not full end
			if show then
				if locked then n.Top.Text, n.Sub.Text = "🔒 TIER " .. n.Biome.Tier, "Needs a Tier " .. n.Biome.Tier .. " car"
				elseif full then n.Top.Text, n.Sub.Text = "GIANT EGG!", "🥚 Incubator full!"
				elseif escaping then n.Top.Text, n.Sub.Text = "GIANT EGG!", "One egg at a time!"
				else n.Top.Text, n.Sub.Text = "GIANT EGG!", "Stop & hold F to grab!" end
				local d = camPos and (camPos - n.Base).Magnitude or 0
				if d < 700 then
					n.Model:PivotTo(CFrame.new(n.Base + Vector3.new(0, 2 + math.sin(t * 1.8 + n.Seed) * 1.4, 0))
						* CFrame.Angles(0, t * 0.9 + n.Seed, math.sin(t * 2.4 + n.Seed) * 0.1))
					n.Beam.Transparency = 0.74 + math.sin(t * 3 + n.Seed) * 0.08
				end
			end
		end
	end)
end

return BiomeEggs
