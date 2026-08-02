# Ver modelos y texturas sin entrar al juego

Tres formas, de más barata a más completa. **Las dos primeras ya funcionan** — no hace falta instalar
nada.

---

## 1. Texturas: `dev/vtf2png.py` (ya funciona)

Decodifica los `.vtf` a `.png` sin dependencias raras: DXT1/DXT3/DXT5, BGRA8888 y BGR888
implementados a mano. Por defecto saca un mipmap chico (256 px), que es lo que hace falta para saber
qué es cada archivo y va mucho más rápido que decodificar un 2048².

```bash
python dev/vtf2png.py               # todo materials/ -> dev/preview/
python dev/vtf2png.py --size 1024   # más resolución
python dev/vtf2png.py --sheet       # + una hoja de contactos con todo junto
```

**Resultado actual: 58/58 convertidos, 0 fallos.** La hoja de contactos
(`dev/preview/_hoja_de_contactos.png`) ya confirmó a ojo dos cosas que se habían deducido del
binario: que los `level_01..05` del K2 son colores planos de LED (verde → rojo), y que la octava
skin del `cursed_book_open` dice *"creator Demit / Back by"* — la firma del autor, que **no** debe
entrar en el sorteo de escritura del fantasma.

## 2. Datos del modelo: `dev/mdlinfo.py` (ya funciona)

Parsea el `studiohdr_t` y escupe bodygroups, familias de skin, texturas, `cdmaterials`, masa,
`surfaceprop` e `includemodels`. **Es lo que corrigió tres afirmaciones del Workshop.**

```bash
python dev/mdlinfo.py models/ > /tmp/info.json
python dev/verify_tree.py            # cruza cada textura contra el .vmt y el .vtf en disco
```

No dibuja el modelo, pero responde casi todo lo que uno quiere saber antes de abrirlo.

## 3. El modelo en 3D: **HLMV** — ya lo tenés instalado

Viene con GMod: `d:\Steam\steamapps\common\GarrysMod\bin\hlmv.exe`. No hay que bajar nada.

**Tiene que arrancar apuntando al directorio del juego**, o abre el modelo sin materiales (todo
morado):

```bat
"d:\Steam\steamapps\common\GarrysMod\bin\hlmv.exe" -game "d:\Steam\steamapps\common\GarrysMod\garrysmod"
```

Y después *File → Load Model* apuntando al `.mdl`.

> **Por eso importa el junction.** HLMV busca los materiales bajo el árbol del juego, no al lado del
> `.mdl`. Con `garrysmod/addons/phantasmagoria` apuntando al repo, HLMV (y GMod) ven los modelos
> **con sus texturas**. Está creado desde el 2026-08-02.

En HLMV, las pestañas que importan para estos props:

| Pestaña | Para qué |
|---|---|
| **Body** | Cambiar `Skin` — así se ven los 6 niveles del K2 y las 7 escrituras del libro |
| **Model** | Bodygroups (el trípode abierto/cerrado) |
| **Physics** | El `.phy`: masa, surfaceprop, forma de colisión |
| **Sequences** | Animaciones, si tuviera |

## 4. Alternativas que **no** hacen falta acá

| Herramienta | Cuándo sí |
|---|---|
| **Crowbar** | Descompilar a SMD/QC para **editar** o recompilar (ej. cambiar `$mass` de verdad) |
| **Blender + Source Tools** | Editar la malla |
| **VTFEdit** | Editar/recomprimir texturas — sería lo que hace falta para bajar los 2048² a 1024² |
| **Noesis** | Visor rápido multi-formato, si HLMV se pone pesado |

---

## El junction

```powershell
New-Item -ItemType Junction `
  -Path   "d:\Steam\steamapps\common\GarrysMod\garrysmod\addons\phantasmagoria" `
  -Target "d:\Documentos\Materia universidad\Personal\Corpus\VSCode\phantasmagoria"
```

Sirve para dos cosas a la vez: que HLMV encuentre los materiales, y que **GMod monte el addon** para
probarlo. Se borra con `Remove-Item` sin tocar el repo.

> **Cuidado conocido de este workspace:** un junction hace que el addon se monte **además** de
> cualquier copia del Workshop. Si tenés suscritos los tres packs originales, ahora hay dos fuentes
> para las mismas rutas y GMod elige una sin avisar. Eso es exactamente lo que detecta
> `phantasmagoria_assetcheck` — y con el junction puesto es la primera vez que se lo puede probar
> de verdad.
