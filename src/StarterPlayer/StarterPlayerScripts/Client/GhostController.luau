--[[
	GhostController (Beta 1.2): o lado "cliente" da PISTA FANTASMA.
	Regra: se EU estou correndo, ou o OUTRO jogador está correndo, eu não vejo o outro (corpo, carro,
	nome e faróis). No lobby, todos se veem normalmente. A física já não colide (grupos de colisão
	"Characters"/"Cars" no RaceService) — aqui é só o visual. Usa LocalTransparencyModifier, que
	afeta apenas a tela deste jogador.
]]
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local Ghost = {}

local function isRacing(p) return (p:GetAttribute("RaceState") or "Lobby") ~= "Lobby" end

local function setHidden(container, hidden)
	if not container then return end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then
			if hidden then
				if d:GetAttribute("GhostWasEnabled") == nil then d:SetAttribute("GhostWasEnabled", d.Enabled) end
				d.Enabled = false
			elseif d:GetAttribute("GhostWasEnabled") ~= nil then
				d.Enabled = d:GetAttribute("GhostWasEnabled")
				d:SetAttribute("GhostWasEnabled", nil)
			end
		end
	end
	local hum = container:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = hidden and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer end
end

local function refresh()
	local cars = workspace:FindFirstChild("Cars")
	local meRacing = isRacing(lp)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp then
			-- Beta 1.9: adversários do MESMO desafio 1v1 (mesmo MatchId ~= 0) se veem; os carros continuam sem colidir
			local myMatch = lp:GetAttribute("MatchId") or 0
			local sameMatch = myMatch ~= 0 and (p:GetAttribute("MatchId") or 0) == myMatch
			local hide = (meRacing or isRacing(p)) and not sameMatch
			setHidden(p.Character, hide)
			setHidden(cars and cars:FindFirstChild("Car_" .. p.Name), hide)
		end
	end
end

function Ghost.Init()
	lp:GetAttributeChangedSignal("RaceState"):Connect(refresh)
	-- loop leve (até 8 jogadores): pega carros/personagens que nasceram depois e mudanças de estado dos outros
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return Ghost
