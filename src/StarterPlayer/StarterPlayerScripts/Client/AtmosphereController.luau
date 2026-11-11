--[[
	AtmosphereController: muda o "clima" visual ao entrar em cada bioma (só no cliente).
	Anima, em 3 segundos: névoa (Atmosphere), tom de cor/contraste/brilho (ColorCorrection "BiomeTint")
	e luz ambiente. NÃO mexe no horário do dia nem nos céus: respeita o skybox escolhido no Lighting
	(ex.: "Simple Sunset Sky"). Valores por bioma: Config.Biomes[i].Sky. No hub volta ao visual-base.
	Beta 1.4: no LOBBY (zona "lobby") aplica Config.Lobby.Sky — noite roxa "Sakura Night" (ClockTime/brilho
	do Lighting SÓ neste cliente). Ao ir para a pista tudo volta ao visual-base.
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local lp = Players.LocalPlayer

local Atmos = {}

function Atmos.Init()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then atmo = Instance.new("Atmosphere"); atmo.Parent = Lighting end
	local cc = Lighting:FindFirstChild("BiomeTint")
	if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "BiomeTint"; cc.Parent = Lighting end

	-- visual-base do hub = o que está configurado no Lighting agora
	local base = {
		FogColor = atmo.Color, FogDensity = atmo.Density, Decay = atmo.Decay,
		Ambient = Lighting.Ambient, Outdoor = Lighting.OutdoorAmbient,
		ClockTime = Lighting.ClockTime, LightBrightness = Lighting.Brightness, Exposure = Lighting.ExposureCompensation,
		Tint = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0,
	}
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local function apply(id)
		local b = id and Config.BiomeById[id]
		local s = b and b.Sky
		if id == "lobby" and Config.Lobby.Sky then s = Config.Lobby.Sky end
		TweenService:Create(atmo, info, {
			Color = s and s.FogColor or base.FogColor,
			Density = s and s.FogDensity or base.FogDensity,
			Decay = s and s.FogColor:Lerp(Color3.new(0, 0, 0), 0.4) or base.Decay,
		}):Play()
		TweenService:Create(cc, info, {
			TintColor = s and s.Tint or base.Tint,
			Saturation = s and s.Saturation or base.Saturation,
			Brightness = s and s.Brightness or base.Brightness,
			Contrast = s and s.Contrast or base.Contrast,
		}):Play()
		TweenService:Create(Lighting, info, {
			Ambient = s and s.Ambient or base.Ambient,
			OutdoorAmbient = s and s.Ambient or base.Outdoor,
			ClockTime = s and s.ClockTime or base.ClockTime,
			Brightness = s and s.LightBrightness or base.LightBrightness,
			ExposureCompensation = s and s.Exposure or base.Exposure,
		}):Play()
	end

	-- menu CONFIGS: "Low Graphics" desliga efeitos pesados e reduz a névoa
	local function applyGfx()
		local low = lp:GetAttribute("Set_LowGfx") == true
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled = not low end
		end
		atmo.Density = low and 0.1 or atmo.Density
		if not low then apply(lp:GetAttribute("Biome")) end
	end
	lp:GetAttributeChangedSignal("Set_LowGfx"):Connect(applyGfx)
	task.defer(applyGfx)
	lp:GetAttributeChangedSignal("Biome"):Connect(function() apply(lp:GetAttribute("Biome")) end)
	apply(lp:GetAttribute("Biome"))
end

return Atmos
