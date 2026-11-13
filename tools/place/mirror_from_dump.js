/*
  mirror_from_dump.js — atualiza src/ a partir de um "despejo" de scripts feito no Roblox Studio pelo MCP.
  ======================================================================================================
  POR QUE EXISTE: o PC do dono não tem Python, então tools/place/place_tool.py não roda lá. Este script faz
  o mesmo trabalho (place -> src/) com Node, sem precisar baixar o .rbxl.

  COMO FUNCIONA: a resposta do execute_luau é cortada em 100.000 bytes, mas quando passa do limite de tokens o
  Claude Code grava a resposta num arquivo .txt (pasta tool-results). Então o despejo sai em PARTES de até
  90.000 bytes, cortadas em fim de linha; este script junta as partes na ordem e reparte em arquivos.

  COMO USAR (Claude Code local, com o MCP do Roblox Studio, Studio em modo Edit):
    1. Rode o trecho DUMP abaixo com parte = 1. A resposta diz "@@@PARTS 1/N". Repita com parte = 2..N.
       (Cada resposta vira um arquivo; uma parte pequena demais para virar arquivo aparece na conversa:
        nesse caso aumente "pular" para sobrar menos, ou grave o texto à mão.)
    2. node tools/place/mirror_from_dump.js <parte1.txt> <parte2.txt> ...   (na ordem)
    3. git diff --stat

  TRECHO DUMP (cole no execute_luau):
    local parte = 1
    local pular = { "ServerStorage.Tools", "ServerStorage.LegacyCode" }  -- pastas grandes que NÃO mudaram ({} = tudo)
    local roots = { game.ServerScriptService, game.ReplicatedStorage, game.ServerStorage, game.StarterPlayer }
    local list = {}
    for _, r in ipairs(roots) do
      for _, d in ipairs(r:GetDescendants()) do
        if d:IsA("LuaSourceContainer") and not d:IsDescendantOf(game.ServerStorage.Backups) then
          local skip = false
          for _, pre in ipairs(pular) do if d:GetFullName():sub(1, #pre) == pre then skip = true end end
          if not skip then table.insert(list, d) end
        end
      end
    end
    table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end)
    local out = {}
    for _, d in ipairs(list) do
      local s = d.Source:gsub("\r", "")
      out[#out + 1] = ("@@@FILE %s %s %d\n%s\n"):format(d:GetFullName(), d.ClassName, #s, s)
    end
    local blob = table.concat(out)
    local LIM, parts, pos = 90000, {}, 1
    while pos <= #blob do
      local stop = math.min(#blob, pos + LIM - 1)
      if stop < #blob then
        local nl = stop
        while nl > pos and blob:byte(nl) ~= 10 do nl -= 1 end
        if nl > pos then stop = nl end
      end
      parts[#parts + 1] = blob:sub(pos, stop)
      pos = stop + 1
    end
    return ("@@@PARTS %d/%d\n"):format(parte, #parts) .. (parts[parte] or "")

  FORMATO DE CADA REGISTRO:  @@@FILE <caminho.com.pontos> <ClassName> <tamanho em bytes>\n<source>\n
  O tamanho é usado para cortar o source, então o conteúdo pode ter qualquer texto, inclusive "@@@FILE".

  NOMES DE ARQUIVO (mesma convenção do place_tool.py / Rojo):
    Script -> .server.luau | LocalScript -> .client.luau | ModuleScript -> .luau
    script com filhos-script -> pasta/init.luau (ou init.server.luau / init.client.luau)

  SEGURANÇA: se alguma parte faltar ou um registro vier cortado, o script para SEM gravar nada.
*/
const fs = require('fs');
const path = require('path');

const repo = path.resolve(__dirname, '..', '..');
const srcRoot = path.join(repo, 'src');
const EXT = { Script: '.server.luau', LocalScript: '.client.luau', ModuleScript: '.luau' };

// 1) junta as partes (tirando a linha "@@@PARTS k/n" de cada uma) e confere se estão todas, na ordem
const chunks = [];
let total = null;
process.argv.slice(2).forEach((file, i) => {
  const buf = Buffer.from(fs.readFileSync(file).filter((b) => b !== 13));
  const eol = buf.indexOf(10);
  const m = buf.slice(0, eol).toString('utf8').match(/^@@@PARTS (\d+)\/(\d+)$/);
  if (!m) { console.error('Sem cabeçalho @@@PARTS: ' + file); process.exit(1); }
  if (Number(m[1]) !== i + 1) { console.error(`Fora de ordem: ${file} é a parte ${m[1]}, esperava ${i + 1}`); process.exit(1); }
  total = Number(m[2]);
  chunks.push(buf.slice(eol + 1));
});
if (total === null || chunks.length !== total) { console.error(`Faltam partes: recebi ${chunks.length} de ${total}`); process.exit(1); }
const buf = Buffer.concat(chunks);
if (buf.includes(Buffer.from('... (truncated)'))) { console.error('Uma parte veio cortada pelo MCP ("... (truncated)").'); process.exit(1); }

// 2) lê os registros
const records = [];
let pos = 0;
while (pos < buf.length) {
  const eol = buf.indexOf(10, pos);
  const header = buf.slice(pos, eol).toString('utf8');
  const m = header.match(/^@@@FILE (\S+) (\S+) (\d+)$/);
  if (!m) { console.error('Registro inesperado na posição ' + pos + ': ' + header.slice(0, 80)); process.exit(1); }
  const size = Number(m[3]);
  const source = buf.slice(eol + 1, eol + 1 + size);
  if (source.length !== size) { console.error('TRUNCADO: ' + m[1]); process.exit(1); }
  records.push({ full: m[1], cls: m[2], source });
  pos = eol + 1 + size + 1; // + o "\n" que fecha o registro
}

// 3) grava. Quem tem filhos-script vira pasta com init.
const parents = new Set(records.map((r) => r.full.split('.').slice(0, -1).join('.')));
let written = 0, same = 0;
for (const r of records) {
  const parts = r.full.split('.');
  const ext = EXT[r.cls] || '.luau';
  const rel = parents.has(r.full)
    ? path.join(...parts, 'init' + ext)
    : path.join(...parts.slice(0, -1), parts[parts.length - 1] + ext);
  const dest = path.join(srcRoot, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  let old = null;
  if (fs.existsSync(dest)) old = Buffer.from(fs.readFileSync(dest).filter((b) => b !== 13));
  if (old && old.equals(r.source)) { same++; continue; }
  fs.writeFileSync(dest, r.source);
  written++;
  console.log((old ? 'atualizado  ' : 'NOVO        ') + path.relative(repo, dest).split(path.sep).join('/'));
}
console.log(`${records.length} scripts lidos: ${written} gravados, ${same} iguais.`);
