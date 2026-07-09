# ============================================================
#  generar_reporte_rentabilidad.py
#  Reporte Gerencial de Rentabilidad por Producto (CPP)
#  Landscape A4 — con membrete
#  Uso: python generar_reporte_rentabilidad.py <json> <pdf>
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
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
VERDE_L = colors.HexColor('#d1fae5')
AMBAR_L = colors.HexColor('#fef3c7')
ROJO_L  = colors.HexColor('#fee2e2')
CIAN    = colors.HexColor('#17a2b8')
CIAN_L  = colors.HexColor('#d1ecf1')
VIOLA   = colors.HexColor('#6f42c1')
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
ST_LBL   = _sty(fontSize=7.5, fontName='Helvetica-Bold')
ST_VAL   = _sty(fontSize=7.5, alignment=TA_RIGHT)
ST_VAL_C = _sty(fontSize=7.5, alignment=TA_CENTER)
ST_TOT   = _sty(fontSize=7.5, fontName='Helvetica-Bold')
ST_TOT_R = _sty(fontSize=7.5, fontName='Helvetica-Bold', alignment=TA_RIGHT)
ST_TOT_C = _sty(fontSize=7.5, fontName='Helvetica-Bold', alignment=TA_CENTER)

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

def clase_rent(r):
    if (r.get('UnidadesVendidas') or 0) == 0:
        return 'sin_ventas'
    m = float(r.get('MargenBrutoPct', 0) or 0)
    if m >= 20: return 'alta'
    if m >= 10: return 'media'
    return 'baja'

def interpretar_margen(m):
    if m >= 40: return 'Excelente'
    if m >= 25: return 'Muy buena'
    if m >= 15: return 'Buena'
    if m >=  5: return 'Regular'
    if m >   0: return 'Baja'
    return 'Sin rentabilidad'


# ════════════════════════════════════════════════════════════════════════════
#  1. RESUMEN EJECUTIVO (KPIs)
# ════════════════════════════════════════════════════════════════════════════
def kpi_table(datos):
    total = len(datos)
    con_ventas = sum(1 for r in datos if (r.get('UnidadesVendidas') or 0) > 0)
    sin_ventas = total - con_ventas
    sum_ing  = sum(float(r.get('IngresosTotales',    0) or 0) for r in datos)
    sum_cost = sum(float(r.get('CostoTotalVentas',   0) or 0) for r in datos)
    sum_util = sum(float(r.get('UtilidadBruta',      0) or 0) for r in datos)
    sum_inv  = sum(float(r.get('ValorInventarioCPP', 0) or 0) for r in datos)
    margen_prom = (sum_util / sum_ing * 100) if sum_ing > 0 else 0

    rows = [
        [P('Indicador', _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
         P('Valor',     _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT))],
        [P('Productos analizados',       ST_LBL), P(str(total),         ST_VAL)],
        [P('Productos con ventas',       ST_LBL), P(str(con_ventas),    ST_VAL)],
        [P('Ingresos totales',           ST_LBL), P(gs(sum_ing),        ST_VAL)],
        [P('Costo total CPP',            ST_LBL), P(gs(sum_cost),       ST_VAL)],
        [P('Utilidad total',             ST_LBL), P(gs(sum_util),       ST_VAL)],
        [P('Margen promedio',            ST_LBL), P(pct(margen_prom),   ST_VAL)],
        [P('Valor del inventario (CPP)', ST_LBL), P(gs(sum_inv),        ST_VAL)],
        [P('Productos sin ventas',       ST_LBL), P(str(sin_ventas),    ST_VAL)],
    ]

    ancho = PAGE_W / cm
    col_val = 5.0
    t = Table(rows, colWidths=[(ancho - col_val) * cm, col_val * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  2. CLASIFICACIÓN DE RENTABILIDAD
# ════════════════════════════════════════════════════════════════════════════
def clasificacion_table(datos):
    total = len(datos)
    cnt = {'alta': 0, 'media': 0, 'baja': 0, 'sin_ventas': 0}
    for r in datos:
        cnt[clase_rent(r)] += 1

    hdrs = ['Nivel', 'Cantidad', '%']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    niveles = [
        ('Alta  (≥20%)',    'alta',      VERDE_L, VERDE),
        ('Media (10–19%)',  'media',     AMBAR_L, AMBAR),
        ('Baja  (0–9%)',    'baja',      GRIS_L,  GRIS_OS),
        ('Sin ventas',      'sin_ventas', colors.HexColor('#e2e3e5'), GRIS_T),
    ]
    for i, (label, key, bg, tc) in enumerate(niveles):
        n = cnt[key]
        p = (n / total * 100) if total > 0 else 0
        st_l = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=tc)
        rows.append([P(label, st_l), P(str(n), ST_VAL_C), P(pct(p), ST_VAL_C)])
        row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), bg))

    ancho = PAGE_W / cm
    col_w = [ancho - 3.0 - 3.0, 3.0, 3.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  3. TOP 5 MAYOR UTILIDAD
# ════════════════════════════════════════════════════════════════════════════
def top_utilidad_table(datos):
    con_ventas = [r for r in datos if (r.get('UnidadesVendidas') or 0) > 0]
    top = sorted(con_ventas, key=lambda r: float(r.get('UtilidadBruta', 0) or 0), reverse=True)[:5]
    sum_util = sum(float(r.get('UtilidadBruta', 0) or 0) for r in con_ventas)

    hdrs = ['Producto', 'Utilidad', '% Total']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    for i, r in enumerate(top):
        util = float(r.get('UtilidadBruta', 0) or 0)
        p    = (util / sum_util * 100) if sum_util > 0 else 0
        bg   = VERDE_L if i == 0 else (BLANCO if i % 2 == 0 else GRIS_L)
        st_u = _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT,
                    fontName='Helvetica-Bold', textColor=VERDE)
        rows.append([
            P(r.get('Producto', ''), ST_CELL),
            P(gs(util), st_u),
            P(pct(p), ST_CELL_C),
        ])

    ancho = PAGE_W / cm
    col_w = [ancho - 4.0 - 3.0, 4.0, 3.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), VERDE),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  4. TOP 5 MAYOR MARGEN
# ════════════════════════════════════════════════════════════════════════════
def top_margen_table(datos):
    con_ventas = [r for r in datos
                  if (r.get('UnidadesVendidas') or 0) > 0
                  and float(r.get('MargenBrutoPct', 0) or 0) > 0]
    top = sorted(con_ventas, key=lambda r: float(r.get('MargenBrutoPct', 0) or 0), reverse=True)[:5]

    hdrs = ['Producto', 'Margen', 'Clasif.']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    for r in top:
        mg = float(r.get('MargenBrutoPct', 0) or 0)
        cl = 'Excelente' if mg >= 40 else 'Muy buena' if mg >= 25 else 'Buena' if mg >= 15 else 'Regular'
        tc = VERDE if mg >= 40 else (CIAN if mg >= 25 else AMBAR)
        st_m = _sty(fontSize=6.5, leading=9, alignment=TA_CENTER,
                    fontName='Helvetica-Bold', textColor=tc)
        rows.append([
            P(r.get('Producto', ''), ST_CELL),
            P(pct(mg), st_m),
            P(cl, ST_CELL_C),
        ])

    ancho = PAGE_W / cm
    col_w = [ancho - 2.5 - 3.5, 2.5, 3.5]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), CIAN),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, CIAN_L]),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  5. BAJO DESEMPEÑO
# ════════════════════════════════════════════════════════════════════════════
def bajo_desempeno_table(datos):
    bajos = [r for r in datos
             if (r.get('UnidadesVendidas') or 0) == 0
             or float(r.get('MargenBrutoPct', 0) or 0) < 20]
    bajos.sort(key=lambda r: float(r.get('MargenBrutoPct', 0) or 0))

    if not bajos:
        return P('Todos los productos tienen alta rentabilidad (≥20%).', ST_CELL)

    hdrs = ['Producto', 'Categoría', 'Margen', 'Estado']
    rows = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    for i, r in enumerate(bajos):
        mg  = float(r.get('MargenBrutoPct', 0) or 0)
        uds = r.get('UnidadesVendidas') or 0

        if uds == 0:
            estado = 'Sin ventas'; bg = colors.HexColor('#e2e3e5'); tc = GRIS_OS
        elif mg >= 10:
            estado = 'Rent. media'; bg = AMBAR_L; tc = AMBAR
        elif mg >= 0:
            estado = 'Rent. baja';  bg = ROJO_L;  tc = ROJO
        else:
            estado = 'Margen neg.'; bg = ROJO_L;  tc = ROJO

        st_e = _sty(fontSize=6.5, leading=9, fontName='Helvetica-Bold', textColor=tc)
        rows.append([
            P(r.get('Producto',  ''), ST_CELL),
            P(r.get('Categoria', '—'), ST_CELL),
            P(pct(mg), ST_CELL_C),
            P(estado, st_e),
        ])
        row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), bg))

    ancho = PAGE_W / cm
    col_w = [ancho - 4.0 - 2.0 - 3.0, 4.0, 2.0, 3.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), ROJO),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  6. INDICADORES ESTRATÉGICOS
# ════════════════════════════════════════════════════════════════════════════
def indicadores_table(datos):
    total = len(datos)
    sum_ing  = sum(float(r.get('IngresosTotales',    0) or 0) for r in datos)
    sum_util = sum(float(r.get('UtilidadBruta',      0) or 0) for r in datos)
    sum_inv  = sum(float(r.get('ValorInventarioCPP', 0) or 0) for r in datos)
    alta      = sum(1 for r in datos if clase_rent(r) == 'alta')
    sin_vtas  = sum(1 for r in datos if clase_rent(r) == 'sin_ventas')
    mg_prom   = (sum_util / sum_ing * 100) if sum_ing > 0 else 0
    pct_alta  = (alta / total * 100)     if total > 0 else 0
    pct_sinv  = (sin_vtas / total * 100) if total > 0 else 0

    hdrs = ['Indicador', 'Resultado', 'Interpretación']
    rows = [[P(h, ST_HDR) for h in hdrs]]

    def fila(ind, res, interp):
        return [P(ind, ST_LBL), P(res, ST_VAL_C), P(interp, ST_CELL)]

    rows += [
        fila('Margen promedio',              pct(mg_prom),  interpretar_margen(mg_prom)),
        fila('Productos altamente rentables', pct(pct_alta), 'Favorable' if pct_alta > 50 else 'Mejorar'),
        fila('Productos sin movimiento',      pct(pct_sinv), 'Requiere análisis' if pct_sinv > 20 else 'Aceptable'),
        fila('Utilidad sobre ingresos',       pct(mg_prom),  interpretar_margen(mg_prom)),
        fila('Valor del inventario (CPP)',    gs(sum_inv),   'Capital inmovilizado'),
    ]

    ancho = PAGE_W / cm
    col_w = [ancho - 3.0 - 5.0, 3.0, 5.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  7. ANÁLISIS GERENCIAL
# ════════════════════════════════════════════════════════════════════════════
def analisis_table(datos):
    if not datos:
        return P('Sin datos.', ST_CELL)

    con_ventas = [r for r in datos if (r.get('UnidadesVendidas') or 0) > 0]

    # Producto con mayor utilidad
    max_util_r = max(datos, key=lambda r: float(r.get('UtilidadBruta', 0) or 0), default=None)
    # Producto con mayor margen (con ventas)
    max_mg_r = max(con_ventas, key=lambda r: float(r.get('MargenBrutoPct', 0) or 0), default=None) if con_ventas else None
    # Categoría más rentable
    cat_map = {}
    for r in datos:
        c = r.get('Categoria') or '(Sin categoría)'
        cat_map[c] = cat_map.get(c, 0) + float(r.get('UtilidadBruta', 0) or 0)
    cat_mejor = max(cat_map, key=cat_map.get) if cat_map else '—'
    sin_vtas  = sum(1 for r in datos if (r.get('UnidadesVendidas') or 0) == 0)
    sum_inv   = sum(float(r.get('ValorInventarioCPP', 0) or 0) for r in datos)

    hdrs = ['Aspecto', 'Resultado']
    rows = [[P(h, ST_HDR) for h in hdrs]]

    def fila(a, b):
        return [P(a, ST_LBL), P(b, ST_CELL)]

    max_util_prd = max_util_r.get('Producto', '—') if max_util_r else '—'
    max_mg_prd   = (max_mg_r.get('Producto', '—') + ' (' + pct(float(max_mg_r.get('MargenBrutoPct', 0))) + ')') if max_mg_r else '—'

    rows += [
        fila('Producto con mayor utilidad', max_util_prd),
        fila('Producto con mayor margen',   max_mg_prd),
        fila('Categoría más rentable',      cat_mejor),
        fila('Productos sin ventas',        str(sin_vtas) + ' (' + pct(sin_vtas / len(datos) * 100 if datos else 0) + ')'),
        fila('Capital inmovilizado',        gs(sum_inv) + ' en inventario'),
    ]

    ancho = PAGE_W / cm
    t = Table(rows, colWidths=[(ancho - 8.0) * cm, 8.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0),  GRIS_OS),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  8. TABLA DE DETALLE (existente)
# ════════════════════════════════════════════════════════════════════════════
COL_W = [1.8, 4.0, 2.5, 1.2, 2.3, 2.3, 1.2, 2.5, 2.5, 2.5, 1.5, 2.4]
HDRS  = ['Código', 'Producto', 'Categoría', 'Stock',
         'CPP (Gs.)', 'P. Venta', 'Uds.', 'Ingresos',
         'Costo CPP', 'Utilidad', 'Margen %', 'Val. Inv.']

def detalle_table(datos):
    data  = [[P(h, ST_HDR) for h in HDRS]]
    row_styles = []

    for i, r in enumerate(datos):
        mg  = float(r.get('MargenBrutoPct', 0) or 0)
        cls = clase_rent(r)
        ri  = i + 1
        if cls == 'alta':      row_styles.append(('ROWBACKGROUNDS', (0,ri), (-1,ri), [VERDE_L]))
        elif cls == 'media':   row_styles.append(('ROWBACKGROUNDS', (0,ri), (-1,ri), [AMBAR_L]))
        elif cls == 'sin_ventas': row_styles.append(('ROWBACKGROUNDS', (0,ri), (-1,ri), [GRIS_L]))

        st_mg = _sty(fontSize=6.5, leading=9, alignment=TA_CENTER,
                     textColor=(VERDE if mg >= 20 else (AMBAR if mg >= 10 else (ROJO if mg < 0 else GRIS_T))),
                     fontName='Helvetica-Bold')
        util  = float(r.get('UtilidadBruta', 0) or 0)
        st_ut = _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT,
                     textColor=VERDE if util >= 0 else ROJO)

        data.append([
            P(r.get('Codigo', ''),              ST_CELL_C),
            P(r.get('Producto', ''),            ST_CELL),
            P(r.get('Categoria', '—'),          ST_CELL),
            P(str(r.get('StockActual', 0)),     ST_CELL_C),
            P(gs(r.get('CostoPromedio', 0)),    ST_CELL_R),
            P(gs(r.get('PrecioVentaVigente',0)),ST_CELL_R),
            P(str(r.get('UnidadesVendidas',0)), ST_CELL_C),
            P(gs(r.get('IngresosTotales',  0)), ST_CELL_R),
            P(gs(r.get('CostoTotalVentas', 0)), ST_CELL_R),
            P(gs(util),                         st_ut),
            P(pct(mg),                          st_mg),
            P(gs(r.get('ValorInventarioCPP',0)),ST_CELL_R),
        ])

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0), AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ── Fila de totales ───────────────────────────────────────────────────────────
def totales_table(datos):
    tot_ing  = sum(float(r.get('IngresosTotales',    0) or 0) for r in datos)
    tot_cost = sum(float(r.get('CostoTotalVentas',   0) or 0) for r in datos)
    tot_util = sum(float(r.get('UtilidadBruta',      0) or 0) for r in datos)
    tot_inv  = sum(float(r.get('ValorInventarioCPP', 0) or 0) for r in datos)
    marg_glb = (tot_util / tot_ing * 100) if tot_ing > 0 else 0

    st_w = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO)
    st_wr= _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)
    st_wc= _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)

    row = [P('TOTALES', st_w), P('', st_w), P('', st_w), P('', st_w),
           P('', st_w), P('', st_w), P('', st_w),
           P(gs(tot_ing),  st_wr), P(gs(tot_cost), st_wr),
           P(gs(tot_util), st_wr), P(pct(marg_glb), st_wc), P(gs(tot_inv), st_wr)]
    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
    ]))
    return t


# ── Leyenda ───────────────────────────────────────────────────────────────────
def leyenda():
    cw = PAGE_W / 4
    data = [[
        P('Margen ≥ 20%  — Alta',       _sty(fontSize=7, leading=10, textColor=VERDE)),
        P('Margen 10–19% — Media',       _sty(fontSize=7, leading=10, textColor=AMBAR)),
        P('Margen  0–9%  — Baja',        _sty(fontSize=7, leading=10, textColor=GRIS_OS)),
        P('Margen < 0%   — Bajo costo',  _sty(fontSize=7, leading=10, textColor=ROJO)),
    ]]
    t = Table(data, colWidths=[cw, cw, cw, cw])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0),(0,0), VERDE_L), ('BACKGROUND',(1,0),(1,0), AMBAR_L),
        ('BACKGROUND', (2,0),(2,0), GRIS_L),  ('BACKGROUND',(3,0),(3,0), ROJO_L),
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
    fi_str         = data.get('FechaInicio',   '')
    ff_str         = data.get('FechaFin',      '')
    periodo        = '{} — {}'.format(fi_str, ff_str) if fi_str else ''
    filtros        = 'Sucursal: ' + tienda if tienda and tienda != 'Todas las sucursales' else ''
    reporte_id     = data.get('ReporteId',     '')
    nombre_usuario = data.get('NombreUsuario', '')
    logo_path      = data.get('LogoPath',      '')
    datos          = data.get('Datos',         [])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Rentabilidad por Producto — CPP'
    )

    cb    = _Canvas('Reporte Gerencial de Rentabilidad por Producto — CPP', empresa,
                    periodo, filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    # ── 1. Resumen ejecutivo ──────────────────────────────────────────────
    story.append(P('Resumen Ejecutivo de Rentabilidad', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(kpi_table(datos))
    story.append(Spacer(1, 8))

    # ── 2. Clasificación ─────────────────────────────────────────────────
    story.append(P('Clasificación de Rentabilidad', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(clasificacion_table(datos))
    story.append(Spacer(1, 8))

    # ── 3. Top 5 mayor utilidad ───────────────────────────────────────────
    story.append(P('Productos con Mayor Utilidad (Top 5)', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(top_utilidad_table(datos))
    story.append(Spacer(1, 8))

    # ── 4. Top 5 mayor margen ─────────────────────────────────────────────
    story.append(P('Productos con Mayor Margen (Top 5)', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(top_margen_table(datos))
    story.append(Spacer(1, 8))

    # ── 5. Bajo desempeño ─────────────────────────────────────────────────
    story.append(P('Productos de Bajo Desempeño', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(bajo_desempeno_table(datos))
    story.append(Spacer(1, 8))

    # ── 6. Indicadores estratégicos ───────────────────────────────────────
    story.append(P('Indicadores Estratégicos', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(indicadores_table(datos))
    story.append(Spacer(1, 8))

    # ── 7. Análisis gerencial ─────────────────────────────────────────────
    story.append(P('Análisis Gerencial', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(analisis_table(datos))
    story.append(Spacer(1, 8))

    # ── 8. Detalle + leyenda + totales ────────────────────────────────────
    story.append(P('Detalle de Productos', ST_SEC))
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
        print('Uso: python generar_reporte_rentabilidad.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
