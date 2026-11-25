--[[
	DevPanel  (StarterPlayerScripts.Client.DevPanel)                                          Beta 2.0b
	=====================================================================================================
	Painel 🛠️ DEV TOOLS da equipe DEV (Config.Dev). Só é CRIADO para quem tem o atributo "IsDev" (posto pelo
	Services.DevService); os outros jogadores não recebem nem o botão. Quem decide tudo é o servidor: cada botão
	chama uma ação "Dev*" pelo Shared.Net, e o servidor confere de novo se o jogador é DEV.

	ABRIR: botão vermelho "DEV" no canto de cima à direita (ao lado do ⚙️) ou a tecla F7.
	ALVO: no topo, ◀ ▶ escolhe o jogador que recebe (padrão: você). Serve para dar coisas ao outro DEV no teste 1v1.
	ABAS
	  CHARACTERS : lista de todos os personagens (filtro por bioma e busca). Escolha estrelas (0-5), mutação,
	               tamanho, nível e quantidade. GIVE = direto para a mochila/garagem | HATCH = ovo na incubadora que
	               choca em 2 s (mostra a revelação) | GIVE ALL = um de cada do filtro.
	  CASH & SPINS: somar ou definir dinheiro (aceita 10K, 2.5M, 1B, 1T, 1QA), giros extras, pontos, giro grátis já.
	  UNLOCKS    : todos os carros, motor no máximo, todos os F1 e efeitos de vitória, personagens 5★ nível 50,
	               chocar a incubadora agora, salvar agora.
	  LOG        : quem fez o quê neste servidor (o servidor guarda as últimas ações).
	Também (para TODOS os clientes): etiqueta vermelha [DEV] no chat antes do nome de quem é DEV.
	Textos em inglês sem tradução: o painel é só da equipe (não é UI de jogador).
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local DevPanel = {}
local D = Config.Dev or {}
local RED = Color3.fromRGB(220, 40, 50)
local built = false

local ERR = {
	NotDev = "⛔ You are not a DEV.", NoTarget = "🎯 That player left.", NoData = "⏳ Player data not loaded yet.",
	Invalid = "Invalid value.", IncubatorFull = "🥚 Incubator is full! Hatch or wait first.", TooFast = "Slow down!",
}

-- ---------------------------------------------------------------- etiqueta [DEV] no chat (todos os clientes)
local function setupChatTag()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end
	local color = D.ChatTagColor or RED
	local hex = string.format("#%02x%02x%02x", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
	TextChatService.OnIncomingMessage = function(msg)
		local src = msg.TextSource
		local p = src and Players:GetPlayerByUserId(src.UserId)
		if p and p:GetAttribute("IsDev") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = string.format("<font color='%s'>%s</font> %s", hex, D.ChatTag or "[DEV]", msg.PrefixText)
			return props
		end
		return nil
	end
end

-- "2.5M" -> 2500000 | "1e9" -> 1e9 | "1,000" -> 1000
local SUFFIX = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, QA = 1e15 }
local function parseAmount(s)
	s = tostring(s or ""):upper():gsub("[%s,$]", "")
	local num, suf = s:match("^([%d%.eE%+%-]+)(%a*)$")
	local n = tonumber(num)
	if not n then return nil end
	if suf ~= "" then
		if not SUFFIX[suf] then return nil end
		n *= SUFFIX[suf]
	end
	return math.floor(n)
end

local function build()
	if built then return end
	built = true
	local gui = new("ScreenGui", { Name = "DevUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 7 },
		lp:WaitForChild("PlayerGui"))
	local panel = UIKit.Panel({ Name = "Dev", Title = "🛠️ DEV TOOLS", HeaderColor = RED, Parent = gui,
		Size = UDim2.fromScale(0.86, 0.86), MaxSize = Vector2.new(980, 640), MinSize = Vector2.new(560, 420) })
	local body = panel.Body
	local Z = 23

	-- botão de abrir (canto de cima, à esquerda do ⚙️ do HUD)
	local open = UIKit.MenuButton(gui, { Name = "DevButton", Icon = "🛠️", Label = "DEV", Size = UDim2.fromOffset(64, 64),
		Color = RED, StrokeColor = Color3.new(0, 0, 0), OnClick = function() panel.Toggle() end })
	open.AnchorPoint = Vector2.new(1, 0); open.Position = UDim2.new(1, -86, 0, 8)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F7 then panel.Toggle() end
	end)

	-- ------------------------------------------------------------ alvo
	local targets, ti = {}, 1
	local targetLabel, statsLabel
	local function target() local p = targets[ti]; if p and p.Parent then return p end return lp end
	local function targetId() local p = target(); return p ~= lp and p.UserId or nil end
	local function refreshTargets()
		local cur = target()
		targets = Players:GetPlayers()
		ti = table.find(targets, cur) or table.find(targets, lp) or 1
		local p = target()
		targetLabel.Text = "🎯 " .. p.Name .. (p == lp and " (you)" or "") .. (p:GetAttribute("IsDev") and "  [DEV]" or "")
	end
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = Z }, body)
	UIKit.Button(bar, { Text = "◀", Size = UDim2.fromOffset(44, 36), Color = C.Blue, ZIndex = Z, OnClick = function()
		ti = ((ti - 2) % math.max(1, #targets)) + 1; refreshTargets() end })
	targetLabel = UIKit.Text(bar, { Text = "", TextSize = 22, Size = UDim2.new(0.42, -100, 1, 0), Position = UDim2.fromOffset(50, 0), Scaled = true, ZIndex = Z })
	UIKit.Button(bar, { Text = "▶", Size = UDim2.fromOffset(44, 36), Position = UDim2.new(0.42, -44, 0, 0), Color = C.Blue, ZIndex = Z, OnClick = function()
		ti = (ti % math.max(1, #targets)) + 1; refreshTargets() end })
	statsLabel = UIKit.Text(bar, { Text = "", TextSize = 18, Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.fromScale(0.44, 0),
		AlignX = Enum.TextXAlignment.Right, Scaled = true, ZIndex = Z, Color = Color3.fromRGB(200, 255, 190) })
	Players.PlayerAdded:Connect(refreshTargets)
	Players.PlayerRemoving:Connect(function() task.defer(refreshTargets) end)
	refreshTargets()

	local function call(name, ...)
		local r = Net.Call(name, targetId(), ...)
		if r and r.ok then Notify.Toast(r.Msg or "✅ Done", "good")
		else Notify.Toast(ERR[r and r.err or ""] or ("❌ " .. tostring(r and r.err or "No answer")), "error") end
		return r
	end

	-- ------------------------------------------------------------ abas
	local tabBar = new("Frame", { Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1, ZIndex = Z }, body)
	local pageArea = new("Frame", { Size = UDim2.new(1, 0, 1, -92), Position = UDim2.fromOffset(0, 92), BackgroundTransparency = 1, ZIndex = Z }, body)
	local pages, tabButtons = {}, {}
	local TABS = { { "Characters", "🐾 CHARACTERS" }, { "Cash", "💵 CASH & SPINS" }, { "Unlocks", "🔓 UNLOCKS" }, { "Log", "📜 LOG" } }
	local onShow = {}
	-- altura mínima de cada aba: em tela pequena a aba rola (ScrollingFrame) em vez de cortar
	local CANVAS = { Characters = 362, Cash = 380, Unlocks = 320, Log = 0 }
	local function show(name)
		for n, pg in pairs(pages) do pg.Visible = (n == name) end
		for n, b in pairs(tabButtons) do b.BackgroundColor3 = (n == name) and RED or C.Grey end
		if onShow[name] then task.spawn(onShow[name]) end
	end
	for i, t in ipairs(TABS) do
		pages[t[1]] = new("ScrollingFrame", { Name = t[1], Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = Z,
			ScrollBarThickness = 6, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, CANVAS[t[1]] or 0) }, pageArea)
		tabButtons[t[1]] = UIKit.Button(tabBar, { Text = t[2], TextSize = 20, Size = UDim2.new(0.25, -6, 1, 0), Position = UDim2.new((i - 1) * 0.25, 3, 0, 0),
			Color = C.Grey, ZIndex = Z, OnClick = function() show(t[1]) end })
	end

	local function label(parent, text, pos, size, color, align)
		return UIKit.Text(parent, { Text = text, TextSize = 18, Position = pos, Size = size, Scaled = true, ZIndex = Z, Color = color,
			AlignX = align or Enum.TextXAlignment.Left, Wrapped = true })
	end
	local function box(parent, placeholder, pos, size)
		local b = new("TextBox", { Text = "", PlaceholderText = placeholder, Font = UIKit.Font, TextSize = 20, TextColor3 = C.White,
			PlaceholderColor3 = Color3.fromRGB(150, 150, 165), BackgroundColor3 = C.CardBg, Position = pos, Size = size,
			ClearTextOnFocus = false, ZIndex = Z }, parent)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, b); UIKit.Stroke(b, 2.5, Color3.fromRGB(90, 90, 112))
		return b
	end

	-- ============================================================ CHARACTERS
	do
		local pg = pages.Characters
		local sel = { Id = nil, Stars = Config.Stars.Max, Mut = nil, Size = nil, Level = 1, Count = 1 }
		local biomeFilter, search = "all", ""
		local list = new("ScrollingFrame", { Size = UDim2.new(0.44, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundColor3 = C.CardBg,
			ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = Z }, pg)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, list)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) }, list)

		-- filtros: ALL + um botão por bioma + busca
		local filters = {}
		local fbar = new("Frame", { Size = UDim2.new(0.44, 0, 0, 38), BackgroundTransparency = 1, ZIndex = Z }, pg)
		local biomeKeys = { { "all", "ALL" } }
		for _, b in ipairs(Config.Biomes) do biomeKeys[#biomeKeys + 1] = { b.Id, b.Emoji or tostring(b.Order) } end
		local fw = 0.62 / #biomeKeys
		local rebuildList
		for i, k in ipairs(biomeKeys) do
			filters[k[1]] = UIKit.Button(fbar, { Text = k[2], TextSize = 16, Size = UDim2.new(fw, -2, 1, 0), Position = UDim2.new((i - 1) * fw, 0, 0, 0),
				Color = C.Grey, Radius = 8, StrokeThickness = 2, ZIndex = Z, OnClick = function() biomeFilter = k[1]; rebuildList() end })
		end
		local searchBox = box(fbar, "🔍 search", UDim2.new(0.63, 0, 0, 0), UDim2.new(0.37, 0, 1, 0))

		-- lado direito: prévia + opções + botões
		local right = new("Frame", { Size = UDim2.new(0.545, 0, 1, 0), Position = UDim2.fromScale(0.455, 0), BackgroundTransparency = 1, ZIndex = Z }, pg)
		local prevBox = new("Frame", { Size = UDim2.new(0.34, 0, 0, 176), BackgroundColor3 = C.CardBg, ZIndex = Z }, right)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, prevBox)
		local nameL = label(right, "Pick a character", UDim2.fromScale(0.37, 0), UDim2.new(0.63, 0, 0, 34))
		local infoL = label(right, "", UDim2.new(0.37, 0, 0, 36), UDim2.new(0.63, 0, 0, 26), Color3.fromRGB(200, 200, 215))
		local preview
		local function refreshPreview()
			if preview then preview:Destroy(); preview = nil end
			local cfg = sel.Id and Config.AnimeById[sel.Id]
			if not cfg then nameL.Text = "Pick a character"; infoL.Text = ""; return end
			local rar = Config.Rarities[cfg.Rarity]
			nameL.Text = cfg.Name; nameL.TextColor3 = Config.RarityText and Config.RarityText(rar) or rar.Color
			local b = Config.BiomeById[cfg.Biome]
			infoL.Text = ("%s %s · %s · $%s/s base"):format(b and b.Emoji or "", b and b.Name or cfg.Biome, rar.Label or cfg.Rarity, Util.FormatNumber(cfg.Income))
			local ok, model = pcall(AnimeFactory.Build, cfg, sel.Mut, sel.Size)
			if ok and model then preview = UIKit.Viewport(prevBox, model, { Dir = Vector3.new(0.35, 0.2, -1), Zoom = 0.95, ZIndex = Z }) end
		end

		local choiceRows = {}
		local function paintChoices()
			for key, btns in pairs(choiceRows) do
				for _, x in ipairs(btns) do x.B.BackgroundColor3 = (sel[key] == x.V) and C.Green or C.Grey end
			end
		end
		local function choiceRow(y, title, key, options, redraw)
			label(right, title, UDim2.new(0.37, 0, 0, y), UDim2.new(0.2, 0, 0, 30))
			local w = 0.43 / #options
			choiceRows[key] = {}
			for i, opt in ipairs(options) do
				local b = UIKit.Button(right, { Text = opt[1], TextSize = 17, Size = UDim2.new(w, -3, 0, 30), Position = UDim2.new(0.57 + (i - 1) * w, 0, 0, y),
					Color = C.Grey, Radius = 8, StrokeThickness = 2, ZIndex = Z, OnClick = function()
						sel[key] = opt[2]; paintChoices(); if redraw then refreshPreview() end end })
				table.insert(choiceRows[key], { B = b, V = opt[2] })
			end
		end
		local starOpts = {}
		for s = 0, Config.Stars.Max do starOpts[#starOpts + 1] = { s .. "★", s } end
		local mutOpts = { { "NONE", nil } }
		for _, m in ipairs(Config.MutationOrder) do table.insert(mutOpts, 2, { m:upper(), m }) end
		local sizeOpts = { { "NORMAL", nil } }
		for s in pairs(Config.Sizes) do sizeOpts[#sizeOpts + 1] = { s, s } end
		choiceRow(68, "STARS", "Stars", starOpts)
		choiceRow(104, "MUTATION", "Mut", mutOpts, true)
		choiceRow(140, "SIZE", "Size", sizeOpts, true)
		-- nível e quantidade ficam embaixo da prévia, ocupando a largura toda
		local function fullRow(y, title, key, options)
			label(right, title, UDim2.fromOffset(0, 178 + y), UDim2.new(0.2, 0, 0, 30))
			local w = 0.8 / #options
			choiceRows[key] = {}
			for i, opt in ipairs(options) do
				local b = UIKit.Button(right, { Text = opt[1], TextSize = 17, Size = UDim2.new(w, -3, 0, 30), Position = UDim2.new(0.2 + (i - 1) * w, 0, 0, 178 + y),
					Color = C.Grey, Radius = 8, StrokeThickness = 2, ZIndex = Z, OnClick = function() sel[key] = opt[2]; paintChoices() end })
				table.insert(choiceRows[key], { B = b, V = opt[2] })
			end
		end
		fullRow(8, "LEVEL", "Level", { { "1", 1 }, { "10", 10 }, { "25", 25 }, { "40", 40 }, { tostring(Config.Levels.Max), Config.Levels.Max } })
		fullRow(44, "AMOUNT", "Count", { { "x1", 1 }, { "x5", 5 }, { "x10", 10 }, { "x25", 25 }, { "x" .. (D.MaxGive or 50), D.MaxGive or 50 } })

		local function opts(hatch) return { Stars = sel.Stars, Mut = sel.Mut, Size = sel.Size, Level = sel.Level, Count = sel.Count, Hatch = hatch } end
		UIKit.Button(right, { Text = "🎁 GIVE", TextSize = 26, Size = UDim2.new(0.38, -4, 0, 52), Position = UDim2.fromOffset(0, 264), Color = C.Green, ZIndex = Z,
			OnClick = function()
				if not sel.Id then Notify.Toast("Pick a character first", "error"); return end
				call("DevGiveAnime", sel.Id, opts(false))
			end })
		UIKit.Button(right, { Text = "🥚 HATCH", TextSize = 26, Size = UDim2.new(0.3, -4, 0, 52), Position = UDim2.new(0.38, 0, 0, 264), Color = C.Orange, ZIndex = Z,
			OnClick = function()
				if not sel.Id then Notify.Toast("Pick a character first", "error"); return end
				call("DevGiveAnime", sel.Id, opts(true))
			end })
		local giveAll = UIKit.Button(right, { Text = "📦 GIVE ALL", TextSize = 22, Size = UDim2.new(0.32, 0, 0, 52), Position = UDim2.new(0.68, 0, 0, 264), Color = C.Magenta, ZIndex = Z,
			OnClick = function() call("DevGiveAll", biomeFilter, opts(false)) end })
		label(right, "GIVE = straight to your garage/backpack · HATCH = egg in the incubator, hatches in 2 s · GIVE ALL = one of each in the filter (uses stars/mutation/level)",
			UDim2.fromOffset(0, 322), UDim2.new(1, 0, 0, 34), Color3.fromRGB(170, 170, 190))

		-- lista
		local entries = {}
		for _, cfg in ipairs(Config.Animes) do if not cfg.Legacy then entries[#entries + 1] = cfg end end
		table.sort(entries, function(a, b)
			local ba, bb = Config.BiomeById[a.Biome], Config.BiomeById[b.Biome]
			local oa, ob = ba and ba.Order or 99, bb and bb.Order or 99
			if oa ~= ob then return oa < ob end
			local ra, rb = Config.Rarities[a.Rarity].Order, Config.Rarities[b.Rarity].Order
			if ra ~= rb then return ra < rb end
			return a.Name < b.Name
		end)
		local rows = {}
		function rebuildList()
			for k, b in pairs(filters) do b.BackgroundColor3 = (k == biomeFilter) and RED or C.Grey end
			UIKit.SetButton(giveAll, biomeFilter == "all" and "📦 GIVE ALL" or "📦 GIVE BIOME")
			for _, r in pairs(rows) do r:Destroy() end
			rows = {}
			local q = search:lower()
			for i, cfg in ipairs(entries) do
				if (biomeFilter == "all" or cfg.Biome == biomeFilter) and (q == "" or cfg.Name:lower():find(q, 1, true) or cfg.Id:find(q, 1, true)) then
					local rar = Config.Rarities[cfg.Rarity]
					local b = Config.BiomeById[cfg.Biome]
					local row = new("TextButton", { Text = "", AutoButtonColor = true, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i,
						BackgroundColor3 = (sel.Id == cfg.Id) and Color3.fromRGB(70, 40, 50) or Color3.fromRGB(40, 40, 56), ZIndex = Z }, list)
					new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
					local bar2 = new("Frame", { Size = UDim2.new(0, 6, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = rar.Void and C.White or rar.Color, ZIndex = Z }, row)
					new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar2)
					UIKit.Text(row, { Text = (b and b.Emoji or "") .. " " .. cfg.Name, TextSize = 18, AlignX = Enum.TextXAlignment.Left,
						Size = UDim2.new(0.66, -16, 1, 0), Position = UDim2.fromOffset(16, 0), Scaled = true, ZIndex = Z })
					UIKit.Text(row, { Text = rar.Label or cfg.Rarity, TextSize = 15, AlignX = Enum.TextXAlignment.Right, Color = Config.RarityText and Config.RarityText(rar) or rar.Color,
						Size = UDim2.new(0.34, -8, 1, 0), Position = UDim2.fromScale(0.66, 0), Scaled = true, ZIndex = Z })
					row.Activated:Connect(function() sel.Id = cfg.Id; refreshPreview(); rebuildList() end)
					rows[cfg.Id] = row
				end
			end
		end
		searchBox:GetPropertyChangedSignal("Text"):Connect(function() search = searchBox.Text; rebuildList() end)
		paintChoices(); rebuildList(); refreshPreview()
	end

	-- ============================================================ CASH & SPINS
	do
		local pg = pages.Cash
		label(pg, "💵 CASH", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 34), C.Cash)
		local amount = box(pg, "amount: 1000, 2.5M, 1B, 1T, 1QA", UDim2.fromOffset(0, 40), UDim2.new(0.5, -6, 0, 44))
		UIKit.Button(pg, { Text = "➕ ADD", TextSize = 22, Size = UDim2.new(0.24, -6, 0, 44), Position = UDim2.new(0.5, 0, 0, 40), Color = C.Green, ZIndex = Z,
			OnClick = function()
				local n = parseAmount(amount.Text)
				if not n then Notify.Toast("Type an amount (ex.: 2.5M)", "error"); return end
				call("DevCash", "add", n)
			end })
		UIKit.Button(pg, { Text = "📌 SET TO", TextSize = 22, Size = UDim2.new(0.26, 0, 0, 44), Position = UDim2.new(0.74, 0, 0, 40), Color = C.Blue, ZIndex = Z,
			OnClick = function()
				local n = parseAmount(amount.Text)
				if not n then Notify.Toast("Type an amount (ex.: 2.5M)", "error"); return end
				call("DevCash", "set", n)
			end })
		local quick = { { "+1K", 1e3 }, { "+100K", 1e5 }, { "+1M", 1e6 }, { "+100M", 1e8 }, { "+1B", 1e9 }, { "+1T", 1e12 }, { "+1QA", 1e15 } }
		for i, q in ipairs(quick) do
			UIKit.Button(pg, { Text = q[1], TextSize = 20, Size = UDim2.new(1 / #quick, -6, 0, 42), Position = UDim2.new((i - 1) / #quick, 0, 0, 92),
				Color = Color3.fromRGB(40, 150, 60), ZIndex = Z, OnClick = function() call("DevCash", "add", q[2]) end })
		end
		UIKit.Button(pg, { Text = "🧹 SET CASH TO 0", TextSize = 18, Size = UDim2.new(0.3, 0, 0, 36), Position = UDim2.new(0, 0, 0, 142),
			Color = C.Grey, ZIndex = Z, OnClick = function() call("DevCash", "set", 0) end })

		label(pg, "🎟️ LUCKY WHEEL SPINS", UDim2.fromOffset(0, 196), UDim2.new(1, 0, 0, 34), C.Gold)
		local spins = { { "+1", 1 }, { "+10", 10 }, { "+100", 100 }, { "+1000", 1000 }, { "-1", -1 } }
		for i, s in ipairs(spins) do
			UIKit.Button(pg, { Text = s[1] .. " SPINS", TextSize = 20, Size = UDim2.new(1 / #spins, -6, 0, 44), Position = UDim2.new((i - 1) / #spins, 0, 0, 236),
				Color = s[2] > 0 and C.Orange or C.Grey, ZIndex = Z, OnClick = function() call("DevSpins", "tokens", s[2]) end })
		end
		UIKit.Button(pg, { Text = "⏱️ FREE SPIN READY NOW", TextSize = 20, Size = UDim2.new(0.5, -6, 0, 44), Position = UDim2.new(0, 0, 0, 290),
			Color = C.Cyan, ZIndex = Z, OnClick = function() call("DevSpins", "free") end })
		UIKit.Button(pg, { Text = "➕ 50 SPIN POINTS", TextSize = 20, Size = UDim2.new(0.5, 0, 0, 44), Position = UDim2.new(0.5, 0, 0, 290),
			Color = C.Magenta, ZIndex = Z, OnClick = function() call("DevSpins", "points", 50) end })
		label(pg, "Spins = extra Lucky Wheel spins (same as the Robux packs). 100 spin points = 1 spin. Cash goes to the target's save.",
			UDim2.fromOffset(0, 344), UDim2.new(1, 0, 0, 30), Color3.fromRGB(170, 170, 190))
	end

	-- ============================================================ UNLOCKS
	do
		local pg = pages.Unlocks
		local items = {
			{ "🏎️ UNLOCK ALL CARS", "Every race car (equip one in the Garage to reach its biome)", C.Orange, function() call("DevCars", "all") end },
			{ "🔧 MAX ENGINE", "Engine level " .. Config.Engine.MaxLevel .. " on every car owned", C.Blue, function() call("DevCars", "engine") end },
			{ "🏁 ALL F1 + VICTORY FX", "Every 1v1 F1 car and victory effect", C.Cyan, function() call("DevVersusShop") end },
			{ "⭐ MAX ALL CHARACTERS", ("%d★ and level %d on every character"):format(Config.Stars.Max, Config.Levels.Max), C.Gold, function() call("DevMaxAnimes") end },
			{ "🥚 HATCH INCUBATOR NOW", "Every egg in the incubator hatches", C.Magenta, function() call("DevHatchNow") end },
			{ "💾 SAVE NOW", "Writes the target's save right away", C.Green, function() call("DevSaveNow") end },
		}
		for i, it in ipairs(items) do
			local col, row = (i - 1) % 2, (i - 1) // 2
			local card = new("Frame", { Size = UDim2.new(0.5, -6, 0, 96), Position = UDim2.new(col * 0.5, col * 6, 0, row * 106), BackgroundColor3 = C.CardBg, ZIndex = Z }, pg)
			new("UICorner", { CornerRadius = UDim.new(0, 12) }, card); UIKit.Stroke(card, 2.5, Color3.fromRGB(90, 90, 112))
			UIKit.Button(card, { Text = it[1], TextSize = 22, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 8), Color = it[3], ZIndex = Z, OnClick = it[4] })
			label(card, it[2], UDim2.fromOffset(10, 62), UDim2.new(1, -20, 0, 26), Color3.fromRGB(190, 190, 205))
		end
	end

	-- ============================================================ LOG
	do
		local pg = pages.Log
		local scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), BackgroundColor3 = C.CardBg,
			ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = Z }, pg)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, scroll)
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12) }, scroll)
		local playersL = label(pg, "", UDim2.fromOffset(0, 0), UDim2.new(0.75, 0, 0, 42), Color3.fromRGB(200, 220, 255))
		local function refresh()
			local r = Net.Call("DevInfo")
			for _, ch in ipairs(scroll:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
			if not (r and r.ok) then return end
			local names = {}
			for _, p in ipairs(r.Players or {}) do names[#names + 1] = p.Name .. (p.Dev and " [DEV]" or "") end
			playersL.Text = "👥 In this server: " .. table.concat(names, ", ") .. (r.Studio and "   (Studio)" or "")
			if #(r.Log or {}) == 0 then label(scroll, "No dev actions yet in this server.", UDim2.new(), UDim2.new(1, 0, 0, 26)) end
			for i, l in ipairs(r.Log or {}) do
				local t = UIKit.Text(scroll, { Text = ("%s  %s → %s: %s"):format(os.date("%H:%M:%S", l.Time), l.By, l.Target, l.Text), TextSize = 17,
					AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), Scaled = true, ZIndex = Z, LayoutOrder = i, Stroke = 1.5 })
				t.TextColor3 = (l.By == lp.Name) and C.White or Color3.fromRGB(255, 210, 150)
			end
		end
		UIKit.Button(pg, { Text = "🔄 REFRESH", TextSize = 20, Size = UDim2.new(0.24, 0, 0, 42), Position = UDim2.new(0.76, 0, 0, 0), Color = C.Blue, ZIndex = Z, OnClick = refresh })
		onShow.Log = refresh
	end

	-- números do alvo no topo (enquanto o painel está aberto)
	panel.OnOpen = function()
		refreshTargets()
		while panel.IsOpen do
			local p = target()
			statsLabel.Text = ("💵 $%s   ⚡ $%s/s   🎟️ %d spins   🎯 %d/100 pts"):format(Util.FormatNumber(p:GetAttribute("Cash") or 0),
				Util.FormatNumber(p:GetAttribute("CashPerSec") or 0), p:GetAttribute("WheelTokens") or 0, p:GetAttribute("WheelPoints") or 0)
			task.wait(0.5)
		end
	end
	show("Characters")
	print("[DevPanel] painel DEV pronto para " .. lp.Name)
end

function DevPanel.Init()
	if not (D.Enabled) then return end
	pcall(setupChatTag)
	if lp:GetAttribute("IsDev") then build()
	else
		lp:GetAttributeChangedSignal("IsDev"):Connect(function() if lp:GetAttribute("IsDev") then build() end end)
	end
end

return DevPanel
