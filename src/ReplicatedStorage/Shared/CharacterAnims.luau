--[[
	CharacterAnims  (ReplicatedStorage.Shared.CharacterAnims)                                    Beta 2.0
	=====================================================================================================
	DADOS das animações de "parado" (idle) dos personagens de malha da Beta 2.0. Quem lê é Shared.CharacterRig.
	ARQUIVO GERADO: não edite à mão. A fonte é arte/blender/char_hero.py (tabela IDLE) no repositório;
	rode o Blender e depois  node tools/art/anims_to_luau.js .

	Cada personagem fica numa POSE própria e se mexe nela:
	    gokun        "Fighting stance"  guarda de luta, respirando
	    super_gokun  "Power up"         braços abertos, tremendo, aura pulsando
	    mini_gokun   "Cloud rider"      em cima da nuvem, acenando, cauda balançando

	Formato (eixos do MODELO no Blender: X = esquerda do personagem, -Y = frente, Z = cima; medidas em studs):
	    Joints[peça] = {x, y, z}    ponto em torno do qual a peça gira
	    Parents[peça] = peça pai    a peça herda o movimento do pai ("Root" = o modelo inteiro)
	    Pose[peça] = {a=, b=, c=, x=, y=, z=}   a/b/c = giro em graus nos eixos X/Y/Z; x/y/z = deslocamento
	    Waves = { {peça, canal, amplitude, período (s), fase 0..1}, ... }   somadas à pose: amp * sin(2*pi*(t/período + fase))
	    Drop = quanto o modelo desce para o pé encostar no chão nessa pose
	Peças: Head Hair Torso ArmL ForeL ArmR ForeR LegL ShinL LegR ShinR (+ Tail Staff Cloud Smoke no mirim; + Aura no Super).

	Dependências: nenhuma. Não foi testado com as malhas reais (ainda não importadas); ver o cabeçalho do CharacterRig.
]]
local Anims = {}

Anims.Parents = {
	Torso = "Root", Head = "Torso", Hair = "Head", ArmL = "Torso", ForeL = "ArmL", ArmR = "Torso", ForeR = "ArmR", LegL = "Root", ShinL = "LegL", LegR = "Root", ShinR = "LegR", Tail = "Torso", Staff = "Torso", Cloud = "Root", Smoke = "Cloud", Aura = "Root",
}

-- ordem de cálculo (o pai sempre antes do filho)
Anims.Order = { "Root", "Torso", "Head", "Hair", "ArmL", "ForeL", "ArmR", "ForeR", "LegL", "ShinL", "LegR", "ShinR", "Tail", "Staff", "Cloud", "Smoke", "Aura" }

Anims.gokun = {
	Name = "Fighting stance", Loop = 4, Drop = 0.0682,
	Joints = {
		Root = { 0, 0, 0 },
		Torso = { 0, 0, 4.171 },
		Head = { 0, 0.021, 6.79 },
		Hair = { 0, 0.021, 6.79 },
		ArmL = { 0.881, 0, 6.343 },
		ForeL = { 1.217, 0.021, 5.096 },
		ArmR = { -0.881, 0, 6.343 },
		ForeR = { -1.217, 0.021, 5.096 },
		LegL = { 0.408, 0, 4.085 },
		ShinL = { 0.451, -0.052, 2.236 },
		LegR = { -0.408, 0, 4.085 },
		ShinR = { -0.451, -0.052, 2.236 },
	},
	Pose = {
		Root = { c = -24 },
		Torso = { a = 5, c = -4 },
		Head = { c = 26, a = 1 },
		ArmL = { a = -50, b = -14 },
		ForeL = { a = -88 },
		ArmR = { a = 28, b = 14 },
		ForeR = { a = -105 },
		LegL = { a = -20, b = -7 },
		ShinL = { a = 20, b = 7 },
		LegR = { a = 14, b = 12 },
		ShinR = { a = 6, b = -12 },
	},
	Waves = {
		{ "Root", "z", 0.0258, 2, 0 },
		{ "Torso", "a", 1.6, 2, 0 },
		{ "Torso", "c", 2, 4, 0 },
		{ "Head", "a", -1.2, 2, 0.1 },
		{ "Hair", "a", 1.2, 2, 0.3 },
		{ "ArmL", "a", 3, 2, 0.1 },
		{ "ForeL", "a", 5, 2, 0.2 },
		{ "ArmR", "a", 2.5, 2, 0.6 },
		{ "ForeR", "a", 4, 2, 0.7 },
	},
}

Anims.super_gokun = {
	Name = "Power up", Loop = 4, Drop = 0.1177,
	Joints = {
		Root = { 0, 0, 0 },
		Torso = { 0, 0, 4.171 },
		Head = { 0, 0.021, 6.79 },
		Hair = { 0, 0.021, 6.79 },
		ArmL = { 0.881, 0, 6.343 },
		ForeL = { 1.217, 0.021, 5.096 },
		ArmR = { -0.881, 0, 6.343 },
		ForeR = { -1.217, 0.021, 5.096 },
		LegL = { 0.408, 0, 4.085 },
		ShinL = { 0.451, -0.052, 2.236 },
		LegR = { -0.408, 0, 4.085 },
		ShinR = { -0.451, -0.052, 2.236 },
		Aura = { 0, 0, 0 },
	},
	Pose = {
		Torso = { a = 7 },
		Head = { a = 6 },
		ArmL = { a = 6, b = -32 },
		ForeL = { a = -62, b = 22 },
		ArmR = { a = 6, b = 32 },
		ForeR = { a = -62, b = -22 },
		LegL = { a = -12, b = -15 },
		ShinL = { a = 12, b = 15 },
		LegR = { a = -12, b = 15 },
		ShinR = { a = 12, b = -15 },
	},
	Waves = {
		{ "Root", "x", 0.015, 0.2, 0 },
		{ "Root", "z", 0.0129, 0.25, 0.3 },
		{ "Torso", "a", 1.2, 1, 0 },
		{ "Head", "a", 1, 1, 0.2 },
		{ "Hair", "a", 2.2, 0.5, 0 },
		{ "Hair", "c", 1.5, 0.25, 0 },
		{ "ArmL", "b", 2.5, 1, 0 },
		{ "ArmR", "b", -2.5, 1, 0 },
		{ "ForeL", "a", 4, 1, 0.1 },
		{ "ForeR", "a", 4, 1, 0.1 },
		{ "Aura", "z", 0.1505, 0.5, 0 },
		{ "Aura", "c", 5, 4, 0 },
	},
}

Anims.mini_gokun = {
	Name = "Cloud rider", Loop = 4, Drop = 0,
	Joints = {
		Root = { 0, 0, 0 },
		Torso = { 0, 0, 2.821 },
		Head = { 0, 0, 4.285 },
		Hair = { 0, 0, 4.285 },
		ArmL = { 0.966, 0, 4.067 },
		ForeL = { 1.401, 0.028, 3.168 },
		ArmR = { -0.966, 0, 4.067 },
		ForeR = { -1.401, 0.028, 3.168 },
		LegL = { 0.471, 0, 2.635 },
		ShinL = { 0.525, -0.067, 1.835 },
		LegR = { -0.471, 0, 2.635 },
		ShinR = { -0.525, -0.067, 1.835 },
		Tail = { 0, 0.434, 2.728 },
		Staff = { 0, 0.713, 4.526 },
		Cloud = { 0, 0, 0 },
		Smoke = { 0, 3.1, 0 },
	},
	Pose = {
		Head = { b = 5 },
		ArmL = { a = 12, b = -38 },
		ForeL = { a = -20, b = 80 },
		ArmR = { a = -28, b = 128 },
		ForeR = { b = -22 },
		LegL = { b = -12 },
		ShinL = { b = 12 },
		LegR = { b = 12 },
		ShinR = { b = -12 },
	},
	Waves = {
		{ "Root", "z", 0.186, 2, 0 },
		{ "Root", "b", 2.5, 4, 0 },
		{ "Cloud", "c", 3, 4, 0.25 },
		{ "Smoke", "z", 0.124, 1, 0.5 },
		{ "Smoke", "y", 0.093, 2, 0 },
		{ "ForeR", "b", 16, 1, 0 },
		{ "ArmR", "b", 4, 1, 0.1 },
		{ "Tail", "c", 22, 1, 0 },
		{ "Tail", "a", 8, 2, 0 },
		{ "Head", "c", 5, 4, 0 },
		{ "Head", "b", 2, 2, 0 },
		{ "Torso", "a", 2, 2, 0 },
		{ "Hair", "a", 1.5, 2, 0.3 },
	},
}

return Anims
