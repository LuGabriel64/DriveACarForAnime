--[[
	Locale  (ReplicatedStorage.Shared.Locale, com um ModuleScript filho por idioma: "pt")          Beta 1.9
	=====================================================================================================
	TRADUÇÃO do jogo. O texto em INGLÊS é a própria chave (como o código já está escrito):

	    Locale.T("Free spin ready!")                    -> "Giro grátis pronto!"   (jogador em português)
	    Locale.T("🔒 This egg needs a Tier %d car!", 3) -> formata depois de traduzir
	    texto sem tradução                              -> volta o próprio inglês (nunca quebra a UI)

	POR QUE NÃO O SISTEMA AUTOMÁTICO DO ROBLOX: ele segue o idioma da CONTA do jogador. O dono quer um botão
	"Languages" dentro do jogo, então a escolha tem de ser nossa. As tabelas ficam no Git (fáceis de revisar).

	IDIOMA DO JOGADOR = atributo "Lang" do Player ("en" | "pt"), definido pelo SERVIDOR (DataService):
	    1ª vez: detectado pelo idioma da conta Roblox (Locale.Detect) | depois: salvo em data.Lang
	    troca: ação de rede "SetLanguage" (lista branca = Config.Languages)

	API (servidor e cliente)
	    Locale.Translate(lang, key, ...)   traduz para um idioma específico
	    Locale.Has(key)                    existe tradução para esta chave em algum idioma?
	    Locale.Detect(robloxLocaleId)      "pt-br" -> "pt" ; desconhecido -> 1º de Config.Languages
	    Locale.IsValid(code)               o código está em Config.Languages?
	SERVIDOR
	    Locale.For(player, key, ...)       traduz no idioma do jogador (toasts: Net.Fire(p, "Toast", Locale.For(p, ...)))
	CLIENTE
	    Locale.Get()                       idioma atual
	    Locale.T(key, ...)                 traduz no idioma atual
	    Locale.Bind(guiObject, key, ...)   põe o texto e RETRADUZ sozinho quando o idioma mudar
	    Locale.OnChanged(fn)               avisa quando o idioma muda (para textos montados à mão)

	COMO OS TEXTOS EXISTENTES ENTRAM: UIKit.Text / UIKit.Button / UIKit.Panel / UIKit.SetButton chamam
	Locale.Bind quando o texto tem tradução (Locale.Has). Textos dinâmicos ("0", "GARAGE 3") não são tocados.
	Se outro script escrever por cima de um texto ligado, o Bind percebe (o texto não é mais o que ele pôs) e solta.

	PARA ADICIONAR UM IDIOMA: 1 linha em Config.Languages + 1 ModuleScript filho deste (copie o "pt").
	O módulo evita sintaxe exclusiva do Luau para também rodar nos testes fora do Roblox.
]]
local Locale = {}

local tables = {}   -- [code] = { ["English text"] = "Tradução" }
local languages     -- Config.Languages
local loaded = false

local function load()
	if loaded then return end
	loaded = true
	local Config = require(script.Parent.Config)
	languages = Config.Languages
	for _, lang in ipairs(languages) do
		local module = script:FindFirstChild(lang.Code)
		if module then
			tables[lang.Code] = require(module)
		end
	end
end
-- Só para testes fora do Roblox: Locale.Use(Config.Languages, { pt = {...} })
function Locale.Use(langs, tbls)
	languages, tables, loaded = langs, tbls, true
	return Locale
end

function Locale.IsValid(code)
	load()
	for _, lang in ipairs(languages) do
		if lang.Code == code then return true end
	end
	return false
end

function Locale.Default()
	load()
	return languages[1].Code
end

-- "pt-br" / "pt_PT" -> "pt". Usado só na PRIMEIRA entrada do jogador.
function Locale.Detect(robloxLocaleId)
	load()
	local id = string.lower(tostring(robloxLocaleId or ""))
	for _, lang in ipairs(languages) do
		for _, prefix in ipairs(lang.RobloxLocales or {}) do
			if string.sub(id, 1, #prefix) == prefix then return lang.Code end
		end
	end
	return languages[1].Code
end

function Locale.Has(key)
	load()
	for _, t in pairs(tables) do
		if t[key] ~= nil then return true end
	end
	return false
end

-- Traduz e formata. Se a tradução tiver os %d/%s errados, cai para o inglês em vez de dar erro na tela.
function Locale.Translate(lang, key, ...)
	load()
	if type(key) ~= "string" then return tostring(key) end
	local t = tables[lang]
	local text = (t and t[key]) or key
	if select("#", ...) == 0 then return text end
	local ok, res = pcall(string.format, text, ...)
	if ok then return res end
	ok, res = pcall(string.format, key, ...)
	return ok and res or key
end

-- ---------------------------------------------------------------- lado do Roblox (servidor / cliente)
local RunService = game and game:GetService("RunService")

if RunService and RunService:IsServer() then
	function Locale.For(player, key, ...)
		load()
		local lang = player and player:GetAttribute("Lang") or languages[1].Code
		return Locale.Translate(lang, key, ...)
	end
elseif RunService then
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local bound = {}    -- [guiObject] = { Key, Args, Last (texto que o Locale escreveu), Conn }
	local listeners = {}

	function Locale.Get()
		load()
		local lang = lp:GetAttribute("Lang")
		return Locale.IsValid(lang) and lang or languages[1].Code
	end

	function Locale.T(key, ...)
		return Locale.Translate(Locale.Get(), key, ...)
	end

	local function unbind(obj)
		local b = bound[obj]
		if b then
			if b.Conn then b.Conn:Disconnect() end
			bound[obj] = nil
		end
	end
	Locale.Unbind = unbind

	function Locale.Bind(obj, key, ...)
		unbind(obj)
		local args = table.pack(...)
		local text = Locale.Translate(Locale.Get(), key, table.unpack(args, 1, args.n))
		obj.Text = text
		bound[obj] = { Key = key, Args = args, Last = text, Conn = obj.Destroying:Connect(function() unbind(obj) end) }
		return obj
	end

	function Locale.OnChanged(fn)
		listeners[#listeners + 1] = fn
	end

	lp:GetAttributeChangedSignal("Lang"):Connect(function()
		local lang = Locale.Get()
		for obj, b in pairs(bound) do
			if obj.Text ~= b.Last then
				unbind(obj) -- outro script escreveu por cima: o texto não é mais nosso
			else
				b.Last = Locale.Translate(lang, b.Key, table.unpack(b.Args, 1, b.Args.n))
				obj.Text = b.Last
			end
		end
		for _, fn in ipairs(listeners) do
			task.spawn(fn, lang)
		end
	end)
end

return Locale
