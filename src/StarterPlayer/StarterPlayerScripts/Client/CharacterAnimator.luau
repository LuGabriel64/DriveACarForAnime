--[[
	CharacterAnimator  (StarterPlayer.StarterPlayerScripts.Client.CharacterAnimator)            Beta 2.0
	=====================================================================================================
	Toca a animação de "parado" dos personagens de MALHA (os que têm o atributo AnimId, criados pelo
	Shared.AnimeModelFactory a partir de ReplicatedStorage.Assets.Characters).
	  * No Workspace (garagem do FarmService, vitrine do lobby, batalha...): animação contínua (Shared.CharacterRig.Play).
	  * Em ViewportFrame (inventário, roleta, painéis): só a POSE, uma vez (barato; são muitos ícones).
	Só visual e só local: o servidor não sabe disso e nada de jogo depende daqui.
	StreamingEnabled: espera o Torso e a Head chegarem; se outra peça chegar depois, recomeça o rig.
	Entradas: nenhuma (escuta Workspace e PlayerGui). Dependências: Shared.CharacterRig.
	NÃO TESTADO no celular nem com muitos jogadores.
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Rig = require(RS:WaitForChild("Shared"):WaitForChild("CharacterRig"))

local Animator = {}
local pending = {}

local function ready(m)
	return m.PrimaryPart ~= nil and m:FindFirstChild("Torso") ~= nil and m:FindFirstChild("Head") ~= nil
end

local function schedule(m)
	if pending[m] then return end
	pending[m] = true
	task.delay(0.25, function()
		pending[m] = nil
		if not m.Parent then return end
		local id = m:GetAttribute("AnimId")
		if not id or not ready(m) then return end
		if m:IsDescendantOf(workspace) then
			local ok, err = pcall(Rig.Play, m, id)
			if not ok then warn("[CharacterAnimator] " .. m.Name .. ": " .. tostring(err)) end
		elseif not m:GetAttribute("Posed") then
			local ok, rig = pcall(Rig.new, m, id)
			if ok then
				pcall(rig.Update, rig, 1.0)
				m:SetAttribute("Posed", true)
			end
		end
	end)
end

local function onWorkspaceAdded(d)
	if d:IsA("Model") then
		if d:GetAttribute("AnimId") then schedule(d) end
	elseif d:IsA("BasePart") then
		local m = d.Parent
		if m and m:IsA("Model") and m:GetAttribute("AnimId") then schedule(m) end -- peça que chegou depois (streaming)
	end
end

function Animator.Init()
	workspace.DescendantAdded:Connect(onWorkspaceAdded)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("AnimId") then schedule(d) end
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	pg.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("AnimId") then schedule(d) end
	end)
end

return Animator
