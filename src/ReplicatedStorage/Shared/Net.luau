--[[
	Net: camada única de rede (cliente <-> servidor).
	  SERVIDOR: Net.Handle(nome, fn, cooldown)  -> fn(player, ...) deve retornar uma tabela {ok=bool,...}
	            Net.Fire(player, nome, ...) / Net.FireAll(nome, ...)
	  CLIENTE : Net.Call(nome, ...) -> tabela de resposta (ou nil em caso de erro)
	            Net.On(nome, fn)    -> escuta eventos do servidor
	Toda ação do cliente passa por Net.Handle => validação e rate-limit centralizados.
	NUNCA confie em valores vindos do cliente: valide tipo e limites no handler.
]]
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = {}
local remotes = RS:WaitForChild("Remotes")
local Action = remotes:WaitForChild("Action")
local Event = remotes:WaitForChild("Event")

if RunService:IsServer() then
	local handlers, last = {}, {}
	function Net.Handle(name, fn, cooldown)
		handlers[name] = { fn = fn, cd = cooldown or 0.1 }
	end
	Action.OnServerInvoke = function(player, name, ...)
		local h = type(name) == "string" and handlers[name]
		if not h then return { ok = false, err = "UnknownAction" } end
		local key, now = player.UserId .. ":" .. name, os.clock()
		if last[key] and now - last[key] < h.cd then return { ok = false, err = "TooFast" } end
		last[key] = now
		local ok, res = pcall(h.fn, player, ...)
		if not ok then
			warn("[Net] erro em '" .. name .. "': " .. tostring(res))
			return { ok = false, err = "ServerError" }
		end
		return res or { ok = true }
	end
	function Net.Fire(player, name, ...) Event:FireClient(player, name, ...) end
	function Net.FireAll(name, ...) Event:FireAllClients(name, ...) end
	Players.PlayerRemoving:Connect(function(p)
		for k in pairs(last) do if k:sub(1, #tostring(p.UserId) + 1) == p.UserId .. ":" then last[k] = nil end end
	end)
else
	local listeners = {}
	function Net.Call(name, ...)
		local ok, res = pcall(Action.InvokeServer, Action, name, ...)
		if not ok then warn("[Net] Call falhou:", name, res); return nil end
		return res
	end
	function Net.On(name, fn)
		listeners[name] = listeners[name] or {}
		table.insert(listeners[name], fn)
	end
	Event.OnClientEvent:Connect(function(name, ...)
		local list = listeners[name]
		if list then for _, fn in ipairs(list) do task.spawn(fn, ...) end end
	end)
end

return Net
