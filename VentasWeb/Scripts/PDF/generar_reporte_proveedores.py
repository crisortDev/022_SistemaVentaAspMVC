# ============================================================
#  generar_reporte_proveedores.py
#  Reporte Gerencial de Proveedores — Landscape A4
#  Uso: python generar_reporte_proveedores.py <json> <pdf>
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
PAGE     = landscape(A4)
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 26.7 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
AMBAR   = colors.HexColor('#b45309')
ROJO    = colors.HexColor('#dc2626')
CIAN    = colors.HexColor('#17a2b8')
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
VERDE_L = colors.HexColor('#d1fae5')
AMBAR_L = colors.HexColor('#fef3c7')
ROJO_L  = colors.HexColor('#fee2e2')
CIAN_L  = colors.HexColor('#d1ecf1')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=AZUL, spaceBefore=6, spaceAfter=3)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=6.5, leading=9)
ST_CELL_R= _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=6.5, leading=9, alignment=TA_CENTER)
ST_SMALL = _sty(fontSize=5.5, leading=8, textColor=GRIS_T)
ST_LBL   = _sty(fontSize=7.5, fontName='Helvetica-Bold')
ST_VAL   = _sty(fontSize=7.5, alignment=TA_RIGHT)
ST_VAL_C = _sty(fontSize=7.5, alignment=TA_CENTER)
ST_TOT   = _sty(fontSize=7,   fontName='Helvetica-Bold')
ST_TOT_R = _sty(fontSize=7,   fontName='Helvetica-Bold', alignment=TA_RIGHT)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v or 0)).replace(',', '.')
    except: return 'Gs. 0'

def pct(v):
    try:    return '{:.1f}%'.format(float(v or 0))
    except: return '0.0%'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

def estado_prov(p):
    if p.get('TieneMorosa'):              return 'Con mora'
    if float(p.get('MontoNeto', 0) or 0) < 0: return 'Saldo neg.'
    return 'Normal'


# ════════════════════════════════════════════════════════════════════════════
#  1. RESUMEN EJECUTIVO
# ════════════════════════════════════════════════════════════════════════════
def kpi_table(datos):
    total_prov   = len(datos)
    total_compras= sum(int(p.get('CantidadCompras', 0) or 0) for p in datos)
    monto_comp   = sum(float(p.get('TotalCompras',  0) or 0) for p in datos)
    total_nc     = sum(int(p.get('CantidadNC',      0) or 0) for p in datos)
    monto_nc     = sum(float(p.get('TotalMontoNC',  0) or 0) for p in datos)
    saldo_neto   = sum(float(p.get('MontoNeto',     0) or 0) for p in datos)
    ind_dev      = (monto_nc / monto_comp * 100) if monto_comp > 0 else 0
    con_mora     = sum(1 for p in datos if p.get('TieneMorosa'))

    rows = [
        [P('Indicador', _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
         P('Valor',     _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT))],
        [P('Proveedores activos',   ST_LBL), P(str(total_prov),    ST_VAL)],
        [P('Compras confirmadas',   ST_LBL), P(str(total_compras), ST_VAL)],
        [P('Monto comprado',        ST_LBL), P(gs(monto_comp),     ST_VAL)],
        [P('Notas de Crédito',      ST_LBL), P(str(total_nc),      ST_VAL)],
        [P('Monto NC',              ST_LBL), P(gs(monto_nc),       ST_VAL)],
        [P('Saldo Neto',            ST_LBL), P(gs(saldo_neto),     ST_VAL)],
        [P('Índice de devoluciones',ST_LBL), P(pct(ind_dev),       ST_VAL)],
        [P('Proveedores con mora',  ST_LBL), P(str(con_mora) + ' (' + pct(con_mora / total_prov * 100 if total_prov else 0) + ')', ST_VAL)],
    ]

    ancho = PAGE_W / cm
    col_val = 5.0
    t = Table(rows, colWidths=[(ancho - col_val) * cm, col_val * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  2. ESTADO FINANCIERO
# ════════════════════════════════════════════════════════════════════════════
def estado_financiero_table(datos):
    total    = len(datos)
    sin_mora = sum(1 for p in datos if not p.get('TieneMorosa'))
    con_mora = total - sin_mora
    saldo_pos= sum(1 for p in datos if float(p.get('MontoNeto', 0) or 0) >= 0)
    saldo_neg= total - saldo_pos

    hdrs = ['Estado', 'Cantidad', '%']
    rows = [[P(h, ST_HDR) for h in hdrs]]

    def fila(label, n, bg, tc):
        p = (n / total * 100) if total > 0 else 0
        st_l = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=tc)
        return [P(label, st_l), P(str(n), ST_VAL_C), P(pct(p), ST_VAL_C)], bg

    for r, bg in [
        fila('Sin mora',       sin_mora, VERDE_L, VERDE),
        fila('Con NC vencida', con_mora, ROJO_L,  ROJO),
        fila('Saldo positivo', saldo_pos,CIAN_L,  CIAN),
        fila('Saldo negativo', saldo_neg,AMBAR_L, AMBAR),
    ]:
        rows.append(r)

    bgs = [VERDE_L, ROJO_L, CIAN_L, AMBAR_L]
    ancho = PAGE_W / cm
    col_w = [ancho - 2.5 - 2.5, 2.5, 2.5]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for i, bg in enumerate(bgs):
        ts.add('BACKGROUND', (0, i+1), (-1, i+1), bg)
    t.setStyle(ts)
    return t


# ════════════════════════════════════════════════════════════════════════════
#  3. TOP PROVEEDORES POR MONTO COMPRADO
# ════════════════════════════════════════════════════════════════════════════
def top_proveedores_table(datos):
    sorted_d = sorted(datos, key=lambda p: float(p.get('TotalCompras', 0) or 0), reverse=True)
    total_m  = sum(float(p.get('TotalCompras', 0) or 0) for p in datos)
    max_v    = float(sorted_d[0].get('TotalCompras', 0) or 0) if sorted_d else 1

    hdrs = ['Proveedor', 'Compras', '% Total']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    for i, p in enumerate(sorted_d):
        comp = float(p.get('TotalCompras', 0) or 0)
        pt   = (comp / total_m * 100) if total_m > 0 else 0
        bg   = CIAN_L if i == 0 else (BLANCO if i % 2 == 0 else GRIS_L)
        st_c = _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT,
                    fontName='Helvetica-Bold' if i == 0 else 'Helvetica',
                    textColor=CIAN if i == 0 else GRIS_OS)
        rows.append([
            P(p.get('Proveedor', ''), ST_CELL),
            P(gs(comp), st_c),
            P(pct(pt), ST_CELL_C),
        ])

    ancho = PAGE_W / cm
    col_w = [ancho - 4.5 - 2.5, 4.5, 2.5]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  CIAN),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  4. DISTRIBUCIÓN DE NOTAS DE CRÉDITO
# ════════════════════════════════════════════════════════════════════════════
def distribucion_nc_table(datos):
    con_nc = [p for p in datos if (p.get('CantidadNC') or 0) > 0]
    if not con_nc:
        return P('Sin notas de crédito en el período.', ST_CELL)

    con_nc.sort(key=lambda p: float(p.get('TotalMontoNC', 0) or 0), reverse=True)
    total_nc_m = sum(float(p.get('TotalMontoNC', 0) or 0) for p in con_nc)

    hdrs = ['Proveedor', 'NC', 'Monto NC', '% NC']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    for i, p in enumerate(con_nc):
        monto = float(p.get('TotalMontoNC', 0) or 0)
        pt    = (monto / total_nc_m * 100) if total_nc_m > 0 else 0
        rows.append([
            P(p.get('Proveedor', ''), ST_CELL),
            P(str(p.get('CantidadNC', 0)), ST_CELL_C),
            P(gs(monto), ST_CELL_R),
            P(pct(pt),   ST_CELL_C),
        ])

    ancho = PAGE_W / cm
    col_w = [ancho - 1.8 - 3.5 - 2.0, 1.8, 3.5, 2.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AMBAR),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, AMBAR_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  5. ANÁLISIS GERENCIAL
# ════════════════════════════════════════════════════════════════════════════
def analisis_table(datos):
    if not datos:
        return P('Sin datos.', ST_CELL)

    sorted_d = sorted(datos, key=lambda p: float(p.get('TotalCompras', 0) or 0), reverse=True)
    top1     = sorted_d[0].get('Proveedor', '—') if sorted_d else '—'
    top2     = sorted_d[1].get('Proveedor', '—') if len(sorted_d) > 1 else '—'

    total_m  = sum(float(p.get('TotalCompras', 0) or 0) for p in datos)
    pct_top2 = 0.0
    if len(sorted_d) >= 2 and total_m > 0:
        pct_top2 = (float(sorted_d[0].get('TotalCompras',0) or 0) +
                    float(sorted_d[1].get('TotalCompras',0) or 0)) / total_m * 100

    max_nc   = sorted(datos, key=lambda p: int(p.get('CantidadNC', 0) or 0), reverse=True)
    top_nc   = max_nc[0].get('Proveedor', '—') if max_nc else '—'

    con_mora  = sum(1 for p in datos if p.get('TieneMorosa'))
    saldo_neg = sum(1 for p in datos if float(p.get('MontoNeto', 0) or 0) < 0)

    if con_mora == 0 and saldo_neg == 0:
        riesgo = 'No se detectan proveedores con saldo negativo ni NC vencidas.'
    else:
        riesgo = '{} prov. con NC vencida'.format(con_mora)
        if saldo_neg > 0:
            riesgo += ', {} con saldo negativo.'.format(saldo_neg)

    if pct_top2 > 0:
        concent = 'Las compras se concentran en dos proveedores ({} del total).'.format(pct(pct_top2))
    else:
        concent = '—'

    hdrs = ['Aspecto Analizado', 'Resultado']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    filas = [
        ('Proveedor con mayor volumen de compras', top1),
        ('Segundo proveedor más importante',        top2),
        ('Proveedor con mayor cantidad de NC',      top_nc),
        ('Riesgo financiero detectado',             riesgo),
        ('Nivel de concentración',                  concent),
    ]
    for i, (a, r) in enumerate(filas):
        rows.append([P(a, ST_LBL), P(r, ST_CELL)])

    ancho = PAGE_W / cm
    t = Table(rows, colWidths=[(ancho - 8.0) * cm, 8.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  GRIS_OS),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  6. TABLA DETALLE
# ════════════════════════════════════════════════════════════════════════════
# Col widths: Prov/RUC | Tel | Compras | T.Compras | NC | MtoNC | NC Pend | Mto Neto | Estado
COL_W = [5.8, 2.5, 1.6, 3.4, 1.5, 3.2, 2.4, 3.4, 2.9]
HDRS  = ['Proveedor / RUC', 'Teléfono', 'Compras', 'Total Compras',
         'NC', 'Monto NC', 'NC Pend.', 'Saldo Neto', 'Estado']

def detalle_table(datos):
    data      = [[P(h, ST_HDR) for h in HDRS]]
    mora_rows = []
    rojo_rows = []

    for i, p in enumerate(datos):
        ri         = i + 1
        tiene_mora = bool(p.get('TieneMorosa', False))
        monto_neto = float(p.get('MontoNeto', 0) or 0)
        nc_pend    = int(p.get('NCPendientes', 0) or 0)
        monto_nc_p = float(p.get('MontoNCPendiente', 0) or 0)

        if tiene_mora: mora_rows.append(ri)
        if monto_neto < 0: rojo_rows.append(ri)

        prov_cell = [
            P(p.get('Proveedor', ''), ST_CELL),
            P('RUC: ' + (p.get('RucProveedor') or '—'), ST_SMALL),
        ]

        nc_pend_cell = [
            P(str(nc_pend),
              _sty(fontSize=6.5, leading=9, alignment=TA_CENTER,
                   textColor=ROJO if nc_pend > 0 else GRIS_OS,
                   fontName='Helvetica-Bold' if nc_pend > 0 else 'Helvetica')),
        ]
        if nc_pend > 0:
            nc_pend_cell.append(P(gs(monto_nc_p),
                _sty(fontSize=5.5, leading=8, alignment=TA_CENTER, textColor=ROJO)))

        # Estado badge-like text
        est = estado_prov(p)
        tc_est = ROJO if est != 'Normal' else VERDE
        st_est = _sty(fontSize=6.5, leading=9, alignment=TA_CENTER,
                      fontName='Helvetica-Bold', textColor=tc_est)

        data.append([
            prov_cell,
            P(p.get('Telefono') or '—', ST_CELL),
            P(str(p.get('CantidadCompras', 0)), ST_CELL_C),
            P(gs(p.get('TotalCompras', 0)), ST_CELL_R),
            P(str(p.get('CantidadNC', 0)), ST_CELL_C),
            P(gs(p.get('TotalMontoNC', 0)), ST_CELL_R),
            nc_pend_cell,
            P(gs(monto_neto),
              _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT,
                   textColor=ROJO if monto_neto < 0 else GRIS_OS,
                   fontName='Helvetica-Bold' if monto_neto < 0 else 'Helvetica')),
            P(est, st_est),
        ])

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for r in mora_rows: ts.add('BACKGROUND', (0,r), (-1,r), AMBAR_L)
    for r in rojo_rows: ts.add('BACKGROUND', (0,r), (-1,r), ROJO_L)
    t.setStyle(ts)
    return t


# ── Totales ───────────────────────────────────────────────────────────────────
def totales_table(datos):
    tot_compras = sum(float(p.get('TotalCompras',     0) or 0) for p in datos)
    tot_nc      = sum(float(p.get('TotalMontoNC',     0) or 0) for p in datos)
    tot_nc_pend = sum(float(p.get('MontoNCPendiente', 0) or 0) for p in datos)
    tot_neto    = sum(float(p.get('MontoNeto',        0) or 0) for p in datos)
    n_prov      = len(datos)
    n_mora      = sum(1 for p in datos if p.get('TieneMorosa'))

    label = 'TOTALES  ({} proveedores, {} con mora)'.format(n_prov, n_mora)
    st_w  = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO)
    st_wr = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)
    st_wc = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)

    row = [P(label, st_w), P('', st_w), P('', st_wc),
           P(gs(tot_compras), st_wr), P('', st_wc), P(gs(tot_nc), st_wr),
           P(gs(tot_nc_pend), st_wr), P(gs(tot_neto), st_wr), P('', st_wc)]
    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
    ]))
    return t


# ── Leyenda ───────────────────────────────────────────────────────────────────
def leyenda():
    cw = PAGE_W / 2
    data = [[
        P('Fondo amarillo — proveedor con NC morosa (pendiente > 30 días)',
          _sty(fontSize=7, leading=10, textColor=AMBAR)),
        P('Fondo rojo — monto neto negativo (NC superan compras)',
          _sty(fontSize=7, leading=10, textColor=ROJO)),
    ]]
    t = Table(data, colWidths=[cw, cw])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0),(0,0), AMBAR_L), ('BACKGROUND',(1,0),(1,0), ROJO_L),
        ('GRID',       (0,0),(-1,-1), 0.3, GRIS_M),
        ('ALIGN',      (0,0),(-1,-1), 'CENTER'),
        ('TOPPADDING', (0,0),(-1,-1), 3), ('BOTTOMPADDING',(0,0),(-1,-1), 3),
        ('LEFTPADDING',(0,0),(-1,-1), 4), ('RIGHTPADDING', (0,0),(-1,-1), 4),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda         = data.get('NombreTienda',  '')
    empresa        = data.get('NombreEmpresa', tienda)
    fi_str         = data.get('FechaInicio',   '—')
    ff_str         = data.get('FechaFin',      '—')
    periodo        = '{} — {}'.format(fi_str, ff_str)
    filtros        = 'Sucursal: ' + tienda if tienda else ''
    reporte_id     = data.get('ReporteId',     '')
    nombre_usuario = data.get('NombreUsuario', '')
    logo_path      = data.get('LogoPath',      '')
    datos          = data.get('Proveedores',   [])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Proveedores'
    )

    cb    = _Canvas('Reporte Gerencial de Proveedores', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    # ── 1. Resumen ejecutivo ──────────────────────────────────────────────
    story.append(P('Resumen Ejecutivo', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(kpi_table(datos))
    story.append(Spacer(1, 8))

    # ── 2. Estado Financiero ──────────────────────────────────────────────
    story.append(P('Estado Financiero de Proveedores', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(estado_financiero_table(datos))
    story.append(Spacer(1, 8))

    # ── 3. Top Proveedores ────────────────────────────────────────────────
    story.append(P('Top Proveedores por Monto Comprado', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(top_proveedores_table(datos))
    story.append(Spacer(1, 8))

    # ── 4. Distribución NC ────────────────────────────────────────────────
    story.append(P('Distribución de Notas de Crédito', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(distribucion_nc_table(datos))
    story.append(Spacer(1, 8))

    # ── 5. Análisis Gerencial ─────────────────────────────────────────────
    story.append(P('Análisis Gerencial', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(analisis_table(datos))
    story.append(Spacer(1, 8))

    # ── 6. Detalle + leyenda + totales ────────────────────────────────────
    story.append(P('Detalle Completo de Proveedores', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(leyenda())
    story.append(Spacer(1, 4))

    if datos:
        story.append(detalle_table(datos))
        story.append(Spacer(1, 0))
        story.append(totales_table(datos))
    else:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_CELL))

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
