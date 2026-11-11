--[[
	WheelService (Beta 1.5 -> 1.7): ROLETA DA SORTE.
	  * 1 giro GRÁTIS a cada Config.Wheel.Cooldown (8 h) + giros EXTRAS (data.Wheel.Tokens).
	  * Tokens vêm de pacotes x3 / x10 comprados com ROBUX (Developer Products, Config.Wheel.Packs[i].ProductId)
	    ou do prêmio "+2 Spins" da própria roda.

	REGRAS (tudo decidido AQUI no servidor; o cliente só anima)
	  * Tempo: data.Wheel.LastSpin = os.time() do último giro GRÁTIS (vai para o DataStore => conta offline).
	    Grátis liberado em LastSpin + Cooldown. O relógio do cliente NUNCA é usado.
	  * Ordem de uso: se o grátis está pronto ele é usado primeiro; senão gasta 1 Token; senão "Cooldown".
	  * Sem giro duplo: o handler não faz yield entre conferir e gravar + rate-limit do Net + "spinning" (não aceita
	    outro giro enquanto a roda do jogador ainda está girando).
	  * Sorteio ponderado (Random do servidor) por Config.Wheel.Prizes[i].Weight — prêmios maiores = peso menor.
	  * Prêmio fica PENDENTE (Pending = Cash, PendingSpins = giros) e é entregue quando a roda para (SpinSeconds)
	    ou no próximo login se o jogador sair antes. O perfil é salvo na hora do giro.
	  * ROBUX: MarketplaceService.ProcessReceipt (ÚNICO no jogo — nenhum outro script deve definir). Idempotente:
	    PurchaseId já entregue => PurchaseGranted sem dar de novo. Só confirma depois de SALVAR (DataService.SaveSync).

	REDE: "GetWheel" -> { ok, NextAt, Now, Tokens } | "SpinWheel" -> { ok, Index, Cash, Spins, Used, NextAt, Now } | { ok=false, err }
	ATRIBUTOS do Player: WheelNextAt (hora UNIX do próximo grátis), WheelTokens (giros extras)
	DEPENDÊNCIAS: DataService, Config.Wheel
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)

local WheelService = {}
local WC = Config.Wheel
local rng = Random.new()
local spinningUntil = {} -- [player] = os.clock() em que a roda dele para

local function wheelData(data)
	data.Wheel = data.Wheel or {}
	local w = data.Wheel
	w.LastSpin = w.LastSpin or 0; w.Spins = w.Spins or 0; w.Pending = w.Pending or 0
	w.Tokens = w.Tokens or 0; w.PendingSpins = w.PendingSpins or 0; w.Receipts = w.Receipts or {}
	return w
end
local function nextAt(data) return wheelData(data).LastSpin + WC.Cooldown end
local function push(player, data)
	local w = wheelData(data)
	player:SetAttribute("WheelNextAt", nextAt(data))
	player:SetAttribute("WheelTokens", w.Tokens)
end

local function roll()
	local total = 0
	for _, p in ipairs(WC.Prizes) do total += p.Weight end
	local r, acc = rng:NextNumber() * total, 0
	for i, p in ipairs(WC.Prizes) do
		acc += p.Weight
		if r < acc then return i end
	end
	return #WC.Prizes
end

local function payPending(player)
	local data = DataService.Get(player)
	if not data then return end
	local w = wheelData(data)
	local cash, spins = w.Pending, w.PendingSpins
	if cash > 0 then w.Pending = 0; DataService.AddCash(player, cash) end
	if spins > 0 then w.PendingSpins = 0; w.Tokens += spins end
	push(player, data)
end

local packByProduct = {}
for _, pk in ipairs(WC.Packs or {}) do if (pk.ProductId or 0) > 0 then packByProduct[pk.ProductId] = pk end end

local function processReceipt(info)
	local pack = packByProduct[info.ProductId]
	if not pack then
		warn("[WheelService] ProcessReceipt: produto desconhecido " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and DataService.Get(player)
	if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end -- entrega quando ele voltar
	local w = wheelData(data)
	for _, id in ipairs(w.Receipts) do
		if id == info.PurchaseId then return Enum.ProductPurchaseDecision.PurchaseGranted end -- já entregue
	end
	w.Tokens += pack.Spins
	table.insert(w.Receipts, info.PurchaseId)
	while #w.Receipts > 50 do table.remove(w.Receipts, 1) end
	push(player, data)
	if not DataService.SaveSync(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- o Roblox tenta de novo; o Receipt já anotado evita dar 2x
	end
	Net.Fire(player, "Toast", ("🎟️ +%d spins added to your Lucky Wheel!"):format(pack.Spins), "good")
	print(("[WheelService] %s comprou %s (+%d giros) | PurchaseId %s"):format(player.Name, pack.Key, pack.Spins, info.PurchaseId))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function WheelService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	DataService.OnLoaded(function(player, data)
		local w = wheelData(data)
		if w.LastSpin > os.time() then w.LastSpin = os.time() end -- nada de "tempo no futuro"
		payPending(player) -- prêmio de um giro interrompido (saiu antes da roda parar)
		push(player, data)
	end)
	Players.PlayerRemoving:Connect(function(p) spinningUntil[p] = nil end)

	Net.Handle("GetWheel", function(player)
		local data = DataService.Get(player)
		if not data then return { ok = false, err = "NoData" } end
		return { ok = true, NextAt = nextAt(data), Now = os.time(), Tokens = wheelData(data).Tokens }
	end, 0.5)

	Net.Handle("SpinWheel", function(player)
		local data = DataService.Get(player)
		if not data then return { ok = false, err = "NoData" } end
		if spinningUntil[player] and os.clock() < spinningUntil[player] then return { ok = false, err = "Spinning" } end
		local w = wheelData(data)
		local now = os.time()
		local used
		if now >= nextAt(data) then
			used = "Free"; w.LastSpin = now
		elseif w.Tokens > 0 then
			used = "Token"; w.Tokens -= 1
		else
			return { ok = false, err = "Cooldown", NextAt = nextAt(data), Now = now }
		end
		w.Spins += 1
		local index = roll()
		local prize = WC.Prizes[index]
		w.Pending += prize.Cash or 0
		w.PendingSpins += prize.Spins or 0
		push(player, data)
		DataService.SaveNow(player)
		local secs = WC.SpinSeconds or 5
		spinningUntil[player] = os.clock() + secs - 0.3
		task.delay(secs, function() if player.Parent then payPending(player) end end)
		print(("[WheelService] %s girou (%s): %s (giro #%d, extras restantes %d)"):format(player.Name, used, prize.Label, w.Spins, w.Tokens))
		return { ok = true, Index = index, Cash = prize.Cash or 0, Spins = prize.Spins or 0, Used = used, NextAt = nextAt(data), Now = now }
	end, 1)

	Net.Handle("WheelPack", function(player, key)
		if type(key) ~= "string" then return { ok = false, err = "Invalid" } end
		for _, pk in ipairs(WC.Packs or {}) do
			if pk.Key == key then
				if (pk.ProductId or 0) <= 0 then return { ok = false, err = "Soon" } end
				MarketplaceService:PromptProductPurchase(player, pk.ProductId)
				return { ok = true }
			end
		end
		return { ok = false, err = "Invalid" }
	end, 1)
end

return WheelService
