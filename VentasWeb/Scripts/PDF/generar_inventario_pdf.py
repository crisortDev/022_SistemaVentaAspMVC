# ============================================================
#  generar_inventario_pdf.py  —  Hoja de Conteo de Inventario
#  Uso: python generar_inventario_pdf.py <ruta_json> <ruta_pdf>
#  Dependencias: reportlab   (pip install reportlab)
# ============================================================

import sys
import os
import json
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from membrete import _Canvas, MARG_TOP, MARG_H

from reportlab.lib.pagesizes import A4
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)

# ── Página ─────────────────────────────────────────────────────────────────────
PAGE     = A4               # 21 × 29.7 cm, vertical
MARG_BOT = 2.2 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 18 cm útil

# ── Colores ────────────────────────────────────────────────────────────────────
AZUL     = colors.HexColor('#1a3566')
AZUL_CLR = colors.HexColor('#e8edf5')
VERDE    = colors.HexColor('#059669')
GRIS_L   = colors.HexColor('#f3f4f6')
GRIS_M   = colors.HexColor('#d1d5db')
GRIS_D   = colors.HexColor('#6b7280')
BLANCO   = colors.white
ROJO_CLR = colors.HexColor('#fee2e2')

# ── Estilos ────────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']

_cnt = [0]
def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=8, leading=11)
    d.update(kw)
    return ParagraphStyle(**d)

ST_TITLE   = _sty(fontSize=13, fontName='Helvetica-Bold', textColor=AZUL,
                  alignment=TA_CENTER, spaceAfter=2)
ST_SUBTITLE= _sty(fontSize=8.5, fontName='Helvetica-Bold', textColor=AZUL,
                  alignment=TA_CENTER, spaceAfter=6)
ST_LBL     = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=AZUL)
ST_VAL     = _sty(fontSize=8,   fontName='Helvetica',      leading=11)
ST_HDR     = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO,
                  alignment=TA_CENTER)
ST_HDR_L   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO)
ST_CELL    = _sty(fontSize=7.5, leading=10)
ST_CELL_C  = _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_CELL_R  = _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_NOTA    = _sty(fontSize=7,   textColor=GRIS_D, leading=9)
ST_FIRMA   = _sty(fontSize=7.5, alignment=TA_CENTER)

def P(txt, sty):
    return Paragraph(str(txt) if txt else '', sty)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]



# ── Tabla de información de cabecera ──────────────────────────────────────────
def info_table(hdr):
    w1 = 3.2 * cm   # etiqueta col izq
    w2 = 5.5 * cm   # valor col izq
    gap = 0.4 * cm
    w3 = 2.8 * cm   # etiqueta col der
    w4 = PAGE_W - w1 - w2 - gap - w3

    rows = [
        [P('N° Inventario:',  ST_LBL), P(hdr.get('Numero',''),        ST_VAL),
         P('Sucursal:',        ST_LBL), P(hdr.get('NombreTienda',''),  ST_VAL)],
        [P('Supervisor:',      ST_LBL), P(hdr.get('Supervisor',''),    ST_VAL),
         P('Estado:',          ST_LBL), P(hdr.get('Estado',''),        ST_VAL)],
        [P('Repositor(es):',   ST_LBL), P(hdr.get('Operadores',''),    ST_VAL),
         P('Apertura:',        ST_LBL), P(hdr.get('FechaRegistro',''), ST_VAL)],
        [P('Observacion:',     ST_LBL), P(hdr.get('Observacion',''),   ST_VAL),
         P('Fin conteo:',      ST_LBL), P(hdr.get('FechaFinalizacion','') or '—', ST_VAL)],
    ]

    t = Table(rows, colWidths=[w1, w2, w3, w4])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AZUL_CLR),
        ('GRID',          (0,0), (-1,-1), 0.5,  GRIS_M),
        ('TOPPADDING',    (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING',   (0,0), (-1,-1), 5),
        ('RIGHTPADDING',  (0,0), (-1,-1), 5),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        # Span "observacion" col del centro a col der si hace falta
        ('SPAN',          (1,3), (3,3)),   # valor Observacion ocupa las 3 columnas restantes
    ]))
    return t


# ── Tabla de productos ────────────────────────────────────────────────────────
#  Columnas: N° | Código | Producto | Categoría | Stock Sis. | Conteo Físico | Diferencia
def productos_table(prods):
    # anchos en cm (total = PAGE_W ~18 cm)
    CW = [0.9, 2.1, 5.5, 3.2, 1.6, 2.4, 2.3]

    headers = [
        P('N°',          ST_HDR),
        P('Código',      ST_HDR),
        P('Producto',    ST_HDR_L),
        P('Categoría',   ST_HDR_L),
        P('Stock\nSist.',ST_HDR),
        P('Conteo\nFísico', ST_HDR),
        P('Diferencia',  ST_HDR),
    ]
    data = [headers]

    for p in prods:
        data.append([
            P(str(p.get('NumFila', '')),   ST_CELL_C),
            P(p.get('Codigo', ''),          ST_CELL_C),
            P(p.get('Nombre', ''),          ST_CELL),
            P(p.get('Categoria', ''),       ST_CELL),
            P(str(p.get('Stock', '')),      ST_CELL_C),
            P('',                           ST_CELL_C),  # Conteo Físico — en blanco
            P('',                           ST_CELL_C),  # Diferencia    — en blanco
        ])

    t = Table(data, colWidths=[w * cm for w in CW], repeatRows=1)
    n = len(data)
    ts = TableStyle(CELL_PAD + [
        # Header azul
        ('BACKGROUND',     (0,0),  (-1,0),   AZUL),
        # Filas alternas
        ('ROWBACKGROUNDS', (0,1),  (-1,-1),  [BLANCO, GRIS_L]),
        # Borde general
        ('GRID',           (0,0),  (-1,-1),  0.3, GRIS_M),
        # Borde derecho más grueso para separar columnas de escritura a mano
        ('LINEAFTER',      (4,-1), (4,-1),   0.8, AZUL),   # después de Stock Sist.
        # Fondo levemente diferente en columnas de relleno manual
        ('BACKGROUND',     (5,1),  (6,-1),   colors.HexColor('#fffbeb')),
    ])
    t.setStyle(ts)
    return t


# ── Resumen del conteo (para completar a mano) ───────────────────────────────
def resumen_table():
    AMARILLO = colors.HexColor('#fefce8')
    BORDE    = colors.HexColor('#ca8a04')

    filas = [
        [P('<b>Concepto</b>', ST_HDR_L), P('<b>Resultado</b>', ST_HDR)],
        [P('Total productos revisados', ST_CELL),  P('', ST_CELL_C)],
        [P('Productos encontrados',     ST_CELL),  P('', ST_CELL_C)],
        [P('Productos sin existencia',  ST_CELL),  P('', ST_CELL_C)],
        [P('Productos pendientes',      ST_CELL),  P('', ST_CELL_C)],
    ]

    w_concepto = 7.0 * cm
    w_result   = 3.0 * cm

    t = Table(filas, colWidths=[w_concepto, w_result])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',    (0,0), (-1,0),  AZUL),
        ('BACKGROUND',    (0,1), (-1,-1), AMARILLO),
        ('GRID',          (0,0), (-1,-1), 0.5, BORDE),
        ('ALIGN',         (1,0), (1,-1),  'CENTER'),
        ('FONTNAME',      (0,1), (0,-1),  'Helvetica'),
        ('FONTSIZE',      (0,0), (-1,-1), 7.5),
    ]))
    return t


# ── Sección de firmas ─────────────────────────────────────────────────────────
def firmas_section():
    w = PAGE_W / 3.0
    data = [[
        P('_______________________\nFirma del Repositor',    ST_FIRMA),
        P('',                                                  ST_FIRMA),
        P('_______________________\nFirma del Supervisor',   ST_FIRMA),
    ]]
    t = Table(data, colWidths=[w, w, w])
    t.setStyle(TableStyle([
        ('TOPPADDING',    (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING',   (0,0), (-1,-1), 0),
        ('RIGHTPADDING',  (0,0), (-1,-1), 0),
        ('VALIGN',        (0,0), (-1,-1), 'TOP'),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    hdr           = data.get('Header')   or {}
    prods         = data.get('Productos') or []
    empresa       = data.get('NombreEmpresa', hdr.get('NombreTienda', ''))
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')

    numero    = hdr.get('Numero', 'SIN NUMERO')
    tienda    = hdr.get('NombreTienda', '')
    filtros   = 'N° Inventario: ' + numero

    # Período: fecha de apertura — fecha de fin (si existe)
    fecha_ini = (hdr.get('FechaRegistro',     '') or '').split(' ')[0]
    fecha_fin = (hdr.get('FechaFinalizacion', '') or '').split(' ')[0]
    if fecha_ini and fecha_fin:
        periodo = fecha_ini + ' — ' + fecha_fin
    elif fecha_ini:
        periodo = fecha_ini
    else:
        periodo = ''

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Hoja de Inventario ' + numero
    )

    cb    = _Canvas('Hoja de Conteo de Inventario Fisico', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    # Cabecera de datos
    story.append(info_table(hdr))
    story.append(Spacer(1, 8))

    # Leyenda de columnas vacías
    story.append(P(
        '<font color="#6b7280">*&nbsp;Las columnas <b>Conteo Físico</b> y '
        '<b>Diferencia</b> deben completarse manualmente durante la toma de inventario.</font>',
        ST_NOTA
    ))
    story.append(Spacer(1, 5))

    # Tabla de productos
    if prods:
        story.append(productos_table(prods))
    else:
        story.append(P('No hay productos asociados a esta tienda.', ST_VAL))

    story.append(Spacer(1, 14))

    # Resumen del conteo
    story.append(P('<b>Resumen del Conteo</b>', ST_LBL))
    story.append(Spacer(1, 4))
    story.append(resumen_table())
    story.append(Spacer(1, 14))

    # Espacio de observaciones del repositor
    story.append(P('<b>Observaciones del repositor:</b>', ST_LBL))
    story.append(Spacer(1, 3))
    for _ in range(3):
        story.append(HRFlowable(width='100%', thickness=0.5,
                                color=GRIS_M, spaceAfter=8))

    story.append(Spacer(1, 10))

    # Firmas
    story.append(firmas_section())

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_inventario_pdf.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
