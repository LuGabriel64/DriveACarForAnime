--[[ State: cache local dos dados replicados pelo servidor (inventário, carros) + flags de UI. ]]
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Shared.Net)

local State = {
	Inventory = {},          -- lista de { Uid, Id, Mut, Size, Placed, Income, Sell }
	PlotSlots = 10,
	Cars = nil,              -- { Equipped, Owned = {[id]=engineLevel}, EngineLevel, EngineCost, EngineMax }
	Encounter = false,       -- true enquanto o mini-jogo de captura está aberto (carro freia)
	Changed = Instance.new("BindableEvent"),
}

function State.Init()
	Net.On("Inventory", function(list, slots)
		State.Inventory, State.PlotSlots = list, slots
		State.Changed:Fire("Inventory")
	end)
	Net.On("CarState", function(s)
		State.Cars = s
		State.Changed:Fire("Cars")
	end)
	task.spawn(function() Net.Call("GetState") end)
end

return State
