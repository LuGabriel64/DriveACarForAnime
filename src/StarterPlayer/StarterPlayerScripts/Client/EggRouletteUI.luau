--[[
	EggRouletteUI (Beta 1.3): a ROLETA do ovo do bioma (estilo gacha / "case opening").
	  Evento do servidor "EggRoulette"(info) => Play(info):
	    1. Escurece a tela, raios girando, título do ovo e o ovo tremendo.
	    2. Uma FAIXA de cartas de personagens passa sob o marcador dourado e desacelera (TweenService,
	       EasingStyle.Quint/Out) até parar EXATAMENTE na carta que o SERVIDOR sorteou (info.Result).
	       As outras cartas são só enfeite (sorteadas aqui com a mesma tabela Config.EggOdds); a carta
	       logo depois da vencedora costuma ser rara (efeito "quase!").
	    3. Clarão + revelação: raridade, "1 in N", nome, mutação/BIG e o tempo de choco na base.
	    4. No horário do servidor (info.RouletteEnds) fecha com "RUN!" — aí começa a fuga (Client.EscapeFX).
	  Enquanto toca, State.Encounter = true (o DriveController freia o carro).
	  info = { Biome, Result = { Id, Mut, Size, Odds }, HatchSeconds, RouletteEnds, FrontStart }
	Dependências: UIKit, State, EggVisuals, AnimeModelFactory, Config.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local EggVisuals = require(script.Parent.EggVisuals)
local new, C = UIKit.New, UIKit.C

local EggRouletteUI = {}
local gui
local busy = false
function EggRouletteUI.IsBusy() return busy end

local CARD_W, CARD_H, GAP = 132, 164, 10
local STEP = CARD_W + GAP
local COUNT, WIN = 34, 28       -- cartas na faixa / posição da vencedora
local SPIN = 4.3                -- segundos girando
local WIN_W = 760               -- largura da janela da roleta

-- sorteio só VISUAL (enfeite das cartas). O resultado de verdade vem do servidor.
local function cosmetic(odds)
	local r, acc = math.random(), 0
	for _, row in ipairs(odds) do
		acc += row.Chance
		if r < acc then return row.Anime end
	end
	return odds[#odds].Anime
end

local function makeCard(strip, cfg, i, mut, size)
	local rar = Config.Rarities[cfg.Rarity]
	local f = new("Frame", { Name = "Card" .. i, Size = UDim2.fromOffset(CARD_W, CARD_H), Position = UDim2.fromOffset((i - 1) * STEP, 0),
		BackgroundColor3 = rar.Color, ZIndex = 62 }, strip)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
	UIKit.Stroke(f, 3.5)
	if not UIKit.RarityFx(f, rar, 90) then UIKit.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(80, 80, 80), 90) end
	local vh = new("Frame", { Size = UDim2.new(1, -12, 0, 106), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, ZIndex = 63 }, f)
	UIKit.Viewport(vh, AnimeFactory.Build(cfg, mut, size), { Dir = Vector3.new(0.3, 0.15, -1), Zoom = 0.95, ZIndex = 63 })
	UIKit.Text(f, { Text = cfg.Name, TextSize = 15, Scaled = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 1, -50), Stroke = 2.5, ZIndex = 64 })
	local rl = UIKit.Text(f, { Text = rar.Label, TextSize = 14, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.new(0, 5, 1, -25), Stroke = 2.5, ZIndex = 64 })
	UIKit.RarityLabel(rl, rar)
	local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 65 }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, dim)
	return f
end

function EggRouletteUI.Play(info)
	if busy then return end
	local cfgWin = info and info.Result and Config.AnimeById[info.Result.Id]
	if not cfgWin then return end
	busy = true
	State.Encounter = true
	local egg = Config.Eggs[info.Biome] or Config.Eggs[Config.Biomes[1].Id]
	local rarWin = Config.Rarities[cfgWin.Rarity]
	local odds = Config.EggOdds(info.Biome, 1)

	-- ---------- fundo + conteúdo escalável (celular: tudo encolhe junto)
	local overlay = new("Frame", { Name = "Roulette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 14),
		BackgroundTransparency = 1, ZIndex = 50 }, gui)
	UIKit.Tween(overlay, 0.25, { BackgroundTransparency = 0.35 })
	local burst = UIKit.Sunburst(overlay, egg.Color, 14, 51)
	local content = new("Frame", { Size = UDim2.fromOffset(820, 600), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, ZIndex = 52 }, overlay)
	local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	new("UIScale", { Scale = math.clamp(math.min((vs.X - 24) / 820, (vs.Y - 24) / 600), 0.4, 1) }, content)

	local title = UIKit.Text(content, { Text = "🥚 " .. egg.Name:upper() .. " 🥚", TextSize = 46, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 20), Stroke = 5, ZIndex = 60 })
	UIKit.Gradient(title, egg.Color:Lerp(Color3.new(1, 1, 1), 0.4), egg.Color, 90)
	UIKit.Pop(title, 1.3)
	local eggHolder = new("Frame", { Size = UDim2.fromOffset(120, 130), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, ZIndex = 58 }, content)
	local eggVp = UIKit.Viewport(eggHolder, EggVisuals.Build(info.Biome, 1), { Dir = Vector3.new(0, 0.12, -1), Zoom = 1.05, ZIndex = 58 })

	-- ---------- janela + faixa de cartas
	local window = new("Frame", { Size = UDim2.fromOffset(WIN_W, CARD_H + 16), Position = UDim2.new(0.5, 0, 0, 316), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.PanelBg, ClipsDescendants = true, ZIndex = 60 }, content)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, window)
	UIKit.Stroke(window, 5)
	local strip = new("Frame", { Size = UDim2.fromOffset(COUNT * STEP, CARD_H), BackgroundTransparency = 1, ZIndex = 61 }, window)
	local rarest = odds[#odds] and odds[#odds].Anime
	for i = 1, COUNT do
		if i == WIN then
			makeCard(strip, cfgWin, i, info.Result.Mut, info.Result.Size)
		else
			local cfg = cosmetic(odds)
			if i == WIN + 1 and rarest and math.random() < 0.6 then cfg = rarest end -- "quase!"
			makeCard(strip, cfg, i)
		end
	end
	local marker = new("Frame", { Size = UDim2.new(0, 6, 1, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 66 }, window)
	UIKit.Stroke(marker, 2)
	local arrowTop = UIKit.Text(content, { Text = "▼", TextSize = 40, Color = C.Gold, Size = UDim2.fromOffset(60, 40), Position = UDim2.new(0.5, 0, 0, 316 - (CARD_H + 16) / 2 - 18),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = 67 })
	local arrowBot = UIKit.Text(content, { Text = "▲", TextSize = 40, Color = C.Gold, Size = UDim2.fromOffset(60, 40), Position = UDim2.new(0.5, 0, 0, 316 + (CARD_H + 16) / 2 + 18),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = 67 })

	-- ---------- giro (TweenService): para com a carta vencedora sob o marcador
	local center = WIN_W / 2
	local y = 8
	local startX = center - (2 * STEP + CARD_W / 2)
	local jitter = math.random(-math.floor(CARD_W * 0.38), math.floor(CARD_W * 0.38))
	local endX = center - ((WIN - 1) * STEP + CARD_W / 2)
	strip.Position = UDim2.fromOffset(startX, y)
	local spin = TweenService:Create(strip, TweenInfo.new(SPIN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(endX + jitter, y) })
	local lastIdx
	local tick = RunService.RenderStepped:Connect(function()
		local idx = math.floor((center - strip.Position.X.Offset) / STEP)
		if idx ~= lastIdx then
			lastIdx = idx
			UIKit.PlaySound("Click")
			UIKit.Pop(arrowTop, 1.25); UIKit.Pop(arrowBot, 1.25)
			eggVp.Rotation = math.random(-9, 9)
		end
	end)
	UIKit.PlaySound("Hatch")
	spin:Play()
	spin.Completed:Wait()
	tick:Disconnect()
	eggVp.Rotation = 0
	-- encaixa no centro da carta (pequeno "clique" de assentamento)
	UIKit.Tween(strip, 0.35, { Position = UDim2.fromOffset(endX, y) }, Enum.EasingStyle.Back)
	task.wait(0.35)

	-- ---------- destaque + revelação
	for _, card in ipairs(strip:GetChildren()) do
		if card.Name ~= "Card" .. WIN and card:FindFirstChild("Dim") then UIKit.Tween(card.Dim, 0.25, { BackgroundTransparency = 0.45 }) end
	end
	local winCard = strip:FindFirstChild("Card" .. WIN)
	if winCard then
		local st = winCard:FindFirstChildOfClass("UIStroke")
		if st then st.Color = C.Gold; st.Thickness = 6 end
		UIKit.Pop(winCard, 1.18)
	end
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 80 }, overlay)
	UIKit.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	burst:Destroy()
	burst = UIKit.Sunburst(overlay, Config.RarityFx(rarWin), 16, 51)
	UIKit.PlaySound(rarWin.Order >= 4 and "Rare" or "Reveal")
	UIKit.Confetti(overlay, Config.RarityFx(rarWin), 20 + rarWin.Order * 10)
	eggHolder.Visible = false

	local ribbon = new("Frame", { Size = UDim2.fromOffset(420, 52), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = rarWin.Color, ZIndex = 62 }, content)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, ribbon); UIKit.Stroke(ribbon, 4)
	if not UIKit.RarityFx(ribbon, rarWin, 120) then UIKit.Gradient(ribbon, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) end
	UIKit.Text(ribbon, { Text = rarWin.Label .. "!", TextSize = 38, Scaled = true, Size = UDim2.fromScale(0.92, 0.82), Position = UDim2.fromScale(0.04, 0.09), Stroke = 4, ZIndex = 63 })
	UIKit.Shine(ribbon, 1.4)
	UIKit.Pop(ribbon, 1.5)
	-- Beta 1.9: as ESTRELAS (0..5) sorteadas pelo servidor aparecem ao lado do "1 in N" (não entram nesse número)
	local starN = math.clamp(tonumber(info.Result.Stars) or 0, 0, Config.Stars.Max)
	local starText = "   " .. string.rep("★", starN) .. string.rep("☆", Config.Stars.Max - starN)
	local oddsL = UIKit.Text(content, { Text = "1 in " .. Util.FormatNumber(info.Result.Odds or 1) .. starText, TextSize = 30, Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 196), Stroke = 4, ZIndex = 62 })
	UIKit.RarityLabel(oddsL, rarWin)

	local line = cfgWin.Name
	if info.Result.Mut then line = ('<font color="#%s">%s</font> '):format(Config.Mutations[info.Result.Mut].Color:ToHex(), info.Result.Mut:upper()) .. line end
	if info.Result.Size then line = '<font color="#ffb400">' .. info.Result.Size .. "</font> " .. line end
	UIKit.Text(content, { Text = line, RichText = true, TextSize = 34, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 430), Stroke = 4, ZIndex = 62 })
	UIKit.Text(content, { Text = "⏳ Hatches in " .. Config.FormatDuration(info.HatchSeconds or 30) .. " at your base", TextSize = 26,
		Color = Color3.fromRGB(150, 230, 255), Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 474), Stroke = 3, ZIndex = 62 })
	if rarWin.Order >= 5 then UIKit.Shake(content, 7, 0.6) end
	if rarWin.Order >= 7 then
		local s = UIKit.Text(content, { Text = "✨ SECRET! ✨", TextSize = 64, Size = UDim2.new(1, 0, 0, 74), Position = UDim2.fromOffset(0, 80), Stroke = 6, ZIndex = 70 })
		UIKit.RarityLabel(s, rarWin); UIKit.Pop(s, 1.6); UIKit.Confetti(overlay, Color3.new(1, 1, 1), 60)
	end

	-- ---------- espera o relógio do servidor e manda correr
	local ends = info.RouletteEnds or (workspace:GetServerTimeNow() + 1)
	while workspace:GetServerTimeNow() < ends - 0.6 do task.wait(0.05) end
	local run = UIKit.Text(content, { Text = "🚨 RUN! GET BACK TO BASE! 🚨", TextSize = 50, Color = Color3.fromRGB(255, 80, 60), Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 530), Stroke = 6, ZIndex = 72 })
	UIKit.Pop(run, 1.7)
	UIKit.Shake(content, 10, 0.5)
	while workspace:GetServerTimeNow() < ends do task.wait(0.05) end

	UIKit.Tween(overlay, 0.25, { BackgroundTransparency = 1 })
	UIKit.Tween(new("UIScale", { Scale = 1 }, window), 0.2, { Scale = 0.05 })
	task.delay(0.27, function() overlay:Destroy() end)
	State.Encounter = false
	busy = false
end

function EggRouletteUI.Init()
	gui = UIKit.GetGui()
	Net.On("EggRoulette", function(info)
		local ok, err = pcall(EggRouletteUI.Play, info)
		if not ok then
			warn("[EggRouletteUI] " .. tostring(err))
			local left = gui and gui:FindFirstChild("Roulette")
			if left then left:Destroy() end
			State.Encounter = false
			busy = false
		end
	end)
end

return EggRouletteUI
