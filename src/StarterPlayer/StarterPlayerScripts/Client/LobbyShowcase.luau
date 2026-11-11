--[[
	LobbyShowcase (Beta 1.4): as VITRINES do lobby "Sakura Night" — tudo no cliente (cada jogador vê as suas).
	  🚗 CAR SHOWROOM (peças com tag "ShowroomPad", atributo Slot):
	       1 = seu carro EQUIPADO (centro) | 2 = próximo carro a comprar | 3 = carro dos sonhos (o mais forte)
	       Os carros giram devagar nos giratórios; placa com nome/preço. Atualiza quando chega "CarState".
	  ⭐ HALL OF HEROES (tag "ShowcasePad", Slot 0..4):
	       0 = cópia do SEU AVATAR no pódio mais alto | 1..4 = seus 4 personagens que mais rendem ($/s)
	       Atualiza quando chega "Inventory" e quando você volta ao lobby.
	  🛒/🎒 BALCÕES (tags "CarShopKiosk" / "InventoryKiosk"): prompt (E) abre o Car Shop / o inventário.
	  🏮 Ambiente: lanternas flutuantes balançam (tag "LobbyLantern") e peixes koi nadam (tag "KoiFish").
	StreamingEnabled: as peças entram/saem pelos sinais de tag; tudo é reconstruído quando reaparece.
	Animações só rodam quando a câmera está perto do lobby (economia no celular).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local AnimeFactory = require(Shared.AnimeModelFactory)
local CarFactory = require(Shared.CarFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local InventoryPanel = require(script.Parent.InventoryPanel)
local lp = Players.LocalPlayer

local LobbyShowcase = {}
local fx                      -- pasta workspace.ClientLobby (modelos locais)
local showroom, heroes = {}, {} -- [slot] = { Pad, Model, Gui, Center, Rel, Spin }
local lanterns, fish = {}, {}
local pending = {}

-- ---------------------------------------------------------------- utilidades
local function padTop(pad)
	local h = (pad.Shape == Enum.PartType.Cylinder) and pad.Size.X or pad.Size.Y
	return pad.Position + Vector3.new(0, h / 2, 0)
end
local function freeze(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
end
-- apoia o modelo em cima do ponto `top` (pelo fundo da caixa), virado para o norte (-Z = para a praça)
local function placeOn(model, top)
	model:PivotTo(CFrame.new(top))
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(top.X - cf.Position.X, top.Y - (cf.Position.Y - size.Y / 2), top.Z - cf.Position.Z))
	return CFrame.new(top):ToObjectSpace(model:GetPivot())
end
-- placa flutuante com tamanho em STUDS (encolhe com a distância => não polui a tela de longe)
local function billboard(adornee, offsetY, lines)
	local total = 0
	for _, l in ipairs(lines) do total += (l.Size or 24) / 18 end
	-- âncora num Attachment em coordenada de MUNDO (peças giradas, como os giratórios-cilindro, entortariam o offset)
	local att = Instance.new("Attachment")
	att.Name = "ShowcaseLabel"
	att.Parent = adornee
	att.WorldPosition = adornee.Position + Vector3.new(0, offsetY, 0)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(16, total)
	bb.MaxDistance = 120; bb.LightInfluence = 0; bb.AlwaysOnTop = false
	local y = 0
	for _, l in ipairs(lines) do
		local h = (l.Size or 24) / 18 / total
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, h * 0.92); t.Position = UDim2.fromScale(0, y)
		y += h
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.Text = l.Text; t.TextColor3 = l.Color or Color3.new(1, 1, 1); t.RichText = true
		local s = Instance.new("UIStroke"); s.Thickness = 2.5; s.Parent = t
		t.Parent = bb
		if l.Void then UIKit.VoidText(t) elseif l.Rainbow then UIKit.Rainbow(t) end
	end
	bb.Parent = att
	return att -- destruir o Attachment apaga a placa junto
end
local function clearSlot(entry)
	if entry.Model then entry.Model:Destroy(); entry.Model = nil end
	if entry.Gui then entry.Gui:Destroy(); entry.Gui = nil end
end
-- reconstrói no máximo 1x por quadro por grupo (vários eventos juntos = 1 reconstrução)
local function schedule(name, fn)
	if pending[name] then return end
	pending[name] = true
	task.delay(0.2, function() pending[name] = nil; local ok, err = pcall(fn); if not ok then warn("[LobbyShowcase] " .. tostring(err)) end end)
end

-- ---------------------------------------------------------------- CAR SHOWROOM
local function carForSlot(slot, cs)
	local eq = Config.CarById[cs.Equipped] or Config.Cars[1]
	if slot == 1 then
		return eq, "⭐ YOUR CAR", ("%s  •  Engine Lv %d"):format(eq.Name, cs.EngineLevel or 0), Config.Lobby.Theme.Gold
	elseif slot == 2 then
		for _, c in ipairs(Config.Cars) do
			if not cs.Owned[c.Id] then return c, "🔜 NEXT UPGRADE", ("%s  •  $%s"):format(c.Name, Util.FormatNumber(c.Price)), Config.Lobby.Theme.Showroom end
		end
		return eq, "✅ ALL CARS OWNED", "you're a legend!", Config.Lobby.Theme.Showroom
	else
		local top = Config.Cars[#Config.Cars]
		return top, "🏆 DREAM CAR", ("%s  •  %s"):format(top.Name, cs.Owned[top.Id] and "OWNED!" or ("$" .. Util.FormatNumber(top.Price))), Config.Lobby.Theme.Heroes
	end
end

local function rebuildShowroom()
	local cs = State.Cars
	if not cs then return end
	for slot, e in pairs(showroom) do
		clearSlot(e)
		if e.Pad.Parent then
			local cfg, title, sub, color = carForSlot(slot, cs)
			local m = CarFactory.Build(cfg, true)
			freeze(m)
			m:ScaleTo(1.35)
			e.Center = padTop(e.Pad)
			e.Rel = placeOn(m, e.Center)
			m.Parent = fx
			e.Model = m
			e.Spin = (slot - 1) * 2
			e.Gui = billboard(e.Pad, 13, { { Text = title, Color = color, Size = 26 }, { Text = sub, Size = 20 } })
		end
	end
end

-- ---------------------------------------------------------------- HALL OF HEROES
local function buildAvatar()
	local char = lp.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local was = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not clone then return nil end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy() end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	freeze(clone)
	clone.Name = "HeroAvatar"
	return clone
end

local function bestCharacters(n)
	local list = table.clone(State.Inventory or {})
	table.sort(list, function(a, b) if a.Income ~= b.Income then return a.Income > b.Income end return a.Uid < b.Uid end)
	local out = {}
	for i = 1, math.min(n, #list) do out[i] = list[i] end
	return out
end

local function rebuildHeroes()
	local best = bestCharacters(4)
	local total = 0
	for _, e in ipairs(State.Inventory or {}) do if e.Placed then total += e.Income end end
	for slot, e in pairs(heroes) do
		clearSlot(e)
		if e.Pad.Parent then
			e.Center = padTop(e.Pad)
			if slot == 0 then
				local av = buildAvatar()
				if av then
					pcall(function() av:ScaleTo(1.4) end)
					e.Rel = placeOn(av, e.Center)
					av.Parent = fx
					e.Model = av
				end
				e.Gui = billboard(e.Pad, 10.5, { { Text = "⭐ " .. lp.DisplayName, Color = Config.Lobby.Theme.Gold, Size = 26 },
					{ Text = "Garage income: $" .. Util.FormatNumber(total) .. "/s", Color = UIKit.C.Cash, Size = 20 } })
			else
				local c = best[slot]
				local cfg = c and Config.AnimeById[c.Id]
				if cfg then
					local rar = Config.Rarities[cfg.Rarity]
					local m = AnimeFactory.Build(cfg, c.Mut, c.Size)
					freeze(m)
					pcall(function() m:ScaleTo(m:GetScale() * 1.5) end)
					e.Rel = placeOn(m, e.Center)
					m.Parent = fx
					e.Model = m
					local tag = rar.Label
					if c.Mut then tag = c.Mut:upper() .. " " .. tag end
					e.Gui = billboard(e.Pad, 12.5, { { Text = ("#%d %s"):format(slot, cfg.Name), Size = 24 },
						{ Text = tag, Color = Config.RarityText(rar), Size = 20, Rainbow = rar.Rainbow, Void = rar.Void }, { Text = "$" .. Util.FormatNumber(c.Income) .. "/s", Color = UIKit.C.Cash, Size = 20 } })
				else
					e.Gui = billboard(e.Pad, 6, { { Text = "#" .. slot .. "  ???", Color = Color3.fromRGB(200, 190, 230), Size = 24 },
						{ Text = "hatch more heroes!", Size = 18 } })
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- tags (streaming-safe)
local function onPad(tag, list, rebuild)
	local function add(p)
		local slot = p:GetAttribute("Slot")
		if slot == nil then return end
		if list[slot] then clearSlot(list[slot]) end
		list[slot] = { Pad = p }
		schedule(tag, rebuild)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(p)
		for slot, e in pairs(list) do if e.Pad == p then clearSlot(e); list[slot] = nil end end
	end)
	for _, p in ipairs(CollectionService:GetTagged(tag)) do add(p) end
end

local function onKiosk(tag, action, object, fn)
	local function add(p)
		if p:FindFirstChild("KioskPrompt") then return end
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "KioskPrompt"; pp.ActionText = action; pp.ObjectText = object
		pp.KeyboardKeyCode = Enum.KeyCode.E; pp.HoldDuration = 0; pp.MaxActivationDistance = 14; pp.RequiresLineOfSight = false
		pp.Triggered:Connect(fn)
		pp.Parent = p
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	for _, p in ipairs(CollectionService:GetTagged(tag)) do add(p) end
end

local function track(tag, list, init)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(o) list[o] = init(o) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(o) list[o] = nil end)
	for _, o in ipairs(CollectionService:GetTagged(tag)) do list[o] = init(o) end
end

function LobbyShowcase.Init()
	fx = Instance.new("Folder"); fx.Name = "ClientLobby"; fx.Parent = workspace

	onPad("ShowroomPad", showroom, rebuildShowroom)
	onPad("ShowcasePad", heroes, rebuildHeroes)
	State.Changed.Event:Connect(function(what)
		if what == "Cars" then schedule("ShowroomPad", rebuildShowroom)
		elseif what == "Inventory" then schedule("ShowcasePad", rebuildHeroes) end
	end)
	-- avatar: refaz ao renascer (aparência carregada) e ao voltar para o lobby
	lp.CharacterAppearanceLoaded:Connect(function() task.wait(1); schedule("ShowcasePad", rebuildHeroes) end)
	lp:GetAttributeChangedSignal("RaceState"):Connect(function()
		if (lp:GetAttribute("RaceState") or "Lobby") == "Lobby" then task.wait(2); schedule("ShowcasePad", rebuildHeroes) end
	end)

	onKiosk("CarShopKiosk", "Open Car Shop", "Car Showroom", function() UIKit.OpenPanel("Garage") end)
	onKiosk("InventoryKiosk", "Open Inventory", "Hall of Heroes", function() InventoryPanel.OpenTab("Characters") end)
	-- Beta 1.7: quiosques e discos da roleta removidos do mapa (a roleta é só a janela Client.WheelPanel, botão WHEEL do dock).

	-- Beta 1.8: a base vem do atributo "Home" (gravado no Edit). Sem ele, só usa o PrimaryPart JÁ carregado; se nem isso,
	-- não anima (antes: pivô lido antes do streaming => todas as lanternas iam parar em (0,0,0), na largada da pista).
	track("LobbyLantern", lanterns, function(m)
		local home = m:GetAttribute("Home")
		if typeof(home) ~= "CFrame" then home = m.PrimaryPart and m.PrimaryPart.CFrame end
		if not home then return nil end
		return { Base = home, Seed = math.random() * 6.28 }
	end)
	track("KoiFish", fish, function(p) return { Center = p:GetAttribute("Center"), Radius = p:GetAttribute("Radius") or 5,
		Speed = p:GetAttribute("Speed") or 0.3, Seed = math.random() * 6.28 } end)

	-- Beta 1.4e: kanji holográficos gigantes nos biomas (tag "HoloSpin") giram e flutuam — só perto da câmera
	local holos = {}
	track("HoloSpin", holos, function(p) return { Base = p.CFrame, Seed = math.random() * 6.28 } end)
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local t = os.clock()
		for p, d in pairs(holos) do
			if p.Parent and (cam.CFrame.Position - d.Base.Position).Magnitude < 1200 then
				p.CFrame = d.Base * CFrame.new(0, math.sin(t * 0.8 + d.Seed) * 3, 0) * CFrame.Angles(0, t * 0.5 + d.Seed, 0)
			end
		end
	end)

	local origin = Config.Lobby.Origin
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam or (cam.CFrame.Position - origin).Magnitude > 650 then return end -- longe do lobby: nada anima
		local t = os.clock()
		for _, e in pairs(showroom) do
			if e.Model and e.Center then e.Model:PivotTo(CFrame.new(e.Center) * CFrame.Angles(0, t * 0.45 + e.Spin, 0) * e.Rel) end
		end
		for slot, e in pairs(heroes) do
			if slot > 0 and e.Model and e.Center then
				e.Model:PivotTo(CFrame.new(e.Center + Vector3.new(0, 0.6 + math.sin(t * 2 + slot) * 0.5, 0)) * CFrame.Angles(0, math.sin(t * 0.8 + slot) * 0.35, 0) * e.Rel)
			end
		end
		for m, d in pairs(lanterns) do
			if m.Parent and m.PrimaryPart and (d.Base.Position - origin).Magnitude < 700 then m:PivotTo(d.Base * CFrame.new(0, math.sin(t * 1.3 + d.Seed) * 0.7, 0) * CFrame.Angles(0, t * 0.4 + d.Seed, math.sin(t + d.Seed) * 0.06)) end
		end
		for p, d in pairs(fish) do
			if p.Parent and d.Center then
				local a = t * d.Speed + d.Seed
				local pos = d.Center + Vector3.new(math.cos(a) * d.Radius, 0, math.sin(a) * d.Radius)
				p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			end
		end
	end)
end

return LobbyShowcase
