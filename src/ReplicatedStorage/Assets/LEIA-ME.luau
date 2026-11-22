--[[
	ReplicatedStorage.Assets (Beta 2.0, 22/11/2026) — malhas feitas no Blender (pasta arte/ no GitHub), enviadas pelo
	Claude Code via Open Cloud para o GRUPO 879120012 e inseridas aqui. IDs em arte/export/assets_roblox.json.

	Cars/<id>        21 carros de Fórmula (warrior_a ... celestial_c). Peças: Body (pintura em TextureID), Trim, Glow,
	                 Glass, Acc, Wheel_FL/FR/RL/RR. Cores das peças sem textura vêm da COR POR VÉRTICE do FBX (o Color
	                 cinza da peça é ignorado). PrimaryPart "Root" invisível no CHÃO, no meio das 4 rodas, frente em -Z.
	                 ~9,8 x 4,5 x 18,5 studs. Atributos: AssetId, DisplayName, Source.
	Characters/<id>  gokun, super_gokun, mini_gokun_classic, mini_gokun_violet (versão de jogo, 24 a 27 mil triângulos).
	                 Peças rígidas Head, Hair, Torso, ArmL, ForeL, ArmR, ForeR, LegL, ShinL, LegR, ShinR (+ Tail, Staff,
	                 Cloud, Smoke no mirim; + Aura no Super). PrimaryPart "Root" nos pés (origem do Blender), frente em -Z.
	                 Atributos: AssetId, AnimId (chave de Shared.CharacterAnims), DisplayName, Source.
	                 Animar no CLIENTE: require(ReplicatedStorage.Shared.CharacterRig).Play(model, model:GetAttribute("AnimId"))

	As cópias aqui NÃO são pacotes (o PackageLink foi tirado de propósito): o giro e o Root foram corrigidos só nesta cópia.
	Reinserir o asset pelo ID traz de volta a versão crua (girada e sem Root).

	Ninguém usa estes modelos ainda: o CarFactory, a garagem e a vitrine passam a usá-los na Etapa B/C da Beta 2.0.
]]
return {}
