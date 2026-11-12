/*
  mirror_from_dump.js — atualiza src/ a partir de um "despejo" de scripts feito no Roblox Studio pelo MCP.
  ======================================================================================================
  POR QUE EXISTE: o PC do dono não tem Python, então tools/place/place_tool.py não roda lá. Este script faz
  o mesmo trabalho (place -> src/) com Node, sem precisar baixar o .rbxl.

  COMO USAR (Claude Code local, com o MCP do Roblox Studio):
    1. No Studio (execute_luau, modo Edit), rode o trecho DUMP abaixo. Como a resposta é grande, o Claude Code
       grava a saída num arquivo .txt (pasta tool-results) e mostra o caminho.
    2. node tools/place/mirror_from_dump.js <arquivo.txt> [<arquivo2.txt> ...]
    3. git diff --stat

  TRECHO DUMP (cole no execute_luau; "parte" divide em blocos para não estourar o limite da resposta):
    local parte, tamanho = 1, 160000
    local roots = { game.ServerScriptService, game.ReplicatedStorage, game.ServerStorage, game.StarterPlayer }
    local list = {}
    for _, r in ipairs(roots) do
      for _, d in ipairs(r:GetDescendants()) do
        if d:IsA("LuaSourceContainer") and not d:IsDescendantOf(game.ServerStorage.Backups) then table.insert(list, d) end
      end
    end
    table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end)
    local out, bloco, acc = {}, 1, 0
    for _, d in ipairs(list) do
      local s = d.Source:gsub("\r", "")
      if acc > 0 and acc + #s > tamanho then bloco += 1 acc = 0 end
      acc += #s
      local kids = #d:GetChildren() > 0 and 1 or 0
      if bloco == parte then
        table.insert(out, ("@@@FILE %s %s %d %d\n%s\n"):format(d:GetFullName(), d.ClassName, kids, #s, s))
      end
    end
    return "@@@PARTS " .. bloco .. "\n" .. table.concat(out)

  FORMATO DE CADA REGISTRO:  @@@FILE <caminho.com.pontos> <ClassName> <temFilhos 0|1> <tamanho>\n<source>\n
  O tamanho (em bytes UTF-8, igual ao # do Luau) é usado para cortar o source, então o conteúdo pode ter
  qualquer texto, inclusive "@@@FILE".

  NOMES DE ARQUIVO (mesma convenção do place_tool.py / Rojo):
    Script -> .server.luau | LocalScript -> .client.luau | ModuleScript -> .luau
    script com filhos-script -> pasta/init.luau (ou init.server.luau / init.client.luau)
*/
const fs = require('fs');
const path = require('path');

const repo = path.resolve(__dirname, '..', '..');
const srcRoot = path.join(repo, 'src');
const EXT = { Script: '.server.luau', LocalScript: '.client.luau', ModuleScript: '.luau' };

const records = [];
for (const file of process.argv.slice(2)) {
  const buf = fs.readFileSync(file);
  let pos = 0;
  const marker = Buffer.from('@@@FILE ');
  while (true) {
    const at = buf.indexOf(marker, pos);
    if (at < 0) break;
    const eol = buf.indexOf(10, at);
    const header = buf.slice(at + marker.length, eol).toString('utf8').replace(/\r$/, '');
    const m = header.match(/^(\S+) (\S+) (\d) (\d+)$/);
    if (!m) { pos = eol + 1; continue; }
    const size = Number(m[4]);
    // O arquivo salvo pode ter CRLF: lê "size" bytes contando só os que não são \r.
    const bytes = [];
    let i = eol + 1;
    while (bytes.length < size && i < buf.length) { if (buf[i] !== 13) bytes.push(buf[i]); i++; }
    if (bytes.length !== size) { console.error('TRUNCADO: ' + m[1]); process.exitCode = 1; }
    records.push({ full: m[1], cls: m[2], kids: m[3] === '1', source: Buffer.from(bytes) });
    pos = i;
  }
}
if (records.length === 0) { console.error('Nenhum registro @@@FILE encontrado.'); process.exit(1); }

// Quem tem filhos-script vira pasta com init.
const hasScriptChild = new Set();
for (const r of records) {
  const parent = r.full.split('.').slice(0, -1).join('.');
  hasScriptChild.add(parent);
}

let written = 0, same = 0;
for (const r of records) {
  const parts = r.full.split('.');
  const ext = EXT[r.cls] || '.luau';
  let rel;
  if (hasScriptChild.has(r.full)) rel = path.join(...parts, 'init' + ext);
  else rel = path.join(...parts.slice(0, -1), parts[parts.length - 1] + ext);
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
