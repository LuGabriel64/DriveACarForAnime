--[[
	RaceUI (Beta 1.2): tudo que o jogador vê da corrida.
	  * Botão 🏁 RACE (no lobby) e PORTAL DE CORRIDA (peça com tag "RacePortal"): entrar nele, de carro
	    ou a pé, chama "StartRace" no servidor.
	  * Contagem 3-2-1-GO sincronizada com o relógio do servidor + luzes do pórtico ficam verdes no GO.
	  * Painel ao vivo: cronômetro, distância e recorde.
	  * Tela de resultados (RaceEnded): distância, tempo, ovos chocados, recorde (confete se for novo),
	    botões RACE AGAIN e OK.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local Drive = require(script.Parent.DriveController)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local RaceUI = {}
local gui, panel, timerL, distL, bestL, raceBtn, results
local startClock = nil
local starting = false

local ERR = {
	NoGarage = "🏁 Choose a garage first!", Full = "⏳ All race slots are busy, try again in a moment!",
	AlreadyRacing = "You're already racing!", Dead = "Wait to respawn!",
}

local function fmtTime(t)
	t = math.max(0, t)
	return string.format("%02d:%04.1f", math.floor(t / 60), t % 60)
end

function RaceUI.Start()
	if starting or (lp:GetAttribute("RaceState") or "Lobby") ~= "Lobby" then return end
	starting = true
	local r = Net.Call("StartRace")
	if r and not r.ok then Notify.Toast(ERR[r.err] or "Couldn't start the race.", "error") end
	task.delay(2.5, function() starting = false end)
end

-- ---------------------------------------------------------------- contagem
local function startLights(color)
	local sl = workspace:FindFirstChild("Map") and workspace.Map.Structures:FindFirstChild("StartLine")
	if not sl then return end
	for _, p in ipairs(sl:GetChildren()) do if p.Name == "StartLight" then p.Color = color end end
end

local function countdown(info)
	startClock = nil
	startLights(Color3.fromRGB(255, 60, 60))
	local overlay = new("Frame", { Name = "Countdown", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 45 }, gui)
	local big = UIKit.Text(overlay, { Text = "", TextSize = 150, Size = UDim2.fromOffset(500, 170), Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 9, ZIndex = 46 })
	local sub = UIKit.Text(overlay, { Text = info.Mode == "Duel" and UIKit.T("🏁 1v1 RACE") or UIKit.T("SLOT %d  •  SOLO RACE", info.Slot), -- Beta 1.9: corrida 1v1 TextSize = 26, Size = UDim2.fromOffset(500, 34),
		Position = UDim2.new(0.5, 0, 0.38, 100), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = 46 })
	local colors = { [3] = Color3.fromRGB(255, 80, 80), [2] = Color3.fromRGB(255, 190, 40), [1] = Color3.fromRGB(255, 240, 80) }
	local last
	while true do
		local left = info.GoAt - workspace:GetServerTimeNow()
		if left <= 0 then break end
		local n = math.ceil(left)
		if n ~= last then
			last = n
			big.Text = tostring(n); big.TextColor3 = colors[n] or C.White
			UIKit.Pop(big, 1.6)
			UIKit.PlaySound("Click")
		end
		task.wait(0.05)
	end
	big.Text = "GO!"; big.TextColor3 = C.Cash; sub.Visible = false
	UIKit.Pop(big, 1.8)
	startLights(Color3.fromRGB(80, 255, 90))
	startClock = os.clock()
	task.delay(0.9, function()
		local tw = UIKit.Tween(big, 0.35, { TextTransparency = 1 })
		tw.Completed:Connect(function() overlay:Destroy() end)
	end)
end

-- ---------------------------------------------------------------- resultados
local function showResults(s)
	startClock = nil
	startLights(Color3.fromRGB(255, 60, 60))
	local body = results.Body
	for _, c in ipairs(body:GetChildren()) do c:Destroy() end
	local reasonText = ({ finish = "🏆 YOU REACHED THE END!", respawn = "💥 Race over", home = "🏝️ Back to the lobby",
		delivered = "🥚 EGG SECURED! It's hatching at your base", caught = "💥 The collapse caught you — egg lost!",
		invalid = "⚠️ Impossible speed — race cancelled" })[s.Reason] or "Race over" -- Beta 1.8d: + invalid (RaceService)
	UIKit.Text(body, { Text = reasonText, TextSize = 26, Size = UDim2.new(1, 0, 0, 32), Stroke = 3, ZIndex = 22 })
	local function stat(y, icon, label, value, color)
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, y), BackgroundColor3 = C.CardBg, ZIndex = 22 }, body)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, f); UIKit.Stroke(f, 3)
		UIKit.Text(f, { Text = icon .. "  " .. UIKit.T(label), TextSize = 22, AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(16, 0), Stroke = 2.5, ZIndex = 23 })
		UIKit.Text(f, { Text = value, TextSize = 26, Color = color or C.White, AlignX = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -16, 1, 0), Position = UDim2.fromScale(0.6, 0), Stroke = 3, ZIndex = 23 })
	end
	stat(42, "📏", "Distance", Util.FormatNumber(s.Distance) .. " m", C.Cash)
	stat(104, "⏱️", "Time", fmtTime(s.Time), Color3.fromRGB(120, 220, 255))
	stat(166, "🥚", "Eggs hatched", tostring(s.Hatched), C.Gold)
	stat(228, "🏆", "Best", Util.FormatNumber(s.Best) .. " m", Color3.fromRGB(255, 150, 230))
	local nextY = 292
	if s.Reward and s.Reward > 0 then stat(290, "💵", "Reward", "+$" .. Util.FormatNumber(s.Reward), C.Cash); nextY = 354 end
	if s.NewRecord and s.Distance > 0 then
		local rec = UIKit.Text(body, { Text = "✨ NEW RECORD! ✨", TextSize = 34, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, nextY), Stroke = 4, ZIndex = 24 })
		UIKit.Rainbow(rec); UIKit.Pop(rec, 1.5)
		UIKit.Confetti(gui, C.Gold, 50)
	end
	UIKit.Button(body, { Text = "🏁 RACE AGAIN", Size = UDim2.new(0.5, -6, 0, 54), Position = UDim2.new(0, 0, 1, -56), Color = C.Orange, TextSize = 26, ZIndex = 23,
		OnClick = function() results.Close(); RaceUI.Start() end })
	UIKit.Button(body, { Text = "OK", Size = UDim2.new(0.5, -6, 0, 54), Position = UDim2.new(0.5, 6, 1, -56), Color = C.Green, TextSize = 26, ZIndex = 23,
		OnClick = function() results.Close() end })
	results.Open()
end

-- ---------------------------------------------------------------- init
function RaceUI.Init()
	gui = UIKit.GetGui()
	local hud = gui:WaitForChild("HUD", 10)

	-- painel ao vivo (abaixo da pílula do bioma)
	panel = new("Frame", { Name = "RacePanel", Size = UDim2.fromOffset(420, 40), Position = UDim2.new(0.5, 0, 0, 48), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(14, 14, 22), BackgroundTransparency = 0.15, Visible = false }, hud)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, panel); UIKit.Stroke(panel, 3)
	UIKit.Platform.Apply(panel, "Overlay") -- Beta 1.9: menor no celular, maior na TV
	local row = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, panel)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 18) }, row)
	timerL = UIKit.Text(row, { Text = "⏱ 00:00.0", TextSize = 22, Size = UDim2.fromOffset(120, 30), Color = Color3.fromRGB(120, 220, 255), Stroke = 2.5, LayoutOrder = 1 })
	distL = UIKit.Text(row, { Text = "📏 0 m", TextSize = 22, Size = UDim2.fromOffset(120, 30), Color = C.Cash, Stroke = 2.5, LayoutOrder = 2 })
	bestL = UIKit.Text(row, { Text = "🏆 0 m", TextSize = 22, Size = UDim2.fromOffset(120, 30), Color = Color3.fromRGB(255, 150, 230), Stroke = 2.5, LayoutOrder = 3 })

	-- botão RACE (lobby) — acima do DRIVE
	raceBtn = UIKit.Button(hud, { Name = "Race", Text = "🏁 RACE", Size = UDim2.fromOffset(170, 74), Position = UDim2.new(1, -16, 0.5, -48),
		AnchorPoint = Vector2.new(1, 0.5), Color = C.Orange, TextSize = 34, Radius = 18, StrokeThickness = 4, OnClick = RaceUI.Start })
	UIKit.Shine(raceBtn, 1.8)

	results = UIKit.Panel({ Name = "RaceResults", Title = "🏁 Race Results", HeaderColor = C.Orange, Size = UDim2.fromScale(0.42, 0.8), MaxSize = Vector2.new(480, 560), MinSize = Vector2.new(360, 520) })

	local function onState()
		local st = lp:GetAttribute("RaceState") or "Lobby"
		raceBtn.Visible = st == "Lobby" and not Config.Features.LobbyDock -- Beta 1.4: o PLAY do dock substitui
		panel.Visible = st ~= "Lobby" and lp:GetAttribute("RaceMode") ~= "Duel" -- Beta 1.9: no 1v1 quem mostra é o placar do DuelRaceUI
		if st ~= "Lobby" then UIKit.Pop(panel, 1.1) end
	end
	lp:GetAttributeChangedSignal("RaceState"):Connect(onState)
	onState()

	Net.On("RaceCountdown", function(info) task.spawn(countdown, info) end)
	Net.On("RaceEnded", function(s)
		-- Beta 1.9: a corrida 1v1 tem a própria tela de resultado (Client.VersusUI); aqui só zera o cronômetro
		if type(s) == "table" and s.Mode == "Duel" then startClock = nil; return end
		task.spawn(showResults, s)
	end)

	-- atualiza o painel e verifica o PORTAL (entrar nele inicia a corrida)
	RunService.Heartbeat:Connect(function()
		local st = lp:GetAttribute("RaceState") or "Lobby"
		if st ~= "Lobby" then
			timerL.Text = "⏱ " .. fmtTime(startClock and (os.clock() - startClock) or 0)
			distL.Text = "📏 " .. Util.FormatNumber(lp:GetAttribute("RaceDistance") or 0) .. " m"
			bestL.Text = "🏆 " .. Util.FormatNumber(lp:GetAttribute("RaceBest") or 0) .. " m"
			return
		end
		if starting then return end
		if (lp:GetAttribute("MatchId") or 0) ~= 0 then return end -- Beta 1.9: em desafio 1v1 o portal não inicia corrida solo
		local pos
		if Drive.IsDriving() then pos = Drive.GetPosition() else
			local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			pos = root and root.Position
		end
		if not pos then return end
		for _, pad in ipairs(CollectionService:GetTagged("RacePortal")) do
			local flat = Vector3.new(pos.X - pad.Position.X, 0, pos.Z - pad.Position.Z)
			if flat.Magnitude < Config.Lobby.PortalRadius and math.abs(pos.Y - pad.Position.Y) < 14 then
				RaceUI.Start()
				break
			end
		end
	end)
end

return RaceUI
