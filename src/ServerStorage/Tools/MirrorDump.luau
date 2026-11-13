--[[
	MirrorDump  (ServerStorage.Tools.MirrorDump)                                                 Beta 1.9
	=====================================================================================================
	FERRAMENTA DE ASSISTENTE (não roda no jogo): despeja o código de todos os scripts para o GitHub.
	Par do script tools/place/mirror_from_dump.js do repositório (place -> src/ sem Python e sem .rbxl).

	COMO USAR (execute_luau, modo Edit):
	    return require(game.ServerStorage.Tools.MirrorDump)(1)          -- parte 1; a resposta começa com "@@@PARTS 1/N"
	    return require(game.ServerStorage.Tools.MirrorDump)(2)          -- ... até N
	    return require(game.ServerStorage.Tools.MirrorDump)(1, {})      -- 2º argumento = pastas a PULAR ({} = tudo)
	    return require(game.ServerStorage.Tools.MirrorDump)("sum")      -- só a lista caminho|checksum|tamanho
	Padrão de "pular": ServerStorage.Tools.WorldBuilder / LobbyBuilder e LegacyCode (grandes; despeje com {} quando mudarem).
	ServerStorage.Backups nunca entra.

	POR QUE EM PARTES: o MCP corta a resposta em 100.000 bytes. Cada parte tem até 90.000, cortada em fim de linha.
	FORMATO: @@@FILE <caminho> <ClassName> <bytes>\n<source>\n
]]
local DEFAULT_SKIP = { "ServerStorage.Tools.WorldBuilder", "ServerStorage.Tools.LobbyBuilder", "ServerStorage.LegacyCode" }
local LIMIT = 90000

local function collect(skipList)
	local roots = { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), game:GetService("StarterPlayer") }
	local backups = game:GetService("ServerStorage"):FindFirstChild("Backups")
	local list = {}
	for _, r in ipairs(roots) do
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("LuaSourceContainer") and not (backups and d:IsDescendantOf(backups)) then
				local skip = false
				for _, pre in ipairs(skipList) do
					if d:GetFullName():sub(1, #pre) == pre then skip = true end
				end
				if not skip then table.insert(list, d) end
			end
		end
	end
	table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end)
	return list
end

local function checksum(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 2147483647 end
	return h
end

return function(part, skipList)
	if part == "sum" then
		local out = {}
		for _, d in ipairs(collect({})) do
			local s = d.Source:gsub("\r", "")
			out[#out + 1] = d:GetFullName() .. "|" .. checksum(s) .. "|" .. #s
		end
		return table.concat(out, "\n")
	end
	local out = {}
	for _, d in ipairs(collect(skipList or DEFAULT_SKIP)) do
		local s = d.Source:gsub("\r", "")
		out[#out + 1] = ("@@@FILE %s %s %d\n%s\n"):format(d:GetFullName(), d.ClassName, #s, s)
	end
	local blob = table.concat(out)
	local parts, pos = {}, 1
	while pos <= #blob do
		local stop = math.min(#blob, pos + LIMIT - 1)
		if stop < #blob then
			local nl = stop
			while nl > pos and blob:byte(nl) ~= 10 do nl -= 1 end
			if nl > pos then stop = nl end
		end
		parts[#parts + 1] = blob:sub(pos, stop)
		pos = stop + 1
	end
	return ("@@@PARTS %d/%d\n"):format(part, #parts) .. (parts[part] or "")
end
