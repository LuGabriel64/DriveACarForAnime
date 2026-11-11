--[[ Util: funções puras (sem estado) usadas por servidor e cliente. ]]
local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K" | 5e9 -> "5B" | 20 -> "20"
function Util.FormatNumber(n)
	n = tonumber(n) or 0
	if n < 0 then return "-" .. Util.FormatNumber(-n) end
	if n < 1000 then
		local s = string.format("%.1f", n)
		if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
		return s
	end
	local idx = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local v = n / 10 ^ (idx * 3)
	if v >= 999.5 and idx < #SUFFIXES - 1 then idx += 1; v = n / 10 ^ (idx * 3) end
	local s
	if v >= 100 then s = string.format("%.0f", v)
	elseif v >= 10 then s = string.format("%.1f", v)
	else s = string.format("%.2f", v) end
	if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s .. SUFFIXES[idx + 1]
end
function Util.FormatMoney(n) return "$" .. Util.FormatNumber(n) end

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = Util.DeepCopy(v) end
	return c
end

-- Onda triangular 0..1..0 (usada no marcador do mini-jogo; servidor e cliente usam a MESMA função).
function Util.Triangle(t, period)
	local x = (t / period) % 2
	return x < 1 and x or 2 - x
end

function Util.SmoothStep(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end

return Util
