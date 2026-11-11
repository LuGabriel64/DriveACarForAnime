--[[
	HazardController (Beta 1.8): anima os OBSTÁCULOS da pista e detecta as batidas do SEU carro.
	  * Obstáculos = Models com tag "Hazard" (WorldBuilder.BuildHazards). Atributos: Kind, Period, Phase, Origin (+ PivotH,
	    Amp, Reach, Duty, JetH). Peças que mexem: atributo Move + Rel. Peças que machucam: atributo Hit.
	  * POSE = função de workspace:GetServerTimeNow() => todos os jogadores veem o obstáculo na mesma posição,
	    sem rede. Só anima o que está a menos de ANIM_DIST da câmera (celular agradece).
	  * BATIDA: testa o TRAJETO do carro entre dois frames (segmento x caixa da peça + margem do carro) => carro a
	    500 studs/s não atravessa o obstáculo sem contar. Laser só machuca LIGADO; jato do gêiser só quando alto.
	    Bateu => Drive.Hit(direção): freia (Config.Track.Hazards.SpeedMult por Duration s) + empurrão, tela pisca
	    vermelho e "💥 OUCH!". As peças têm CanCollide = false: a física do carro nunca prende no obstáculo.
	  * Com StreamingEnabled os modelos (Atomic) entram/saem pelos sinais da tag.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent.UIKit)
local Drive = require(script.Parent.DriveController)
local new = UIKit.New
local lp = Players.LocalPlayer

local HazardController = {}
local HZ = Config.Track.Hazards or {}
local ANIM_DIST = 520
local HIT_DIST = 90
local MARGIN = Vector3.new(3.4, 2.4, 3.4) -- meia largura/altura/comprimento aproximada do carro
local TAU = math.pi * 2
local hazards = {}
local prevPos
local flash, ouch

local function register(m)
	if not m:IsA("Model") or hazards[m] then return end
	local origin = m:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then return end
	local d = { Model = m, Kind = m:GetAttribute("Kind"), Period = m:GetAttribute("Period") or 3, Phase = m:GetAttribute("Phase") or 0,
		Origin = origin, Movers = {}, Hits = {}, Active = {} }
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local role = p:GetAttribute("Move")
			if role then
				table.insert(d.Movers, { Part = p, Rel = p:GetAttribute("Rel") or CFrame.new(), Role = role, Delay = p:GetAttribute("Delay") or 0, Size = p.Size })
			end
			if p:GetAttribute("Hit") then table.insert(d.Hits, p); d.Active[p] = true end
		end
	end
	hazards[m] = d
end
local function unregister(m) hazards[m] = nil end

local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- pose de um obstáculo no tempo t
local function animate(d, t)
	local ph = (t / d.Period + d.Phase) % 1
	local m, O = d.Model, d.Origin
	if d.Kind == "pendulum" then
		local ang = math.rad(m:GetAttribute("Amp") or 60) * math.sin(TAU * ph)
		local pivot = O * CFrame.new(0, m:GetAttribute("PivotH") or 29, 0) * CFrame.Angles(0, 0, ang)
		for _, mv in ipairs(d.Movers) do mv.Part.CFrame = pivot * mv.Rel end
	elseif d.Kind == "sweeper" then
		local spin = O * CFrame.Angles(0, TAU * ph, 0)
		for _, mv in ipairs(d.Movers) do mv.Part.CFrame = spin * mv.Rel end
	elseif d.Kind == "piston" then
		local reach = m:GetAttribute("Reach") or 28
		local s = math.sin(TAU * ph)
		local eL, eR = smoothstep(s * 1.5), smoothstep(-s * 1.5)
		for _, mv in ipairs(d.Movers) do
			local dx = (mv.Role == "pistonL") and (eL * reach) or (-eR * reach)
			mv.Part.CFrame = O * CFrame.new(dx, 0, 0) * mv.Rel
		end
	elseif d.Kind == "laser" then
		local duty = m:GetAttribute("Duty") or 0.5
		local on = ph < duty
		local warn = (not on) and ph > 0.86 -- pisca antes de ligar
		local tr = on and 0 or (warn and ((math.floor(t * 14) % 2 == 0) and 0.35 or 0.9) or 0.93)
		for _, mv in ipairs(d.Movers) do
			mv.Part.Transparency = tr
			d.Active[mv.Part] = on
		end
	elseif d.Kind == "geyser" then
		local H = m:GetAttribute("JetH") or 16
		for _, mv in ipairs(d.Movers) do
			local lp2 = (ph + mv.Delay) % 1
			local h = 0.2
			if lp2 < 0.4 then h = math.max(0.2, H * math.sin(math.pi * lp2 / 0.4)) end
			-- cilindro com eixo X local => Size.X = altura do jato (Rel já tem a rotação de 90°)
			mv.Part.Size = Vector3.new(h, mv.Size.Y, mv.Size.Z)
			mv.Part.CFrame = O * mv.Rel * CFrame.new(h / 2, 0, 0)
			mv.Part.Transparency = h > 1 and 0.15 or 0.6
			d.Active[mv.Part] = h > 2.2
		end
	end
end

-- segmento a->b (espaço do objeto) cruza a caixa de meia-medida hs? (teste de placas)
local function segBox(a, b, hs)
	local tmin, tmax = 0, 1
	local d = b - a
	for _, ax in ipairs({ "X", "Y", "Z" }) do
		local o, v, h = a[ax], d[ax], hs[ax]
		if math.abs(v) < 1e-6 then
			if o < -h or o > h then return false end
		else
			local t1, t2 = (-h - o) / v, (h - o) / v
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return false end
		end
	end
	return true
end

local function feedback()
	if not flash then return end
	flash.BackgroundTransparency = 0.55
	UIKit.Tween(flash, 0.45, { BackgroundTransparency = 1 })
	local st = ouch:FindFirstChildOfClass("UIStroke")
	ouch.Visible = true
	ouch.TextTransparency = 0
	if st then st.Transparency = 0 end
	UIKit.Pop(ouch, 1.5)
	local token = os.clock()
	ouch:SetAttribute("Token", token)
	task.delay(0.7, function()
		if ouch:GetAttribute("Token") ~= token then return end
		UIKit.Tween(ouch, 0.25, { TextTransparency = 1 })
		if st then UIKit.Tween(st, 0.25, { Transparency = 1 }) end
		task.delay(0.27, function() if ouch:GetAttribute("Token") == token then ouch.Visible = false end end)
	end)
	UIKit.PlaySound("Crack")
	local cam = workspace.CurrentCamera
	if cam then
		task.spawn(function()
			for i = 1, 8 do
				local k = (8 - i) * 0.05
				cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

local function checkHits(carPos)
	if not prevPos or (carPos - prevPos).Magnitude > 120 then prevPos = carPos; return end -- teleporte: não conta
	if not Drive.IsDriving() or (lp:GetAttribute("RaceState") or "Lobby") ~= "Racing" then prevPos = carPos; return end
	for _, d in pairs(hazards) do
		if (d.Origin.Position - carPos).Magnitude < HIT_DIST then
			for _, p in ipairs(d.Hits) do
				if d.Active[p] and p.Parent then
					local cf = p.CFrame
					local hs = p.Size * 0.5 + MARGIN
					if segBox(cf:PointToObjectSpace(prevPos), cf:PointToObjectSpace(carPos), hs) then
						local away = carPos - p.Position
						away = Vector3.new(away.X, 0, away.Z)
						local back = -(carPos - prevPos)
						back = Vector3.new(back.X, 0, back.Z)
						local dir = (away.Magnitude > 0.1 and away.Unit or Vector3.zero) + (back.Magnitude > 0.1 and back.Unit * 0.6 or Vector3.zero)
						if Drive.Hit(dir) then feedback() end
						prevPos = carPos
						return
					end
				end
			end
		end
	end
	prevPos = carPos
end

function HazardController.Init()
	CollectionService:GetInstanceAddedSignal("Hazard"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Hazard"):Connect(unregister)
	for _, m in ipairs(CollectionService:GetTagged("Hazard")) do register(m) end

	local gui = UIKit.GetGui()
	flash = new("Frame", { Name = "HazardFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 40), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 4 }, gui)
	ouch = UIKit.Text(gui, { Name = "HazardOuch", Text = "💥 OUCH!", TextSize = 54, Color = Color3.fromRGB(255, 90, 70), Size = UDim2.fromOffset(400, 64),
		Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 5, ZIndex = 5 })
	ouch.Visible = false

	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		if camPos then
			for m, d in pairs(hazards) do
				if m.Parent and (d.Origin.Position - camPos).Magnitude < ANIM_DIST then animate(d, t) end
			end
		end
		local ch = Drive.GetChassis and Drive.GetChassis()
		if ch and ch.Parent then checkHits(ch.Position) else prevPos = nil end
	end)
end

return HazardController
