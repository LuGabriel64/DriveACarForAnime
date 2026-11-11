--[[ GiftService: presente grátis (UI "Free Gift"). Recompensa única por jogador (data.GiftClaimed). ]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)

local GiftService = {}

function GiftService.Init()
	Net.Handle("ClaimGift", function(player)
		local data = DataService.Get(player)
		if not data then return { ok = false } end
		if data.GiftClaimed then return { ok = false, err = "Claimed" } end
		if Config.Gift.GroupId > 0 then
			local ok, inGroup = pcall(function() return player:IsInGroup(Config.Gift.GroupId) end)
			if not (ok and inGroup) then return { ok = false, err = "Group" } end
		end
		data.GiftClaimed = true
		player:SetAttribute("GiftClaimed", true)
		DataService.AddCash(player, Config.Gift.Cash)
		return { ok = true, Cash = Config.Gift.Cash }
	end, 1)
end

return GiftService
