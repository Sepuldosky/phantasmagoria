# -*- coding: utf-8 -*-
"""Verifica el arbol consolidado de Phantasmagoria.

Para cada .mdl bajo models/, comprueba que cada textura que declara exista
como .vmt en materials/<cdmaterial>/, y que cada $basetexture de ese .vmt
apunte a un .vtf que exista. Tambien verifica que cada .mdl tenga sus
acompanantes .vvd/.vtx.
"""
import json, os, io, re, sys, struct

ROOT = r"d:\Documentos\Materia universidad\Personal\Corpus\VSCode\phantasmagoria"
MDLJSON = os.path.join(os.path.dirname(__file__), "mdl_all.json")

mdls = json.load(io.open(MDLJSON, encoding="utf-8"))
matroot = os.path.join(ROOT, "materials")
modroot = os.path.join(ROOT, "models")

miss_vmt, miss_vtf, miss_comp, ok = [], [], [], 0

for m in mdls:
    # ruta destino del mdl dentro del arbol consolidado
    internal = m["internal_name"].replace("/", os.sep).replace("\\", os.sep)
    mdl_path = os.path.join(modroot, internal)
    if not os.path.exists(mdl_path):
        # el internal_name puede no coincidir; buscar por nombre de archivo
        for r, _, fs in os.walk(modroot):
            if m["file"] in fs:
                mdl_path = os.path.join(r, m["file"])
                break

    # acompanantes obligatorios
    stem = mdl_path[:-4]
    if not os.path.exists(stem + ".vvd"):
        miss_comp.append(m["file"] + " -> falta .vvd")
    if not any(os.path.exists(stem + e) for e in (".dx90.vtx", ".dx80.vtx", ".vtx", ".sw.vtx")):
        miss_comp.append(m["file"] + " -> falta .vtx")

    for cd in m["cdmaterials"]:
        cd = cd.replace("\\", os.sep).replace("/", os.sep).strip(os.sep)
        for tex in m["textures"]:
            vmt = os.path.join(matroot, cd, tex + ".vmt")
            if not os.path.exists(vmt):
                miss_vmt.append("%s -> materials/%s/%s.vmt" % (m["file"], cd.replace(os.sep, "/"), tex))
                continue
            ok += 1
            try:
                body = io.open(vmt, encoding="utf-8", errors="replace").read()
            except Exception:
                continue
            for mm in re.finditer(r'\$(?:basetexture|bumpmap|selfillummask|envmapmask)\s*"?\s*"?([^"\r\n\}]+?)"?\s*$',
                                  body, re.I | re.M):
                t = mm.group(1).strip().strip('"').replace("/", os.sep).replace("\\", os.sep)
                if t.lower().startswith("env_cubemap"):
                    continue
                if not os.path.exists(os.path.join(matroot, t + ".vtf")):
                    miss_vtf.append("%s -> %s.vtf" % (os.path.relpath(vmt, ROOT), t.replace(os.sep, "/")))

print("=" * 64)
print("referencias mdl->vmt resueltas : %d" % ok)
print("VMT faltantes                  : %d" % len(miss_vmt))
for x in miss_vmt: print("    " + x)
print("VMT -> VTF inexistente         : %d" % len(set(miss_vtf)))
for x in sorted(set(miss_vtf)): print("    " + x)
print("acompanantes faltantes         : %d" % len(miss_comp))
for x in miss_comp: print("    " + x)
print("=" * 64)
print("mdl en arbol : %d" % sum(1 for r, _, fs in os.walk(modroot) for f in fs if f.endswith(".mdl")))
print("vmt en arbol : %d" % sum(1 for r, _, fs in os.walk(matroot) for f in fs if f.endswith(".vmt")))
print("vtf en arbol : %d" % sum(1 for r, _, fs in os.walk(matroot) for f in fs if f.endswith(".vtf")))
