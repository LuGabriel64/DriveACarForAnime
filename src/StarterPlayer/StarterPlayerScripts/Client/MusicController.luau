--[[
	MusicController  (StarterPlayerScripts.Client.MusicController)                               Beta 1.9
	=====================================================================================================
	Música de fundo dos desafios 1v1, com fade de entrada e saída. Decide sozinho o que tocar olhando os
	atributos do jogador (definidos pelo servidor):
	    VersusStage Lobby / Vote / Prep          -> Config.Music.VersusLobby
	    VersusStage Playing + VersusMode Race    -> Config.Music.Race
	    VersusStage Playing + VersusMode Battle  -> Config.Music.Battle
	    evento VersusResult (vitória deste jogador) -> Config.Music.Victory (uma vez, sem loop)
	    fora de um desafio                       -> silêncio
	Respeita o interruptor "Music" do menu Configs (atributo Set_Music). ID vazio = silêncio, sem erro.
	PENDENTE DO DONO: escolher os áudios (Creator Store > Audio) e pôr os IDs em Config.Music.
	API: MusicController.Play(key, loop) | MusicController.Stop()
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared.Net)
local lp = Players.LocalPlayer

local MusicController = {}
local M = Config.Music
local current, currentKey

local function enabled() return lp:GetAttribute("Set_Music") ~= false end

local function fadeOut(sound)
	if not sound then return end
	local tw = TweenService:Create(sound, TweenInfo.new(M.FadeSeconds or 1), { Volume = 0 })
	tw:Play()
	tw.Completed:Connect(function() sound:Destroy() end)
end

function MusicController.Stop()
	fadeOut(current)
	current, currentKey = nil, nil
end

function MusicController.Play(key, loop)
	if key == currentKey and current then return end
	MusicController.Stop()
	local id = M[key]
	if not enabled() or type(id) ~= "string" or id == "" then currentKey = key; return end
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key; s.SoundId = id; s.Looped = loop ~= false; s.Volume = 0
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(M.FadeSeconds or 1), { Volume = M.Volume or 0.45 }):Play()
	current, currentKey = s, key
	if not s.Looped then s.Ended:Connect(function() if current == s then current, currentKey = nil, nil end end) end
end

local function refresh()
	local stage, mode = lp:GetAttribute("VersusStage") or "", lp:GetAttribute("VersusMode") or ""
	if stage == "Lobby" or stage == "Vote" or stage == "Prep" then
		MusicController.Play("VersusLobby")
	elseif stage == "Playing" then
		MusicController.Play(mode == "Battle" and "Battle" or "Race")
	elseif stage == "Result" then
		-- a vitória é tocada pelo evento VersusResult; quem perdeu fica em silêncio
		if currentKey ~= "Victory" then MusicController.Stop() end
	else
		if currentKey ~= "Victory" then MusicController.Stop() end
	end
end

function MusicController.Init()
	lp:GetAttributeChangedSignal("VersusStage"):Connect(refresh)
	lp:GetAttributeChangedSignal("Set_Music"):Connect(function()
		if not enabled() then MusicController.Stop() else currentKey = nil; refresh() end
	end)
	Net.On("VersusResult", function(info)
		if type(info) == "table" and info.WinnerUserId == lp.UserId then MusicController.Play("Victory", false)
		else MusicController.Stop() end
	end)
end

return MusicController
