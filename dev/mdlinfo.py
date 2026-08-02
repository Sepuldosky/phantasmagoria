# -*- coding: utf-8 -*-
"""Parser del header studiohdr_t de un .mdl de Source.

Extrae lo que decide si un prop sirve: bodygroups (y sus submodelos), familias
de skin, materiales referenciados + las carpetas cdmaterials donde el binario
los busca, includemodels, y datos fisicos.

No adivina nada del nombre del archivo: todo sale del binario.
"""
import struct, os, sys, io, json

def cstr(d, off):
    if off <= 0 or off >= len(d):
        return ""
    e = d.index(b"\0", off)
    return d[off:e].decode("ascii", "replace")

def parse(path):
    d = open(path, "rb").read()
    if d[:4] != b"IDST":
        return {"error": "no es IDST (mdl valido)"}
    u = lambda o: struct.unpack_from("<i", d, o)[0]
    f = lambda o: struct.unpack_from("<f", d, o)[0]

    r = {
        "file": os.path.basename(path),
        "bytes": len(d),
        "version": u(4),
        "checksum": u(8),
        "internal_name": cstr(d, 12),
        "flags": u(152),
        "numbones": u(156),
        "numseq": u(188),
        "mass": f(328),
        "contents": u(332),
    }
    r["surfaceprop"] = cstr(d, u(308))

    # --- texturas (nombres sueltos, sin carpeta) ---
    ntex, texidx = u(204), u(208)
    tex = []
    for i in range(ntex):
        base = texidx + i * 64
        tex.append(cstr(d, base + u(base)))
    r["textures"] = tex

    # --- cdmaterials: las carpetas horneadas donde busca esos nombres ---
    ncd, cdidx = u(212), u(216)
    cds = []
    for i in range(ncd):
        cds.append(cstr(d, struct.unpack_from("<i", d, cdidx + i * 4)[0]))
    r["cdmaterials"] = cds

    # --- skins ---
    r["numskinref"] = u(220)
    r["numskinfamilies"] = u(224)
    skinidx = u(228)
    fams = []
    for fam in range(r["numskinfamilies"]):
        row = []
        for ref in range(r["numskinref"]):
            off = skinidx + (fam * r["numskinref"] + ref) * 2
            row.append(struct.unpack_from("<h", d, off)[0])
        fams.append(row)
    r["skin_table"] = fams

    # --- bodyparts / bodygroups ---
    nbp, bpidx = u(232), u(236)
    bps = []
    for i in range(nbp):
        base = bpidx + i * 16
        name = cstr(d, base + u(base))
        nmodels = u(base + 4)
        modelindex = u(base + 12)
        subs = []
        for m in range(nmodels):
            mbase = base + modelindex + m * 148
            mname = cstr(d, mbase) if mbase < len(d) else ""
            nverts = u(mbase + 68) if mbase + 72 < len(d) else 0
            subs.append({"name": mname, "verts": nverts})
        bps.append({"name": name, "nmodels": nmodels, "submodels": subs})
    r["bodyparts"] = bps

    # --- includemodels ---
    ninc, incidx = u(336), u(340)
    incs = []
    for i in range(ninc):
        base = incidx + i * 8
        incs.append(cstr(d, base + u(base + 4)))
    r["includemodels"] = incs
    return r

def main():
    roots = sys.argv[1:]
    out = []
    for root in roots:
        for dirpath, _, files in os.walk(root):
            for fn in sorted(files):
                if fn.endswith(".mdl"):
                    p = os.path.join(dirpath, fn)
                    info = parse(p)
                    info["path"] = p
                    out.append(info)
    print(json.dumps(out, indent=1, ensure_ascii=False))

main()
