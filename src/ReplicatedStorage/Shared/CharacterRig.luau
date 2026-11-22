--[[
	CharacterRig  (ReplicatedStorage.Shared.CharacterRig)                                        Beta 2.0
	=====================================================================================================
	Anima os personagens de MALHA da Beta 2.0 (Gokun, Super Gokun, Mini Gokun...) por PEÇAS RÍGIDAS: cada peça é um
	MeshPart ancorado, e a cada quadro o módulo calcula o CFrame de todas a partir da pose (Shared.CharacterAnims).
	Não usa Humanoid, Motor6D nem AnimationTrack: é barato e funciona igual no ViewportFrame.

	USO (sempre no CLIENTE; no servidor o movimento replicaria a 20 Hz e pesaria na rede):
	    local Rig = require(ReplicatedStorage.Shared.CharacterRig)
	    Rig.Play(model, "gokun")        -- começa a animação de parado; para sozinho quando o modelo é destruído
	    Rig.Stop(model)                 -- para e devolve as peças à pose de repouso
	    local rig = Rig.new(model, "gokun")  ;  rig:Update(t)   -- controle manual (testes, ViewportFrame)

	O MODELO precisa de:
	    * PrimaryPart "Root" nos PÉS, com a frente em -Z (igual ao AnimeModelFactory). Mover o Root move o personagem.
	    * peças com os nomes de CharacterAnims (Head, Hair, Torso, ArmL, ForeL, ...), ancoradas, na pose de REPOUSO
	      na hora do Rig.new (é aí que o módulo memoriza onde cada peça fica). Peça que faltar é ignorada.

	ENTRADAS: model (Model), animId (chave de CharacterAnims), opts = { Speed = 1, Phase = segundos, MaxDistance = 300 }.
	SAÍDAS: só o CFrame das peças. Nenhum dado de jogo passa por aqui (é só visual).
	Dependências: Shared.CharacterAnims.

	Rig.DebugProxy(animId) monta um boneco de BLOCOS com as mesmas juntas, só para testar a animação sem as malhas.

	TESTADO (16/11/2026, modo Edit, boneco de blocos): as três poses e o movimento batem com o vídeo do Blender.
	TESTADO (22/11/2026, modo Edit): com as malhas reais de ReplicatedStorage.Assets.Characters.

	Beta 2.0 (22/11): respeita a escala do modelo (model:GetScale(), usada por Size e Look.MeshScale) e funciona fora do
	Workspace (ViewportFrame: move as peças uma a uma; BulkMoveTo só no Workspace). Update protegido por pcall no laço
	(com StreamingEnabled uma peça pode sumir no meio).
]]
local RunService = game:GetService("RunService")
local Anims = require(script.Parent.CharacterAnims)

local Rig = {}
Rig.__index = Rig

local rad, sin, TAU = math.rad, math.sin, math.pi * 2
local X_AXIS, Y_AXIS, NEG_Z = Vector3.xAxis, Vector3.yAxis, -Vector3.zAxis
-- espaço do rig (eixos do Blender convertidos: x, z, -y) -> espaço do Root (frente em -Z): meia-volta em Y
local FLIP = CFrame.Angles(0, math.pi, 0)

-- ponto nos eixos do Blender -> eixos do Roblox
local function toR(v)
	return Vector3.new(v[1], v[3], -v[2])
end

-- Rz(c) * Rx(a) * Ry(b) do Blender, escrito nos eixos do Roblox (Z do Blender = Y; Y do Blender = -Z)
local function rot(a, b, c)
	local cf = CFrame.identity
	if c ~= 0 then cf = CFrame.fromAxisAngle(Y_AXIS, rad(c)) end
	if a ~= 0 then cf = cf * CFrame.fromAxisAngle(X_AXIS, rad(a)) end
	if b ~= 0 then cf = cf * CFrame.fromAxisAngle(NEG_Z, rad(b)) end
	return cf
end

local CHANNELS = { a = 1, b = 2, c = 3, x = 4, y = 5, z = 6 }

function Rig.new(model, animId, opts)
	local anim = Anims[animId]
	assert(type(anim) == "table" and anim.Joints, "CharacterRig: animação desconhecida: " .. tostring(animId))
	local root = model.PrimaryPart
	assert(root, "CharacterRig: o modelo precisa de PrimaryPart (Root nos pés)")
	opts = opts or {}
	local self = setmetatable({}, Rig)
	self.Model, self.Root, self.Anim = model, root, anim
	self.Speed = opts.Speed or 1
	self.Phase = opts.Phase or 0
	self.MaxDistance = opts.MaxDistance or 300
	local base = root.CFrame * FLIP
	local s = model:GetScale()
	self.Scale = s
	self._nodes, self._parts, self._cfs = {}, {}, {}
	local byName = {}
	for _, name in ipairs(Anims.Order) do
		local part = name ~= "Root" and model:FindFirstChild(name) or nil
		if name == "Root" or (part and part:IsA("BasePart")) then
			local j = (anim.Joints[name] and toR(anim.Joints[name]) or Vector3.zero) * s
			local pose = anim.Pose[name] or {}
			local node = {
				Name = name, Part = part, Parent = byName[Anims.Parents[name] or ""],
				J = CFrame.new(j), JInv = CFrame.new(-j),
				Base = { pose.a or 0, pose.b or 0, pose.c or 0, pose.x or 0, pose.y or 0, pose.z or 0 },
				Waves = {}, Val = { 0, 0, 0, 0, 0, 0 }, World = CFrame.identity,
				Rest = part and base:ToObjectSpace(part.CFrame) or nil,
			}
			if name == "Root" then node.Base[6] -= anim.Drop or 0 end
			-- peça cujo pai não existe no modelo gira com o Root
			if name ~= "Root" and not node.Parent then node.Parent = byName.Root end
			byName[name] = node
			table.insert(self._nodes, node)
			if part then
				table.insert(self._parts, part)
				node.Index = #self._parts
			end
		end
	end
	for _, w in ipairs(anim.Waves) do
		local node = byName[w[1]]
		local ch = CHANNELS[w[2]]
		if node and ch then
			table.insert(node.Waves, { ch, w[3], w[4], w[5] or 0 })
		end
	end
	return self
end

-- Coloca as peças na pose do instante t (segundos).
function Rig:Update(t)
	t = t * self.Speed + self.Phase
	local base = self.Root.CFrame * FLIP
	local cfs = self._cfs
	for _, node in ipairs(self._nodes) do
		local v, b = node.Val, node.Base
		v[1], v[2], v[3], v[4], v[5], v[6] = b[1], b[2], b[3], b[4], b[5], b[6]
		for _, w in ipairs(node.Waves) do
			v[w[1]] += w[2] * sin(TAU * (t / w[3] + w[4]))
		end
		local localCF = node.J * rot(v[1], v[2], v[3]) * node.JInv
		if v[4] ~= 0 or v[5] ~= 0 or v[6] ~= 0 then
			local s = self.Scale
			localCF = CFrame.new(v[4] * s, v[6] * s, -v[5] * s) * localCF
		end
		node.World = node.Parent and (node.Parent.World * localCF) or localCF
		if node.Index then
			cfs[node.Index] = base * node.World * node.Rest
		end
	end
	self:_apply()
end

function Rig:_apply()
	if self.Root:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(self._parts, self._cfs, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in ipairs(self._parts) do p.CFrame = self._cfs[i] end
	end
end

-- Devolve as peças à pose de repouso (a que tinham no Rig.new).
function Rig:Reset()
	local base = self.Root.CFrame * FLIP
	for _, node in ipairs(self._nodes) do
		if node.Index then self._cfs[node.Index] = base * node.Rest end
	end
	self:_apply()
end

-- ---------------------------------------------------------------- laço único para todos os personagens tocando
local playing = {} -- [model] = rig
local conn

local function step()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local now = os.clock()
	for model, rig in pairs(playing) do
		if not model.Parent or not rig.Root.Parent then
			playing[model] = nil
		elseif not camPos or not model:IsDescendantOf(workspace)
			or (rig.Root.Position - camPos).Magnitude <= rig.MaxDistance then
			if not pcall(rig.Update, rig, now) then playing[model] = nil end
		end
	end
	if next(playing) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

function Rig.Play(model, animId, opts)
	local rig = playing[model]
	if rig then rig:Reset() end
	opts = opts or {}
	if opts.Phase == nil then opts.Phase = math.random() * 4 end -- personagens iguais não ficam em sincronia
	rig = Rig.new(model, animId, opts)
	playing[model] = rig
	if not conn then
		conn = (RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat):Connect(step)
	end
	return rig
end

function Rig.Stop(model)
	local rig = playing[model]
	if rig then
		playing[model] = nil
		if model.Parent then rig:Reset() end
	end
end

function Rig.IsPlaying(model)
	return playing[model] ~= nil
end

-- ---------------------------------------------------------------- boneco de blocos (só para teste)
local PROXY = { -- peça = { junta de baixo (ou nil = usa Tip), largura, profundidade, cor }
	Torso = { "Head", 1.7, 0.95, Color3.fromRGB(248, 134, 28) }, Head = { nil, 1.0, 1.0, Color3.fromRGB(255, 208, 168) },
	Hair = { nil, 1.25, 1.1, Color3.fromRGB(36, 36, 48) },
	ArmL = { "ForeL", 0.5, 0.5, Color3.fromRGB(255, 208, 168) }, ArmR = { "ForeR", 0.5, 0.5, Color3.fromRGB(255, 208, 168) },
	ForeL = { nil, 0.45, 0.45, Color3.fromRGB(46, 62, 152) }, ForeR = { nil, 0.45, 0.45, Color3.fromRGB(46, 62, 152) },
	LegL = { "ShinL", 0.75, 0.75, Color3.fromRGB(248, 134, 28) }, LegR = { "ShinR", 0.75, 0.75, Color3.fromRGB(248, 134, 28) },
	ShinL = { nil, 0.7, 0.7, Color3.fromRGB(40, 50, 128) }, ShinR = { nil, 0.7, 0.7, Color3.fromRGB(40, 50, 128) },
	Tail = { nil, 0.2, 0.2, Color3.fromRGB(128, 74, 38) }, Staff = { nil, 0.2, 0.2, Color3.fromRGB(226, 48, 44) },
	Cloud = { nil, 4.6, 3.6, Color3.fromRGB(255, 224, 108) }, Smoke = { nil, 1.2, 1.2, Color3.fromRGB(255, 240, 170) },
	Aura = { nil, 5.0, 3.0, Color3.fromRGB(255, 236, 130) },
}

function Rig.DebugProxy(animId)
	local anim = Anims[animId]
	assert(anim, "CharacterRig.DebugProxy: animação desconhecida")
	local m = Instance.new("Model")
	m.Name = "RigProxy_" .. animId
	local root = Instance.new("Part")
	root.Name, root.Size, root.Anchored, root.Transparency, root.CanCollide = "Root", Vector3.new(1, 0.2, 1), true, 1, false
	root.Parent = m
	m.PrimaryPart = root
	local base = root.CFrame * FLIP
	local J = anim.Joints
	for name, spec in pairs(PROXY) do
		if J[name] then
			local top = toR(J[name])
			local bottom
			if spec[1] and J[spec[1]] then
				bottom = toR(J[spec[1]])
			elseif name == "Head" then
				bottom = top + Vector3.new(0, 1.15, 0)
			elseif name == "Hair" then
				top = top + Vector3.new(0, 1.0, 0)
				bottom = top + Vector3.new(0, 0.9, 0)
			elseif name:sub(1, 4) == "Fore" then
				bottom = top + (top - toR(J[name == "ForeL" and "ArmL" or "ArmR"])).Unit * 1.45
			elseif name:sub(1, 4) == "Shin" then
				bottom = Vector3.new(top.X, 0, top.Z)
			elseif name == "Tail" then
				bottom = top + Vector3.new(0.9, 1.2, 1.2)
			elseif name == "Staff" then
				top, bottom = top + Vector3.new(-1.5, -2.4, 0), top + Vector3.new(1.5, 2.4, 0)
			elseif name == "Cloud" then
				top, bottom = Vector3.new(0, -1.0, 0), Vector3.new(0, 0.6, 0)
			elseif name == "Smoke" then
				top, bottom = Vector3.new(0, -0.3, -4.2), Vector3.new(0, 0.9, -4.2)
			elseif name == "Aura" then
				top, bottom = Vector3.new(0, 0, -1.4), Vector3.new(0, 9.5, -1.4)
			else
				bottom = top + Vector3.new(0, -1, 0)
			end
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.CanCollide = name, true, false
			p.Material, p.Color = Enum.Material.SmoothPlastic, spec[4]
			p.Size = Vector3.new(spec[2], math.max((top - bottom).Magnitude, 0.2), spec[3])
			local mid = (top + bottom) / 2
			p.CFrame = base * (CFrame.lookAt(mid, bottom) * CFrame.Angles(math.pi / 2, 0, 0))
			if name == "Aura" then p.Transparency = 0.7 end
			p.Parent = m
		end
	end
	return m
end

return Rig
