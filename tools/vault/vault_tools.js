#!/usr/bin/env node
/*
  vault_tools.js — ferramentas do Mapa Cerebral (vault do Obsidian) sem Python.

  Uso (Node 18+):
    node tools/vault/vault_tools.js check  [vault]   confere links quebrados, notas inalcançáveis a partir do
                                                     00_Mapa_Cerebral.md e frontmatter sem title
    node tools/vault/vault_tools.js canvas [vault]   regera Mapa_Cerebral.canvas (mapa mental visual)
    node tools/vault/vault_tools.js sync   [vault]   copia o vault para cerebro/ no repositório
                                                     (sem .obsidian/workspace*.json)

  [vault] padrão: D:\Arquivos Sistema\Obsidian\DriveACarForAnime\Drive A Car For Anime
  Regras dos links: só links markdown relativos ([texto](pasta/nota.md)); a pasta _Modelos é ignorada na
  checagem de links (os modelos têm caminhos de exemplo).
*/
const fs = require("fs");
const path = require("path");

const DEFAULT_VAULT = "D:\\Arquivos Sistema\\Obsidian\\DriveACarForAnime\\Drive A Car For Anime";
const REPO = path.resolve(__dirname, "..", "..");
const HOME = "00_Mapa_Cerebral.md";

function walk(dir, base = dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === ".obsidian" || e.name === ".trash") continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, base, out);
    else out.push(path.relative(base, full).split(path.sep).join("/"));
  }
  return out;
}

function linksOf(text) {
  const noCode = text.replace(/```[\s\S]*?```/g, "").replace(/`[^`\n]*`/g, "");
  const re = /!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
  const out = [];
  let m;
  while ((m = re.exec(noCode))) {
    const t = m[1];
    if (/^[a-z]+:/i.test(t) || t.startsWith("#")) continue;
    out.push(decodeURI(t.split("#")[0]));
  }
  return out;
}

function check(vault) {
  const files = walk(vault);
  const set = new Set(files);
  const md = files.filter((f) => f.endsWith(".md"));
  let broken = 0, noTitle = 0;
  const graph = {};
  for (const f of md) {
    const text = fs.readFileSync(path.join(vault, f), "utf8");
    if (!/^---\r?\n[\s\S]*?\btitle:/.test(text)) { console.log(`SEM TITLE   ${f}`); noTitle++; }
    graph[f] = [];
    for (const l of linksOf(text)) {
      const target = path.posix.normalize(path.posix.join(path.posix.dirname(f), l));
      graph[f].push(target);
      if (!set.has(target) && !f.startsWith("_Modelos/")) { console.log(`QUEBRADO    ${f} -> ${l}`); broken++; }
    }
  }
  const seen = new Set([HOME]);
  const queue = [HOME];
  while (queue.length) {
    const f = queue.shift();
    for (const t of graph[f] || []) if (!seen.has(t) && set.has(t)) { seen.add(t); queue.push(t); }
  }
  const orphans = md.filter((f) => !seen.has(f));
  for (const o of orphans) console.log(`INALCANÇÁVEL ${o}`);
  console.log(`\n${md.length} notas | links quebrados: ${broken} | inalcançáveis: ${orphans.length} | sem title: ${noTitle}`);
  return broken + orphans.length + noTitle === 0 ? 0 : 1;
}

function titleOf(vault, f) {
  const t = fs.readFileSync(path.join(vault, f), "utf8").match(/^title:\s*(.+)$/m);
  return t ? t[1].trim() : f;
}

function canvas(vault) {
  const files = walk(vault).filter((f) => f.endsWith(".md"));
  const folders = [...new Set(files.filter((f) => f.includes("/")).map((f) => f.split("/")[0]))].sort();
  const nodes = [], edges = [];
  const W = 300, H = 70;
  nodes.push({ id: "home", type: "file", file: HOME, x: -200, y: -60, width: 400, height: 120, color: "6" });
  const R = 1500;
  folders.forEach((folder, i) => {
    const a = (i / folders.length) * Math.PI * 2 - Math.PI / 2;
    const cx = Math.cos(a) * R, cy = Math.sin(a) * R;
    const notes = files.filter((f) => f.startsWith(folder + "/") && !f.endsWith("/INDEX.md")).sort();
    const cols = notes.length > 8 ? 2 : 1;
    const rows = Math.ceil(notes.length / cols);
    const gw = cols * (W + 20) + 40, gh = (rows + 1) * (H + 16) + 60;
    const gx = Math.round(cx - gw / 2), gy = Math.round(cy - gh / 2);
    const color = String((i % 6) + 1);
    nodes.push({ id: `g${i}`, type: "group", label: folder.replace(/_/g, " "), x: gx, y: gy, width: gw, height: gh, color });
    const idx = `${folder}/INDEX.md`;
    const idxId = `i${i}`;
    if (files.includes(idx)) {
      nodes.push({ id: idxId, type: "file", file: idx, x: gx + 20, y: gy + 40, width: gw - 40, height: H, color });
      edges.push({ id: `e${i}`, fromNode: "home", toNode: idxId, color });
    }
    notes.forEach((f, k) => {
      const c = k % cols, r = Math.floor(k / cols);
      const id = `n${i}_${k}`;
      nodes.push({ id, type: "file", file: f, x: gx + 20 + c * (W + 20), y: gy + 40 + (r + 1) * (H + 16), width: W, height: H });
    });
  });
  const out = path.join(vault, "Mapa_Cerebral.canvas");
  fs.writeFileSync(out, JSON.stringify({ nodes, edges }, null, "\t"));
  console.log(`canvas: ${nodes.length} nós, ${edges.length} ligações -> ${out}`);
  return 0;
}

function sync(vault) {
  const dest = path.join(REPO, "cerebro");
  fs.rmSync(dest, { recursive: true, force: true });
  fs.cpSync(vault, dest, {
    recursive: true,
    filter: (src) => !/workspace(-mobile)?\.json$/.test(src) && !src.includes(`${path.sep}.trash`),
  });
  console.log(`copiado: ${vault} -> ${dest}`);
  return 0;
}

const [cmd, vaultArg] = process.argv.slice(2);
const vault = vaultArg || DEFAULT_VAULT;
const fn = { check, canvas, sync }[cmd];
if (!fn) { console.log("uso: node tools/vault/vault_tools.js check|canvas|sync [vault]"); process.exit(2); }
if (!fs.existsSync(vault)) { console.log(`vault não encontrado: ${vault}`); process.exit(2); }
process.exit(fn(vault));
