--[[
	VersusUI  (StarterPlayerScripts.Client.VersusUI)                                             Beta 1.9
	=====================================================================================================
	Toda a interface do DESAFIO 1v1 que é igual para corrida e batalha. O servidor (Services.VersusService)
	decide tudo; aqui só pedimos e mostramos.

	TELAS
	  * Painel "Challenge a Player"  : lista de quem está no servidor (INVITE / BUSY). Aberto pelos botões
	                                   RACE 1v1 e BATTLE do dock (Client.LobbyDock) -> VersusUI.OpenChallenge(modo).
	  * Cartão de convite             : quem foi convidado vê ACCEPT / DECLINE (teclas Y / N) com barra de tempo;
	                                   quem convidou vê "Waiting for <nome>..." com CANCEL.
	  * Faixa da etapa (topo)         : Lobby (READY / LEAVE) -> Vote (cartões de mapa/arena) -> Prep (lojas,
	                                   escolha do lutador, contagem). Some durante o jogo.
	  * Tela de resultado             : vitória/derrota, motivo e recompensas (XP, dinheiro, pontos de spin).
	  * Lojas do Versus Hall          : F1 Shop e Victory Effects (painéis do UIKit) -> VersusUI.OpenShop("F1"|"Fx").
	                                   Também abrem pelos balcões do mapa (ProximityPrompt com a tag "VersusShop").
	  * Escolha do lutador (batalha)  : painel com os personagens do jogador, ordenados por Poder.

	REDE (ver VersusService): VersusPlayers, VersusInvite, VersusRespond, VersusCancel, VersusReady, VersusVote,
	    VersusLeave, GetVersusShop, BuyF1, EquipF1, BuyVictoryFx, EquipVictoryFx, PickFighter (BattleService)
	    eventos: VersusInvited, VersusInviteClosed, VersusState, VersusResult, VersusShop

	PLATAFORMA: a faixa e os cartões usam Platform.Apply("Overlay") (menores no celular); os painéis usam o UIKit.
	IDIOMAS: textos fixos passam pelo UIKit (tradução automática); os montados usam UIKit.T.
	NÃO TESTADO com 2 jogadores reais. Dependências: UIKit, Notify, State, Shared.Config / Net / CarFactory.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local CarFactory = require(Shared.CarFactory)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local new, C, T = UIKit.New, UIKit.C, UIKit.T
local Platform = UIKit.Platform
local lp = Players.LocalPlayer

local VersusUI = {}
local gui
local challengePanel, challengeList, challengeMode = nil, nil, "Race"
local card, cardText, cardBar, cardBtns, cardToken, cardEnds, cardStart = nil, nil, nil, {}, 0, 0, 0
local incomingId -- convite recebido que está na tela
local stage, stageTitle, stageVs, stageTimer, stageBody
local resultFrame
local snap -- último VersusState (nil = sem partida)
local shop = { F1 = { Owned = {}, Equipped = "" }, Fx = { Owned = {}, Equipped = "" } }
local shopPanels = {} -- [kind] = { Panel, Grid }
local pickPanel, pickGrid

local PURPLE = Color3.fromRGB(120, 80, 220)
local function now() return workspace:GetServerTimeNow() end
local function clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
local function round(f, r) new("UICorner", { CornerRadius = UDim.new(0, r or 14) }, f) end

-- ============================================================ cartão de convite (recebido / enviado)
local function hideCard()
	cardToken += 1
	incomingId = nil
	if card then card.Visible = false end
end

-- buttons = { { Text, Color, Fn }, ... } (1 ou 2)
local function showCard(text, endsAt, buttons)
	cardToken += 1
	cardText.Text = text
	cardStart, cardEnds = now(), endsAt
	for i, b in ipairs(cardBtns) do
		local def = buttons[i]
		b.Visible = def ~= nil
		if def then
			UIKit.SetButton(b, def.Text, def.Color, false)
			b:SetAttribute("Slot", i)
		end
	end
	card:SetAttribute("Buttons", #buttons)
	cardBtns[1].Position = (#buttons == 1) and UDim2.new(0.5, 0, 1, -14) or UDim2.new(0.5, -84, 1, -14)
	card.Visible = true
	UIKit.Pop(card, 1.12)
	local token = cardToken
	VersusUI._cardFns = { buttons[1] and buttons[1].Fn, buttons[2] and buttons[2].Fn }
	task.delay(math.max(0, endsAt - now()) + 0.3, function() if cardToken == token then hideCard() end end)
end

local function respond(accept)
	local id = incomingId
	if not id then return end
	hideCard()
	local r = Net.Call("VersusRespond", id, accept)
	if accept and not (r and r.ok) then Notify.Toast(r and r.msg or "The match was cancelled.", "error") end
end

-- ============================================================ painel "Challenge a Player"
local function refreshPlayers()
	if not (challengePanel and challengePanel.IsOpen) then return end
	local r = Net.Call("VersusPlayers")
	if not (r and r.ok) or not challengePanel.IsOpen then return end
	clear(challengeList)
	if #r.List == 0 then
		UIKit.Text(challengeList, { Text = "Nobody else is here yet. Invite a friend to the server!", TextSize = 20, Wrapped = true,
			Color = Color3.fromRGB(190, 190, 210), Size = UDim2.new(1, -12, 0, 90), Stroke = 2, ZIndex = 23 })
		return
	end
	for i, p in ipairs(r.List) do
		local row = new("Frame", { Name = "Player_" .. p.UserId, Size = UDim2.new(1, -12, 0, 58), BackgroundColor3 = C.CardBg, LayoutOrder = i, ZIndex = 22 }, challengeList)
		round(row); UIKit.Stroke(row, 3)
		UIKit.Text(row, { Text = p.Name, TextSize = 22, Scaled = true, AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(1, -176, 0.7, 0),
			Position = UDim2.new(0, 14, 0.15, 0), Stroke = 3, ZIndex = 23 })
		UIKit.Button(row, { Name = "Invite", Text = p.Free and "INVITE" or "BUSY", Size = UDim2.fromOffset(146, 42), Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), Color = p.Free and C.Green or C.Grey, TextSize = 20, ZIndex = 23,
			OnClick = function()
				if not p.Free then return end
				local res = Net.Call("VersusInvite", p.UserId, challengeMode)
				if res and res.ok then
					challengePanel.Close()
					showCard(T("Waiting for %s...", res.Name or p.Name), res.EndsAt or (now() + Config.Versus.InviteSeconds),
						{ { Text = "CANCEL", Color = C.Red, Fn = function() hideCard(); Net.Call("VersusCancel") end } })
				else
					Notify.Toast(res and res.msg or "Couldn't do that.", "error")
					task.spawn(refreshPlayers)
				end
			end })
	end
end

function VersusUI.OpenChallenge(mode)
	if snap then return end -- já está numa partida
	challengeMode = (mode == "Battle") and "Battle" or "Race"
	local title = challengePanel.Header:FindFirstChild("Title")
	if title then UIKit.SetText(title, challengeMode == "Battle" and "⚔️ Battle Challenge" or "🏁 Race Challenge") end
	challengePanel.Header.BackgroundColor3 = challengeMode == "Battle" and C.Red or C.Orange
	challengePanel.Open()
	task.spawn(refreshPlayers)
end

-- ============================================================ lojas (F1 e animações de vitória)
local SHOPS = {
	F1 = { Name = "F1Shop", Title = "🏎️ F1 SHOP", Color = C.Orange, List = Config.F1Cars, Buy = "BuyF1", Equip = "EquipF1", Note = "Formula cars are only for 1v1 races." },
	Fx = { Name = "VictoryShop", Title = "✨ VICTORY SHOP", Color = C.Magenta, List = Config.Battle.VictoryFx, Buy = "BuyVictoryFx", Equip = "EquipVictoryFx" },
}
local SHOP_ERR = { NoCash = "💸 Not enough cash!", Owned = "You already own it." }

local function renderShop(kind)
	local sp, def = shopPanels[kind], SHOPS[kind]
	if not (sp and sp.Panel.IsOpen) then return end
	clear(sp.Grid)
	local st = shop[kind]
	for i, item in ipairs(def.List) do
		local owned, equipped = st.Owned[item.Id] == true, st.Equipped == item.Id
		local f = new("Frame", { Name = item.Id, BackgroundColor3 = C.CardBg, LayoutOrder = i, ZIndex = 22 }, sp.Grid)
		round(f); UIKit.Stroke(f, 3.5, equipped and C.Gold or nil)
		local icon = new("Frame", { Size = UDim2.new(1, -12, 0, 92), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = item.Color or PURPLE, ZIndex = 23 }, f)
		round(icon, 12); UIKit.Stroke(icon, 2.5); UIKit.Gradient(icon, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110))
		if kind == "F1" then
			UIKit.Viewport(icon, CarFactory.Build(item, true), { Dir = Vector3.new(0.8, 0.45, -1), Zoom = 0.9, ZIndex = 24 })
			UIKit.Text(f, { Text = "🚀 " .. item.MaxSpeed .. " km/h", TextSize = 15, Color = Color3.fromRGB(150, 220, 255), Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 124), Stroke = 2.5, ZIndex = 23 })
		else
			UIKit.Text(icon, { Text = item.Icon, TextSize = 58, Stroke = 0, ZIndex = 24 })
		end
		UIKit.Text(f, { Text = item.Name, TextSize = 17, Scaled = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 101), Stroke = 2.5, ZIndex = 23 })
		local text, color = equipped and "EQUIPPED" or "EQUIP", equipped and C.Grey or C.Blue
		if not owned then text, color = (item.Price > 0 and ("$" .. Util.FormatNumber(item.Price)) or "FREE"), C.Green end
		UIKit.Button(f, { Name = "Action", Text = text, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 1, -40), Color = color, TextSize = 18, ZIndex = 24,
			OnClick = function()
				if equipped then return end
				local r = Net.Call(owned and def.Equip or def.Buy, item.Id)
				if not (r and r.ok) then Notify.Toast(SHOP_ERR[r and r.err] or "Couldn't do that.", "error") end
			end })
	end
end

function VersusUI.OpenShop(kind)
	local sp = shopPanels[kind]
	if not sp then return end
	sp.Panel.Open()
	renderShop(kind)
end

local function buildShop(kind)
	local def = SHOPS[kind]
	local p = UIKit.Panel({ Name = def.Name, Title = def.Title, HeaderColor = def.Color, Size = UDim2.fromScale(0.62, 0.78), MaxSize = Vector2.new(690, 520) })
	local top = 0
	if def.Note then
		UIKit.Text(p.Body, { Text = def.Note, TextSize = 16, Color = Color3.fromRGB(190, 190, 210), Size = UDim2.new(1, 0, 0, 22), Stroke = 2, ZIndex = 22 })
		top = 26
	end
	local grid = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -top), Position = UDim2.fromOffset(0, top), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, p.Body)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(150, kind == "F1" and 190 or 172), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3) }, grid)
	shopPanels[kind] = { Panel = p, Grid = grid }
end

-- ============================================================ escolha do lutador (batalha)
local function myFighters()
	local list = table.clone(State.Inventory or {})
	table.sort(list, function(a, b)
		if (a.Power or 0) ~= (b.Power or 0) then return (a.Power or 0) > (b.Power or 0) end
		return a.Uid < b.Uid
	end)
	return list
end
-- Lutador em uso: o escolhido (atributo FighterUid) ou o mais forte.
local function currentFighter()
	local list = myFighters()
	local uid = lp:GetAttribute("FighterUid") or 0
	for _, e in ipairs(list) do if e.Uid == uid then return e end end
	return list[1]
end

local function renderPick()
	if not (pickPanel and pickPanel.IsOpen) then return end
	clear(pickGrid)
	local cur = currentFighter()
	for i, e in ipairs(myFighters()) do
		local cfg = Config.AnimeById[e.Id]
		if cfg then
			local rar = Config.Rarities[cfg.Rarity]
			local selected = cur and cur.Uid == e.Uid
			local b = UIKit.Button(pickGrid, { Name = "Fighter_" .. e.Uid, Text = "", Color = selected and Color3.fromRGB(60, 120, 60) or C.CardBg, Radius = 12, LayoutOrder = i, ZIndex = 22,
				StrokeColor = selected and C.Gold or nil, OnClick = function() Net.Call("PickFighter", e.Uid) end })
			b.Label.Visible = false
			UIKit.Text(b, { Text = cfg.Name, TextSize = 17, Scaled = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 5), Stroke = 2.5, ZIndex = 23 })
			UIKit.Text(b, { Text = rar.Label, TextSize = 13, Color = Config.RarityText(rar), Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 27), Stroke = 2, ZIndex = 23 })
			UIKit.Text(b, { Text = string.rep("★", e.Stars or 0) .. string.rep("☆", Config.Stars.Max - (e.Stars or 0)) .. "  " .. T("Lv %d", e.Level or 1), TextSize = 14,
				Color = C.Gold, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 44), Stroke = 2, ZIndex = 23 })
			UIKit.Text(b, { Text = "⚔️ " .. T("Power") .. " " .. Util.FormatNumber(e.Power or 0), TextSize = 15, Color = Color3.fromRGB(255, 150, 120),
				Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 64), Stroke = 2.5, ZIndex = 23 })
		end
	end
end

-- ============================================================ faixa da etapa (Lobby / Vote / Prep)
local function leave()
	Net.Call("VersusLeave")
end

local function stageButton(text, color, order, onClick, width)
	return UIKit.Button(stageBody, { Text = text, Size = UDim2.fromOffset(width or 150, 46), Color = color, TextSize = 20, LayoutOrder = order, ZIndex = 32, OnClick = onClick })
end

local function renderStage()
	if not stage then return end
	clear(stageBody)
	if not snap or snap.Stage == "Playing" or snap.Stage == "Result" or snap.Stage == "" then
		stage.Visible = false
		return
	end
	local me, foe
	for _, p in ipairs(snap.Players) do if p.UserId == lp.UserId then me = p else foe = p end end
	if not (me and foe) then stage.Visible = false; return end
	local battle = snap.Mode == "Battle"
	local mark = function(p) return (snap.Stage == "Lobby" and p.Ready) and " ✔" or "" end
	stageVs.Text = me.Name .. mark(me) .. "   ⚔️   " .. foe.Name .. mark(foe)
	if snap.Stage == "Lobby" then
		UIKit.SetText(stageTitle, "VERSUS HALL")
		stageButton(me.Ready and "READY ✔" or "READY", me.Ready and C.Grey or C.Green, 1, function() if not me.Ready then Net.Call("VersusReady") end end)
		stageButton(battle and "✨ VICTORY SHOP" or "🏎️ F1 SHOP", battle and C.Magenta or C.Orange, 2, function() VersusUI.OpenShop(battle and "Fx" or "F1") end, 190)
		stageButton("LEAVE", C.Red, 3, leave, 110)
	elseif snap.Stage == "Vote" then
		UIKit.SetText(stageTitle, battle and "VOTE FOR THE ARENA" or "VOTE FOR THE MAP")
		for i, map in ipairs(snap.Maps or {}) do
			local mine = me.Vote == map.Id
			stageButton((map.Icon or "") .. " " .. map.Name, mine and C.Green or PURPLE, i, function() Net.Call("VersusVote", map.Id) end, 200)
		end
	elseif snap.Stage == "Prep" then
		UIKit.SetText(stageTitle, "GET READY!")
		stageVs.Text = stageVs.Text .. "\n" .. T("Map chosen: %s", snap.Map and ((snap.Map.Icon or "") .. " " .. snap.Map.Name) or "?")
		if battle then
			local f = currentFighter()
			local cfg = f and Config.AnimeById[f.Id]
			stageButton(cfg and ("🥋 " .. cfg.Name) or "Pick your fighter", C.Blue, 1, function() pickPanel.Open(); renderPick() end, 210)
			stageButton("✨ VICTORY SHOP", C.Magenta, 2, function() VersusUI.OpenShop("Fx") end, 190)
		else
			local car = Config.F1ById[shop.F1.Equipped] or Config.F1Cars[1]
			stageButton("🏎️ " .. car.Name, C.Orange, 1, function() VersusUI.OpenShop("F1") end, 210)
			stageButton("✨ VICTORY SHOP", C.Magenta, 2, function() VersusUI.OpenShop("Fx") end, 190)
		end
		stageButton("LEAVE", C.Red, 3, leave, 110)
	end
	if not stage.Visible then stage.Visible = true; UIKit.Pop(stage, 1.08) end
end

-- ============================================================ resultado
local REASON_ICON = { ["Finished first"] = "🏁", ["Caught by the collapse"] = "🔥", ["Went the farthest"] = "📏" }
local function showResult(info)
	if type(info) ~= "table" then return end
	for _, pnl in pairs(UIKit.Panels) do if pnl.IsOpen then pnl.Close() end end
	clear(resultFrame)
	local win = info.WinnerUserId == lp.UserId
	local draw = (info.WinnerUserId or 0) == 0
	local color = draw and C.Grey or (win and C.Gold or C.Red)
	local st = resultFrame:FindFirstChildOfClass("UIStroke"); if st then st.Color = color end
	UIKit.Text(resultFrame, { Text = draw and "The match was cancelled." or (win and "🏆 YOU WIN!" or "💥 YOU LOSE"), TextSize = 46, Color = color,
		Size = UDim2.new(1, -20, 0, 56), Position = UDim2.fromOffset(10, 10), Scaled = true, Stroke = 5, ZIndex = 42 })
	local reason = info.Reason or ""
	local sub = (REASON_ICON[reason] or "") .. " " .. T(reason)
	if not draw and info.WinnerName ~= "" then
		sub = T(info.Mode == "Battle" and "%s wins the battle!" or "%s wins the race!", info.WinnerName) .. "   " .. sub
	end
	UIKit.Text(resultFrame, { Text = sub, TextSize = 19, Scaled = true, Color = Color3.fromRGB(225, 225, 240), Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 68), Stroke = 3, ZIndex = 42 })
	-- distâncias da corrida (do servidor)
	local y = 100
	local d = info.Details and info.Details.Distances
	if d and snap then
		local parts = {}
		for _, p in ipairs(snap.Players) do parts[#parts + 1] = p.Name .. ": " .. T("%s m", Util.FormatNumber(d[tostring(p.UserId)] or 0)) end
		UIKit.Text(resultFrame, { Text = "📏 " .. table.concat(parts, "   •   "), TextSize = 17, Scaled = true, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, y), Stroke = 2.5, ZIndex = 42 })
		y += 28
	end
	local box = new("Frame", { Size = UDim2.new(1, -28, 0, 132), Position = UDim2.fromOffset(14, y + 4), BackgroundColor3 = C.CardBg, ZIndex = 42 }, resultFrame)
	round(box); UIKit.Stroke(box, 3)
	new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, box)
	local function line(text, c, order, size)
		UIKit.Text(box, { Text = text, TextSize = size or 22, Scaled = true, Color = c, Size = UDim2.new(1, -16, 0, (size or 22) + 6), LayoutOrder = order, Stroke = 3, ZIndex = 43 })
	end
	local rw = info.Rewards
	line(T("Rewards"), Color3.fromRGB(200, 200, 220), 0, 16)
	if rw then
		if rw.XP and rw.XP.Name then
			line(T("+%d XP for %s", rw.XP.Amount or 0, rw.XP.Name) .. ((rw.XP.LevelsGained or 0) > 0 and ("   ⬆️ " .. T("Lv %d", rw.XP.Level or 1)) or ""), Color3.fromRGB(110, 200, 255), 1)
		end
		if (rw.Cash or 0) > 0 then line(T("+$%s", Util.FormatNumber(rw.Cash)), C.Cash, 2) end
		if (rw.SpinPoints or 0) > 0 then line("🎟️ " .. T("+%d spin points", rw.SpinPoints), Color3.fromRGB(210, 150, 255), 3) end
		if rw.Full == false then line(T("Play each other too many times and only XP is rewarded."), Color3.fromRGB(255, 190, 120), 4, 14) end
	else
		line("—", C.Grey, 1)
	end
	UIKit.Button(resultFrame, { Text = "BACK TO LOBBY", Size = UDim2.fromOffset(220, 44), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Green, TextSize = 20, ZIndex = 43, OnClick = function() resultFrame.Visible = false end })
	resultFrame.Visible = true
	UIKit.Pop(resultFrame, 1.15)
	if win then
		local fxIcon = "🎉"
		for _, fx in ipairs(Config.Battle.VictoryFx) do if fx.Id == info.WinnerFx then fxIcon = fx.Icon end end
		UIKit.Confetti(gui, C.Gold, 70)
		UIKit.FloatText(resultFrame, fxIcon .. " " .. fxIcon .. " " .. fxIcon, C.Gold, UDim2.new(0.5, -60, 0, -6), 40)
		UIKit.PlaySound("Rare")
	end
	task.delay((info.Seconds or Config.Versus.ResultSeconds) + 0.5, function() resultFrame.Visible = false end)
end

-- ============================================================ init
function VersusUI.Init()
	gui = UIKit.GetGui()

	-- painel de desafio
	challengePanel = UIKit.Panel({ Name = "Versus", Title = "Challenge a Player", HeaderColor = C.Orange, Size = UDim2.fromScale(0.46, 0.7), MaxSize = Vector2.new(520, 470) })
	challengeList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, challengePanel.Body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, challengeList)
	new("UIPadding", { PaddingTop = UDim.new(0, 4) }, challengeList)
	task.spawn(function() -- lista atualizada enquanto o painel estiver aberto
		while true do task.wait(3); if challengePanel.IsOpen then pcall(refreshPlayers) end end
	end)

	buildShop("F1"); buildShop("Fx")
	pickPanel = UIKit.Panel({ Name = "FighterPick", Title = "Pick your fighter", HeaderColor = C.Blue, Size = UDim2.fromScale(0.62, 0.74), MaxSize = Vector2.new(690, 480) })
	pickGrid = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, pickPanel.Body)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(156, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pickGrid)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }, pickGrid)

	-- cartão de convite (topo da tela, abaixo dos avisos)
	card = new("Frame", { Name = "VersusCard", Size = UDim2.fromOffset(430, 142), Position = UDim2.new(0.5, 0, 0, 118), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.PanelBg, Visible = false, ZIndex = 60 }, gui)
	round(card, 18); UIKit.Stroke(card, 4.5, C.Gold)
	Platform.Apply(card, "Overlay")
	cardText = UIKit.Text(card, { Name = "Text", Text = "", TextSize = 24, Scaled = true, Wrapped = true, Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 8), Stroke = 3.5, ZIndex = 61 })
	local track = new("Frame", { Size = UDim2.new(1, -40, 0, 8), Position = UDim2.fromOffset(20, 66), BackgroundColor3 = Color3.fromRGB(40, 36, 60), ZIndex = 61 }, card)
	round(track, 4)
	cardBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 62 }, track)
	round(cardBar, 4)
	for i = 1, 2 do
		cardBtns[i] = UIKit.Button(card, { Name = "Btn" .. i, Text = "", Size = UDim2.fromOffset(156, 46), Position = UDim2.new(0.5, i == 1 and -84 or 84, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1), TextSize = 22, ZIndex = 62,
			OnClick = function() local fn = VersusUI._cardFns and VersusUI._cardFns[i]; if fn then fn() end end })
	end

	-- faixa da etapa
	stage = new("Frame", { Name = "VersusStage", Size = UDim2.fromOffset(640, 168), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.PanelBg, BackgroundTransparency = 0.08, Visible = false, ZIndex = 30 }, gui)
	round(stage, 18); UIKit.Stroke(stage, 4, PURPLE)
	Platform.Apply(stage, "Overlay")
	stageTitle = UIKit.Text(stage, { Name = "Title", Text = "VERSUS HALL", TextSize = 28, Color = C.Gold, Size = UDim2.new(1, -150, 0, 32), Position = UDim2.fromOffset(16, 6),
		AlignX = Enum.TextXAlignment.Left, Scaled = true, Stroke = 4, ZIndex = 31 })
	stageTimer = UIKit.Text(stage, { Name = "Timer", Text = "", TextSize = 30, Color = Color3.fromRGB(120, 220, 255), Size = UDim2.fromOffset(120, 32), Position = UDim2.new(1, -16, 0, 6),
		AnchorPoint = Vector2.new(1, 0), AlignX = Enum.TextXAlignment.Right, Stroke = 4, ZIndex = 31 })
	stageVs = UIKit.Text(stage, { Name = "Versus", Text = "", TextSize = 20, Scaled = true, Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 40), Stroke = 3, ZIndex = 31 })
	stageBody = new("Frame", { Name = "Body", Size = UDim2.new(1, -16, 0, 58), Position = UDim2.new(0, 8, 1, -66), BackgroundTransparency = 1, ZIndex = 31 }, stage)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, stageBody)

	-- resultado
	resultFrame = new("Frame", { Name = "VersusResult", Size = UDim2.fromOffset(500, 330), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.PanelBg, Visible = false, ZIndex = 41 }, gui)
	round(resultFrame, 20); UIKit.Stroke(resultFrame, 5, C.Gold)
	Platform.Apply(resultFrame, "Panel")

	-- relógios (barra do convite e contagem da etapa)
	RunService.RenderStepped:Connect(function()
		if card.Visible and cardEnds > cardStart then
			cardBar.Size = UDim2.fromScale(math.clamp((cardEnds - now()) / (cardEnds - cardStart), 0, 1), 1)
		end
		if stage.Visible and snap then
			stageTimer.Text = snap.EndsAt and tostring(math.max(0, math.ceil(snap.EndsAt - now()))) or ""
		end
	end)

	-- eventos do servidor
	Net.On("VersusInvited", function(info)
		if type(info) ~= "table" then return end
		incomingId = info.Id
		local id = info.Id
		showCard(T(info.Mode == "Battle" and "%s challenged you to a BATTLE!" or "%s challenged you to a RACE!", tostring(info.FromName)), info.EndsAt or (now() + Config.Versus.InviteSeconds), {
			{ Text = "ACCEPT", Color = C.Green, Fn = function() respond(true) end },
			{ Text = "DECLINE", Color = C.Red, Fn = function() respond(false) end },
		})
		incomingId = id -- (showCard não limpa, mas deixa explícito)
		UIKit.PlaySound("Reveal")
	end)
	Net.On("VersusInviteClosed", function() hideCard() end)
	Net.On("VersusState", function(s)
		snap = (type(s) == "table") and s or nil
		if snap then
			hideCard()
			if challengePanel.IsOpen then challengePanel.Close() end
			if snap.Stage == "Playing" then for _, pnl in pairs(UIKit.Panels) do if pnl.IsOpen then pnl.Close() end end end
		end
		renderStage()
	end)
	Net.On("VersusResult", function(info) task.spawn(showResult, info) end)
	Net.On("VersusShop", function(s)
		if type(s) ~= "table" then return end
		for kind in pairs(shop) do if type(s[kind]) == "table" then shop[kind] = { Owned = s[kind].Owned or {}, Equipped = s[kind].Equipped or "" } end end
		renderShop("F1"); renderShop("Fx"); renderStage()
	end)
	task.spawn(function() Net.Call("GetVersusShop") end)

	lp:GetAttributeChangedSignal("FighterUid"):Connect(function() renderPick(); renderStage() end)
	State.Changed.Event:Connect(function(what) if what == "Inventory" then renderPick() end end)
	UIKit.Locale.OnChanged(function() renderStage(); renderShop("F1"); renderShop("Fx"); renderPick() end)

	-- teclado: Y aceita, N recusa (o controle usa os botões, que são selecionáveis)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not incomingId then return end
		if input.KeyCode == Enum.KeyCode.Y then respond(true) elseif input.KeyCode == Enum.KeyCode.N then respond(false) end
	end)

	-- balcões do Versus Hall
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("ShopKind")
		if kind == "F1" or kind == "Fx" then VersusUI.OpenShop(kind) end
	end)
end

return VersusUI
