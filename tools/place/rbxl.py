"""Leitor mínimo de arquivos binários do Roblox (.rbxl / .rbxm) — Drive A Car For Anime.

Por que existe: o código do jogo vive dentro do Roblox Studio. Este leitor transforma o place
salvo ("Arquivo > Baixar uma cópia") em dados Python, para extrair scripts para o Git e
inspecionar o mapa sem abrir o Studio. Só LÊ; nunca grava .rbxl.

Formato: cabeçalho "<roblox!" + chunks META/SSTR/INST/PROP/PRNT/END, cada um comprimido com
zstd ou LZ4 (especificação pública: https://dom.rojo.space/binary.html).
Tipos de propriedade não suportados são ignorados e listados em `problems` (não quebram a leitura).

Descompressão (tenta nesta ordem):
  1. pacotes Python `zstandard` / `lz4`   (pip install zstandard lz4  — recomendado no Windows/macOS)
  2. bibliotecas do sistema libzstd / liblz4 via ctypes (Linux já costuma ter)
"""
import ctypes, ctypes.util, struct


def _load_zstd():
    try:
        import zstandard  # type: ignore
        dctx = zstandard.ZstdDecompressor()
        return lambda data, size: dctx.decompress(data, max_output_size=size)
    except ImportError:
        pass
    name = ctypes.util.find_library("zstd") or "libzstd.so.1"
    lib = ctypes.CDLL(name)
    lib.ZSTD_decompress.restype = ctypes.c_size_t
    lib.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]

    def dec(data, size):
        out = ctypes.create_string_buffer(size)
        src = ctypes.create_string_buffer(data, len(data))
        n = lib.ZSTD_decompress(out, size, src, len(data))
        if lib.ZSTD_isError(n):
            raise ValueError("zstd error")
        return out.raw[:n]
    return dec


def _load_lz4():
    try:
        import lz4.block  # type: ignore
        return lambda data, size: lz4.block.decompress(data, uncompressed_size=size)
    except ImportError:
        pass
    name = ctypes.util.find_library("lz4") or "liblz4.so.1"
    lib = ctypes.CDLL(name)
    lib.LZ4_decompress_safe.restype = ctypes.c_int
    lib.LZ4_decompress_safe.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]

    def dec(data, size):
        out = ctypes.create_string_buffer(size)
        n = lib.LZ4_decompress_safe(data, out, len(data), size)
        if n < 0:
            raise ValueError("lz4 error")
        return out.raw[:n]
    return dec


_zstd_dec = _lz4_dec = None


def _decompress(data, size):
    global _zstd_dec, _lz4_dec
    if data[:4] == b"\x28\xb5\x2f\xfd":
        _zstd_dec = _zstd_dec or _load_zstd()
        return _zstd_dec(data, size)
    _lz4_dec = _lz4_dec or _load_lz4()
    return _lz4_dec(data, size)


class R:
    def __init__(self, b):
        self.b, self.p = b, 0

    def take(self, n):
        v = self.b[self.p:self.p + n]
        if len(v) < n:
            raise EOFError
        self.p += n
        return v

    def u8(self): return self.take(1)[0]
    def u16(self): return struct.unpack("<H", self.take(2))[0]
    def u32(self): return struct.unpack("<I", self.take(4))[0]
    def i32(self): return struct.unpack("<i", self.take(4))[0]
    def f32(self): return struct.unpack("<f", self.take(4))[0]
    def f64(self): return struct.unpack("<d", self.take(8))[0]
    def str(self): return self.take(self.u32())
    def done(self): return self.p >= len(self.b)

    def interleaved(self, n, k):
        raw = self.take(n * k)
        return [bytes(raw[j * n + i] for j in range(k)) for i in range(n)]

    def i32s(self, n):
        out = []
        for v in self.interleaved(n, 4):
            x = int.from_bytes(v, "big")
            out.append((x >> 1) ^ -(x & 1))
        return out

    def u32s(self, n):
        return [int.from_bytes(v, "big") for v in self.interleaved(n, 4)]

    def i64s(self, n):
        out = []
        for v in self.interleaved(n, 8):
            x = int.from_bytes(v, "big")
            out.append((x >> 1) ^ -(x & 1))
        return out

    def f32s(self, n):
        out = []
        for v in self.interleaved(n, 4):
            x = int.from_bytes(v, "big")
            x = ((x >> 1) | (x << 31)) & 0xFFFFFFFF
            out.append(struct.unpack("<f", struct.pack("<I", x))[0])
        return out

    def refs(self, n):
        acc, out = 0, []
        for d in self.i32s(n):
            acc += d
            out.append(acc)
        return out


class Instance:
    __slots__ = ("ref", "cls", "props", "children", "parent", "skipped")

    def __init__(self, ref, cls):
        self.ref, self.cls = ref, cls
        self.props, self.children, self.parent, self.skipped = {}, [], None, []

    @property
    def name(self):
        n = self.props.get("Name", self.cls)
        return n if isinstance(n, str) else self.cls

    def path(self):
        parts, n = [], self
        while n is not None and n.cls != "DataModel":
            parts.append(n.name)
            n = n.parent
        return ".".join(reversed(parts))

    def find(self, *names):
        n = self
        for nm in names:
            n = next((c for c in n.children if c.name == nm), None)
            if n is None:
                return None
        return n

    def descendants(self):
        st = list(reversed(self.children))
        while st:
            n = st.pop()
            yield n
            st.extend(reversed(n.children))


_NORMALS = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]


def _dec(b):
    try:
        return b.decode("utf-8")
    except UnicodeDecodeError:
        return b


def _cframes(r, n):
    rots = []
    for _ in range(n):
        rid = r.u8()
        if rid == 0:
            rots.append(tuple(r.f32() for _ in range(9)))
        else:
            idx = rid - 1
            xv, yv = _NORMALS[idx // 6], _NORMALS[idx % 6]
            zv = (xv[1] * yv[2] - xv[2] * yv[1], xv[2] * yv[0] - xv[0] * yv[2], xv[0] * yv[1] - xv[1] * yv[0])
            rots.append((xv[0], yv[0], zv[0], xv[1], yv[1], zv[1], xv[2], yv[2], zv[2]))
    xs, ys, zs = r.f32s(n), r.f32s(n), r.f32s(n)
    return [("CFrame", (xs[i], ys[i], zs[i]), rots[i]) for i in range(n)]


def _read_values(r, t, n, sstr):
    if t in (0x01, 0x1D):
        return [_dec(r.str()) for _ in range(n)]
    if t == 0x02:
        return [b != 0 for b in r.take(n)]
    if t == 0x03:
        return r.i32s(n)
    if t == 0x04:
        return r.f32s(n)
    if t == 0x05:
        return [r.f64() for _ in range(n)]
    if t == 0x06:
        s, o = r.f32s(n), r.i32s(n)
        return [("UDim", s[i], o[i]) for i in range(n)]
    if t == 0x07:
        sx, sy, ox, oy = r.f32s(n), r.f32s(n), r.i32s(n), r.i32s(n)
        return [("UDim2", sx[i], ox[i], sy[i], oy[i]) for i in range(n)]
    if t == 0x08:
        return [("Ray", tuple(r.f32() for _ in range(6))) for _ in range(n)]
    if t in (0x09, 0x0A):
        return list(r.take(n))
    if t == 0x0B:
        return [("BrickColor", v) for v in r.u32s(n)]
    if t == 0x0C:
        a, b, c = r.f32s(n), r.f32s(n), r.f32s(n)
        return [("Color3", a[i], b[i], c[i]) for i in range(n)]
    if t == 0x0D:
        a, b = r.f32s(n), r.f32s(n)
        return [("Vector2", a[i], b[i]) for i in range(n)]
    if t == 0x0E:
        a, b, c = r.f32s(n), r.f32s(n), r.f32s(n)
        return [("Vector3", a[i], b[i], c[i]) for i in range(n)]
    if t == 0x10:
        return _cframes(r, n)
    if t == 0x12:
        return [("Enum", v) for v in r.u32s(n)]
    if t == 0x13:
        return [("Ref", v) for v in r.refs(n)]
    if t == 0x14:
        return [("Vector3int16", struct.unpack("<hhh", r.take(6))) for _ in range(n)]
    if t == 0x15:
        out = []
        for _ in range(n):
            k = r.u32()
            out.append(("NumberSequence", [tuple(r.f32() for _ in range(3)) for _ in range(k)]))
        return out
    if t == 0x16:
        out = []
        for _ in range(n):
            k = r.u32()
            out.append(("ColorSequence", [tuple(r.f32() for _ in range(5)) for _ in range(k)]))
        return out
    if t == 0x17:
        return [("NumberRange", r.f32(), r.f32()) for _ in range(n)]
    if t == 0x18:
        a, b, c, d = r.f32s(n), r.f32s(n), r.f32s(n), r.f32s(n)
        return [("Rect", a[i], b[i], c[i], d[i]) for i in range(n)]
    if t == 0x19:
        out = []
        for _ in range(n):
            f = r.u8()
            if f & 1:
                vals = [r.f32() for _ in range(5)]
                if f & 2:
                    vals.append(r.f32())
                out.append(("PhysicalProperties", tuple(vals)))
            else:
                out.append(("PhysicalProperties", None))
        return out
    if t == 0x1A:
        a, b, c = r.take(n), r.take(n), r.take(n)
        return [("Color3", a[i] / 255, b[i] / 255, c[i] / 255) for i in range(n)]
    if t == 0x1B:
        return r.i64s(n)
    if t == 0x1C:
        return [("SharedString", sstr[i] if i < len(sstr) else None) for i in r.u32s(n)]
    if t == 0x1E:
        r.u8()
        cfs = _cframes(r, n)
        r.u8()
        has = r.take(n)
        return [cfs[i] if has[i] else None for i in range(n)]
    if t == 0x1F:
        return [("UniqueId", v.hex()) for v in r.interleaved(n, 16)]
    if t == 0x20:
        out = []
        for _ in range(n):
            fam = _dec(r.str()); w = r.u16(); st = r.u8(); r.str()
            out.append(("Font", fam, w, st))
        return out
    if t == 0x21:
        return r.i64s(n)
    if t == 0x22:
        kinds = r.i32s(n)
        uris = [_dec(r.str()) for _ in range(r.u32())]
        k = r.u32(); objs = r.refs(k)
        k = r.u32(); r.refs(k)
        out, ui, oi = [], 0, 0
        for kd in kinds:
            if kd == 1 and ui < len(uris):
                out.append(("Content", uris[ui])); ui += 1
            elif kd == 2 and oi < len(objs):
                out.append(("ContentObject", objs[oi])); oi += 1
            else:
                out.append(None)
        return out
    raise NotImplementedError(t)


def load(path):
    data = open(path, "rb").read()
    if data[:8] != b"<roblox!":
        raise ValueError("not a binary roblox file")
    r = R(data)
    r.take(14); r.u16(); r.i32(); r.i32(); r.take(8)
    classes, insts, sstr, meta, problems = {}, {}, [], {}, []
    prnt = None
    while not r.done():
        name = r.take(4).rstrip(b"\0").decode()
        clen, ulen = r.u32(), r.u32(); r.u32()
        body = r.take(clen) if clen else r.take(ulen)
        if clen:
            body = _decompress(body, ulen)
        c = R(body)
        if name == "END":
            break
        if name == "META":
            for _ in range(c.u32()):
                meta[_dec(c.str())] = _dec(c.str())
        elif name == "SSTR":
            c.u32()
            for _ in range(c.u32()):
                c.take(16); sstr.append(c.str())
        elif name == "INST":
            cid = c.u32(); cname = c.str().decode(); c.u8(); n = c.u32()
            refs = c.refs(n)
            classes[cid] = (cname, refs)
            for ref in refs:
                insts[ref] = Instance(ref, cname)
        elif name == "PROP":
            cid = c.u32(); pname = c.str().decode(); t = c.u8()
            cname, refs = classes[cid]
            try:
                vals = _read_values(c, t, len(refs), sstr)
                for ref, v in zip(refs, vals):
                    insts[ref].props[pname] = v
            except Exception as e:  # keep going; one bad prop type shouldn't kill the parse
                problems.append((cname, pname, t, repr(e)))
        elif name == "PRNT":
            c.u8(); n = c.u32()
            prnt = (c.refs(n), c.refs(n))
    root = Instance(-1, "DataModel")
    if prnt:
        for ch, pa in zip(*prnt):
            node = insts.get(ch)
            if node is None:
                continue
            parent = insts.get(pa, root) if pa != -1 else root
            node.parent = parent
            parent.children.append(node)
    return root, meta, problems, insts
