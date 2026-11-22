/*
  anims_to_luau.js — gera o módulo de dados ReplicatedStorage.Shared.CharacterAnims a partir de
  arte/export/personagens_anim.json (escrito por arte/blender/char_hero.py).

    node tools/art/anims_to_luau.js            -> escreve src/ReplicatedStorage/Shared/CharacterAnims.luau

  O arquivo gerado é o texto que vai para o Studio (colar no módulo ou aplicar pelo MCP). A animação é a MESMA
  que o Blender usa no vídeo arte/renders/idle_personagens.mp4: quem mudar a pose muda em char_hero.py (IDLE),
  roda o Blender e depois este script.
*/
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', '..');
const data = JSON.parse(fs.readFileSync(path.join(root, 'arte', 'export', 'personagens_anim.json'), 'utf8'));

// id do jogo -> entrada do JSON (as skins e a versão de jogo usam a mesma animação)
const MAP = { gokun: 'gokun_v3', super_gokun: 'super_gokun_v3', mini_gokun: 'mini_gokun_v3_classic' };
const ORDER = ['Root', 'Torso', 'Head', 'Hair', 'ArmL', 'ForeL', 'ArmR', 'ForeR', 'LegL', 'ShinL', 'LegR', 'ShinR', 'Tail', 'Staff', 'Cloud', 'Smoke', 'Aura'];
const num = (v) => String(Math.round(v * 10000) / 10000);

let out = `--[[
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
`;
const parents = data[MAP.gokun].parents;
out += '\t' + ORDER.filter((p) => parents[p]).map((p) => `${p} = "${parents[p]}"`).join(', ') + ',\n}\n\n';
out += `-- ordem de cálculo (o pai sempre antes do filho)\nAnims.Order = { ${ORDER.map((p) => `"${p}"`).join(', ')} }\n`;

for (const [id, key] of Object.entries(MAP)) {
  const a = data[key];
  if (!a) throw new Error('falta ' + key + ' em personagens_anim.json');
  out += `\nAnims.${id} = {\n\tName = "${a.name}", Loop = ${num(a.loop)}, Drop = ${num(a.drop)},\n\tJoints = {\n`;
  for (const p of ORDER) if (a.joints[p]) out += `\t\t${p} = { ${a.joints[p].map(num).join(', ')} },\n`;
  out += '\t},\n\tPose = {\n';
  for (const p of ORDER) {
    if (!a.pose[p]) continue;
    out += `\t\t${p} = { ${Object.entries(a.pose[p]).map(([k, v]) => `${k} = ${num(v)}`).join(', ')} },\n`;
  }
  out += '\t},\n\tWaves = {\n';
  for (const w of a.waves) out += `\t\t{ "${w[0]}", "${w[1]}", ${num(w[2])}, ${num(w[3])}, ${num(w[4])} },\n`;
  out += '\t},\n}\n';
}
out += '\nreturn Anims\n';
const dst = path.join(root, 'src', 'ReplicatedStorage', 'Shared', 'CharacterAnims.luau');
fs.writeFileSync(dst, out);
console.log('ok', dst, out.length, 'bytes');
