# ============================================================
#  generar_reporte_proveedores.py
#  Reporte de Proveedores — Landscape A4
#  Uso: python generar_reporte_proveedores.py <json> <pdf>
#  Dependencias: reportlab
# ============================================================

import sys
import os
import json
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from membrete import _Canvas, MARG_TOP, MARG_H

from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = landscape(A4)          # 297 × 210 mm en apaisado
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H  # ≈ 26.7 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
AMBAR   = colors.HexColor('#b45309')
ROJO    = colors.HexColor('#dc2626')
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
AMBAR_L = colors.HexColor('#fef3c7')
ROJO_L  = colors.HexColor('#fee2e2')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_NRM   = _sty(fontSize=8, leading=11)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=6.5, leading=9)
ST_CELL_R= _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=6.5, leading=9, alignment=TA_CENTER)
ST_SMALL = _sty(fontSize=5.5, leading=8, textColor=GRIS_T)
ST_SMALL_R = _sty(fontSize=5.5, leading=8, textColor=GRIS_T, alignment=TA_RIGHT)
ST_TOT   = _sty(fontSize=7, fontName='Helvetica-Bold', leading=10)
ST_TOT_R = _sty(fontSize=7, fontName='Helvetica-Bold', leading=10, alignment=TA_RIGHT)
ST_TOT_C = _sty(fontSize=7, fontName='Helvetica-Bold', leading=10, alignment=TA_CENTER)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v)).replace(',', '.')
    except: return 'Gs. 0'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)



# ── Leyenda ───────────────────────────────────────────────────────────────────
def leyenda():
    """Fila de 2 celdas: mora y monto neto negativo."""
    cw = PAGE_W / 2
    data = [[
        P('Fondo amarillo — proveedor con NC morosa (pendiente > 30 dias)',
          _sty(fontSize=7, leading=10, textColor=AMBAR)),
        P('Fondo rojo — monto neto negativo (NC recibidas superan compras)',
          _sty(fontSize=7, leading=10, textColor=ROJO)),
    ]]
    t = Table(data, colWidths=[cw, cw])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (0,0), AMBAR_L),
        ('BACKGROUND',    (1,0), (1,0), ROJO_L),
        ('GRID',          (0,0), (-1,-1), 0.3, GRIS_M),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('TOPPADDING',    (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING',   (0,0), (-1,-1), 4),
        ('RIGHTPADDING',  (0,0), (-1,-1), 4),
    ]))
    return t


# ── Tabla principal ───────────────────────────────────────────────────────────
# Columnas (26.7 cm total):
# Prov/RUC | Tel  | Compras | T.Compras | NC | MtoNC | NC Pend | Mto Neto
#  6.7     | 2.8  |  1.8    |  3.7      |1.8 |  3.5  |  2.6    |  3.8
COL_W = [6.7, 2.8, 1.8, 3.7, 1.8, 3.5, 2.6, 3.8]
HDRS  = ['Proveedor / RUC', 'Teléfono',
         'Compras', 'Total Compras',
         'NC', 'Monto NC',
         'NC Pend.', 'Monto Neto']

def proveedores_table(datos):
    data  = [[P(h, ST_HDR) for h in HDRS]]
    mora_rows = []
    rojo_rows = []

    for i, p in enumerate(datos):
        ri = i + 1  # +1 por encabezado

        tiene_mora  = bool(p.get('TieneMorosa', False))
        monto_neto  = float(p.get('MontoNeto', 0) or 0)
        nc_pend     = int(p.get('NCPendientes', 0) or 0)
        monto_nc_p  = float(p.get('MontoNCPendiente', 0) or 0)

        if tiene_mora:
            mora_rows.append(ri)
        if monto_neto < 0:
            rojo_rows.append(ri)

        # Celda Proveedor + RUC en línea pequeña
        prov_cell = [
            P(p.get('Proveedor', ''), ST_CELL),
            P('RUC: ' + (p.get('RucProveedor') or '—'), ST_SMALL),
        ]

        # Celda NC Pendientes: número + monto
        if nc_pend > 0:
            nc_pend_cell = [
                P(str(nc_pend), _sty(fontSize=6.5, leading=9,
                                     alignment=TA_CENTER, textColor=ROJO,
                                     fontName='Helvetica-Bold')),
                P(gs(monto_nc_p), _sty(fontSize=5.5, leading=8,
                                        alignment=TA_CENTER, textColor=ROJO)),
            ]
        else:
            nc_pend_cell = [P('0', ST_CELL_C)]

        row = [
            prov_cell,
            P(p.get('Telefono') or '—', ST_CELL),
            P(str(p.get('CantidadCompras', 0)), ST_CELL_C),
            P(gs(p.get('TotalCompras', 0)),     ST_CELL_R),
            P(str(p.get('CantidadNC', 0)),      ST_CELL_C),
            P(gs(p.get('TotalMontoNC', 0)),     ST_CELL_R),
            nc_pend_cell,
            P(gs(monto_neto),
              _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT,
                   textColor=ROJO if monto_neto < 0 else GRIS_OS,
                   fontName='Helvetica-Bold' if monto_neto < 0 else 'Helvetica')),
        ]
        data.append(row)

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for r in mora_rows:
        ts.add('BACKGROUND', (0,r), (-1,r), AMBAR_L)
    for r in rojo_rows:
        ts.add('BACKGROUND', (0,r), (-1,r), ROJO_L)
    t.setStyle(ts)
    return t


# ── Fila de totales ───────────────────────────────────────────────────────────
def totales_table(datos):
    tot_compras   = sum(float(p.get('TotalCompras',     0) or 0) for p in datos)
    tot_nc        = sum(float(p.get('TotalMontoNC',     0) or 0) for p in datos)
    tot_nc_pend   = sum(float(p.get('MontoNCPendiente', 0) or 0) for p in datos)
    tot_neto      = sum(float(p.get('MontoNeto',        0) or 0) for p in datos)
    n_prov        = len(datos)
    n_mora        = sum(1 for p in datos if bool(p.get('TieneMorosa', False)))

    label = 'TOTALES  ({} proveedores, {} con mora)'.format(n_prov, n_mora)

    row = [
        P(label,         ST_TOT),
        P('',            ST_CELL),
        P('',            ST_CELL_C),
        P(gs(tot_compras), ST_TOT_R),
        P('',            ST_CELL_C),
        P(gs(tot_nc),    ST_TOT_R),
        P(gs(tot_nc_pend), ST_TOT_R),
        P(gs(tot_neto),  ST_TOT_R),
    ]
    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('TEXTCOLOR',  (0,0), (-1,0), BLANCO),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda        = data.get('NombreTienda',  '')
    empresa       = data.get('NombreEmpresa', tienda)
    fi_str        = data.get('FechaInicio',   '—')
    ff_str        = data.get('FechaFin',      '—')
    periodo       = '{} — {}'.format(fi_str, ff_str)
    filtros       = 'Sucursal: ' + tienda if tienda else ''
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')
    datos         = data.get('Proveedores',   [])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte de Proveedores'
    )

    cb    = _Canvas('Reporte de Proveedores', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    # Leyenda
    story.append(leyenda())
    story.append(Spacer(1, 6))

    # Tabla de datos
    if datos:
        story.append(proveedores_table(datos))
        story.append(Spacer(1, 0))
        story.append(totales_table(datos))
    else:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_NRM))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_proveedores.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
