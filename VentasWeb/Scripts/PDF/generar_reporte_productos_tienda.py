# ============================================================
#  generar_reporte_productos_tienda.py
#  Reporte Gerencial de Productos — Portrait A4
#  Uso: python generar_reporte_productos_tienda.py <json> <pdf>
# ============================================================

import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from membrete import _Canvas, MARG_TOP, MARG_H

from reportlab.lib.pagesizes import A4
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = A4
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 18.0 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
AZUL_CLR= colors.HexColor('#e8edf5')
VERDE   = colors.HexColor('#28a745')
VERDE_L = colors.HexColor('#d4edda')
ROJO    = colors.HexColor('#dc3545')
ROJO_L  = colors.HexColor('#f8d7da')
AMBAR   = colors.HexColor('#ffc107')
AMBAR_L = colors.HexColor('#fff3cd')
INFO    = colors.HexColor('#17a2b8')
INFO_L  = colors.HexColor('#d1ecf1')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
GRIS_OS = colors.HexColor('#1f2937')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=8.5, fontName='Helvetica-Bold', textColor=INFO,
                spaceBefore=10, spaceAfter=4)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_HDR_L = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO)
ST_CELL  = _sty(fontSize=7,   leading=9)
ST_CELL_C= _sty(fontSize=7,   leading=9, alignment=TA_CENTER)
ST_CELL_R= _sty(fontSize=7,   leading=9, alignment=TA_RIGHT)
ST_BOLD  = _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold')
ST_BOLD_C= _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold', alignment=TA_CENTER)
ST_BOLD_R= _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold', alignment=TA_RIGHT)
ST_SMALL = _sty(fontSize=6,   leading=8, textColor=GRIS_T)
ST_KPI_L = _sty(fontSize=6.5, textColor=GRIS_T, alignment=TA_CENTER)
ST_KPI_V = _sty(fontSize=10,  fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER)
ST_KPI_S = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER, leading=10)

CELL_PAD = [
    ('TOPPADDING',    (0, 0), (-1, -1), 2),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ('LEFTPADDING',   (0, 0), (-1, -1), 3),
    ('RIGHTPADDING',  (0, 0), (-1, -1), 3),
    ('VALIGN',        (0, 0), (-1, -1), 'MIDDLE'),
]

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(str(v).replace(',', ''))).replace(',', '.')
    except: return 'Gs. 0'

def _num(v):
    try:    return float(str(v).replace(',', ''))
    except: return 0.0

def _stock(v):
    try:    return int(str(v).replace(',', '') or '0')
    except: return 0

def barra(n, maximo, largo=14):
    if maximo <= 0: return ''
    b = max(1, round(n / maximo * largo)) if n > 0 else 0
    return '█' * b


# ── 1. Resumen Ejecutivo (tabla KPI) ─────────────────────────────────────────
def resumen_ejecutivo_table(productos):
    total      = len(productos)
    stock_tot  = sum(_stock(p.get('StockenTienda', 0)) for p in productos)
    val_costo  = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioCompra', 0)) for p in productos)
    pot_venta  = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioVenta',  0)) for p in productos)
    sin_stock  = sum(1 for p in productos if _stock(p.get('StockenTienda', 0)) == 0)
    critico    = sum(1 for p in productos if 0 < _stock(p.get('StockenTienda', 0)) <= 5)
    margenes   = [(_num(p.get('PrecioVenta', 0)) - _num(p.get('PrecioCompra', 0))) / _num(p.get('PrecioCompra', 0)) * 100
                  for p in productos if _num(p.get('PrecioCompra', 0)) > 0]
    mg_prom    = sum(margenes) / len(margenes) if margenes else 0
    ganancia   = pot_venta - val_costo

    st_lbl = _sty(fontSize=7, fontName='Helvetica-Bold')
    st_val = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_RIGHT)

    rows = [
        [P('Indicador', ST_HDR_L),                      P('Valor', ST_HDR)],
        [P('Total productos relevados',      st_lbl),   P(str(total),                 st_val)],
        [P('Stock total disponible',         st_lbl),   P('{:,} u.'.format(stock_tot).replace(',','.'), st_val)],
        [P('Valor inventario a costo',       st_lbl),   P(gs(val_costo),              st_val)],
        [P('Potencial de venta',             st_lbl),   P(gs(pot_venta),              st_val)],
        [P('Ganancia potencial',             st_lbl),   P(gs(ganancia),               st_val)],
        [P('Margen promedio',                st_lbl),   P('{:.1f}%'.format(mg_prom),  st_val)],
        [P('Productos sin stock',            st_lbl),   P('{} ({:.1f}%)'.format(sin_stock, sin_stock/total*100 if total else 0), st_val)],
        [P('Productos en stock crítico (≤5)',st_lbl),   P(str(critico),               st_val)],
    ]

    t = Table(rows, colWidths=[10.0 * cm, 8.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 2. Top 10 por Stock ───────────────────────────────────────────────────────
def top_stock_table(productos):
    sorted_p  = sorted(productos, key=lambda x: _stock(x.get('StockenTienda', 0)), reverse=True)[:10]
    max_stock = _stock(sorted_p[0].get('StockenTienda', 0)) if sorted_p else 1

    rows = [[P('Código', ST_HDR), P('Producto', ST_HDR_L),
             P('Stock', ST_HDR), P('P. Venta', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for p in sorted_p:
        stock = _stock(p.get('StockenTienda', 0))
        rows.append([
            P(p.get('CodigoProducto', ''), ST_CELL_C),
            P(p.get('NombreProducto', ''), ST_CELL),
            P(str(stock),                  ST_BOLD_C),
            P(gs(p.get('PrecioVenta', 0)), ST_CELL_R),
            Paragraph('<font color="#17a2b8">{}</font>'.format(barra(stock, max_stock)), ST_CELL),
        ])

    w = [2.0, 6.5, 1.5, 3.0, PAGE_W / cm - 13.0]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 3. Productos Sin Stock ────────────────────────────────────────────────────
def sin_stock_table(productos):
    sin = [p for p in productos if _stock(p.get('StockenTienda', 0)) == 0]

    if not sin:
        msg = Table([[P('✓  Todos los productos tienen stock disponible.', _sty(fontSize=7, textColor=VERDE))]],
                    colWidths=[PAGE_W])
        msg.setStyle(TableStyle([('BACKGROUND', (0,0), (-1,-1), VERDE_L),
                                 ('TOPPADDING', (0,0), (-1,-1), 4),
                                 ('BOTTOMPADDING', (0,0), (-1,-1), 4),
                                 ('LEFTPADDING', (0,0), (-1,-1), 6)]))
        return msg

    rows = [[P('Código', ST_HDR), P('Producto', ST_HDR_L), P('P. Venta', ST_HDR)]]
    for p in sin:
        rows.append([
            P(p.get('CodigoProducto', ''), ST_CELL_C),
            P(p.get('NombreProducto', ''), ST_CELL),
            P(gs(p.get('PrecioVenta', 0)), ST_CELL_R),
        ])

    t = Table(rows, colWidths=[2.2 * cm, 11.8 * cm, 4.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  ROJO),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [ROJO_L, BLANCO]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 4. Distribución por Rango de Precio ──────────────────────────────────────
def rango_precios_table(productos):
    rangos = [
        {'label': 'Económico (< Gs. 100.000)',           'min': 0,        'max': 100000,   'cant': 0, 'stock': 0},
        {'label': 'Intermedio (Gs. 100.000–500.000)',    'min': 100000,   'max': 500000,   'cant': 0, 'stock': 0},
        {'label': 'Superior (Gs. 500.000–2.000.000)',    'min': 500000,   'max': 2000000,  'cant': 0, 'stock': 0},
        {'label': 'Premium (> Gs. 2.000.000)',           'min': 2000000,  'max': float('inf'), 'cant': 0, 'stock': 0},
    ]
    total = len(productos) or 1

    for p in productos:
        venta = _num(p.get('PrecioVenta', 0))
        stock = _stock(p.get('StockenTienda', 0))
        for r in rangos:
            if r['min'] <= venta < r['max']:
                r['cant']  += 1
                r['stock'] += stock
                break

    max_cant = max(r['cant'] for r in rangos) or 1

    rows = [[P('Rango de Precio', ST_HDR_L), P('Cant.', ST_HDR),
             P('Stock', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)]]

    bg_cols = [GRIS_L, VERDE_L, INFO_L, AMBAR_L]
    for i, r in enumerate(rangos):
        pct = '{:.1f}%'.format(r['cant'] / total * 100)
        rows.append([
            P(r['label'],       ST_CELL),
            P(str(r['cant']),   ST_BOLD_C),
            P(str(r['stock']),  ST_CELL_C),
            P(pct,              ST_CELL_C),
            Paragraph('<font color="#17a2b8">{}</font>'.format(barra(r['cant'], max_cant)), ST_CELL),
        ])

    w = [6.0, 1.5, 1.5, 1.5, PAGE_W / cm - 10.5]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), bg_cols),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 5. Top 10 por Margen % ───────────────────────────────────────────────────
def top_margen_table(productos):
    con_margen = []
    for p in productos:
        compra = _num(p.get('PrecioCompra', 0))
        if compra <= 0: continue
        venta  = _num(p.get('PrecioVenta', 0))
        margen = (venta - compra) / compra * 100
        con_margen.append({'p': p, 'margen': margen})

    sorted_m  = sorted(con_margen, key=lambda x: x['margen'], reverse=True)[:10]
    max_margen = sorted_m[0]['margen'] if sorted_m else 1

    rows = [[P('Código', ST_HDR), P('Producto', ST_HDR_L),
             P('P. Compra', ST_HDR), P('P. Venta', ST_HDR), P('Margen', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for item in sorted_m:
        p      = item['p']
        margen = item['margen']
        m_color = '#28a745' if margen >= 50 else '#17a2b8' if margen >= 20 else '#ffc107'
        rows.append([
            P(p.get('CodigoProducto', ''),    ST_CELL_C),
            P(p.get('NombreProducto', ''),    ST_CELL),
            P(gs(p.get('PrecioCompra', 0)),   ST_CELL_R),
            P(gs(p.get('PrecioVenta', 0)),    ST_CELL_R),
            Paragraph('<font color="{}">{:.1f}%</font>'.format(m_color, margen), ST_BOLD_C),
            Paragraph('<font color="{}">{}</font>'.format(m_color, barra(margen, max_margen)), ST_CELL),
        ])

    w = [1.8, 4.5, 2.8, 2.8, 1.8, PAGE_W / cm - 13.7]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 6. Análisis Gerencial ─────────────────────────────────────────────────────
def analisis_table(productos):
    total     = len(productos) or 1
    stock_tot = sum(_stock(p.get('StockenTienda', 0)) for p in productos)
    val_costo = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioCompra', 0)) for p in productos)
    pot_venta = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioVenta',  0)) for p in productos)
    sin_stock = sum(1 for p in productos if _stock(p.get('StockenTienda', 0)) == 0)
    critico   = sum(1 for p in productos if 0 < _stock(p.get('StockenTienda', 0)) <= 5)
    margenes  = [(_num(p.get('PrecioVenta', 0)) - _num(p.get('PrecioCompra', 0))) / _num(p.get('PrecioCompra', 0)) * 100
                 for p in productos if _num(p.get('PrecioCompra', 0)) > 0]
    mg_prom   = sum(margenes) / len(margenes) if margenes else 0

    sorted_stock = sorted(productos, key=lambda x: _stock(x.get('StockenTienda', 0)), reverse=True)
    prod_max_stock = sorted_stock[0] if sorted_stock else None

    sorted_mg  = sorted([p for p in productos if _num(p.get('PrecioCompra', 0)) > 0],
                        key=lambda x: (_num(x.get('PrecioVenta', 0)) - _num(x.get('PrecioCompra', 0))) / _num(x.get('PrecioCompra', 0)),
                        reverse=True)
    prod_max_mg = sorted_mg[0] if sorted_mg else None

    st_asp = _sty(fontSize=7, fontName='Helvetica-Bold')
    st_res = _sty(fontSize=7)

    filas = [
        (P('Total de productos relevados',       st_asp), P(str(total),                                        st_res)),
        (P('Stock total disponible',             st_asp), P('{:,} unidades'.format(stock_tot).replace(',','.'), st_res)),
        (P('Valor del inventario a costo',       st_asp), P(gs(val_costo),                                     st_res)),
        (P('Potencial de venta',                 st_asp), P(gs(pot_venta),                                     st_res)),
        (P('Ganancia potencial bruta',           st_asp), P(gs(pot_venta - val_costo),                        st_res)),
        (P('Margen promedio',                    st_asp), P('{:.1f}%'.format(mg_prom),                        st_res)),
        (P('Productos sin stock',                st_asp), P('{} ({:.1f}%)'.format(sin_stock, sin_stock/total*100), st_res)),
        (P('Productos en stock crítico (≤ 5)',   st_asp), P(str(critico),                                     st_res)),
        (P('Producto con mayor stock',           st_asp), P(
            (prod_max_stock.get('NombreProducto', '—') + ' — ' + str(_stock(prod_max_stock.get('StockenTienda', 0))) + ' u.')
            if prod_max_stock else '—', st_res)),
        (P('Producto con mayor margen',          st_asp), P(
            prod_max_mg.get('NombreProducto', '—') if prod_max_mg else '—', st_res)),
    ]

    data = [[P('Aspecto', ST_HDR_L), P('Resultado', ST_HDR)]] + [[f[0], f[1]] for f in filas]
    w_asp = 9.0 * cm
    w_res = PAGE_W - w_asp
    t = Table(data, colWidths=[w_asp, w_res])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 7. Detalle Completo ───────────────────────────────────────────────────────
def detalle_table(productos, mostrar_tienda):
    if mostrar_tienda:
        col_w = [3.0, 1.8, 4.0, 1.4, 2.2, 2.2, 1.8]
        hdrs  = ['Sucursal', 'Código', 'Producto', 'Stock', 'P. Compra', 'P. Venta', 'Margen']
    else:
        col_w = [2.0, 5.5, 1.5, 2.5, 2.5, 2.0]
        hdrs  = ['Código', 'Producto', 'Stock', 'P. Compra', 'P. Venta', 'Margen']
    # Ajustar último col para completar PAGE_W
    resto  = PAGE_W / cm - sum(col_w)
    col_w[-1] += resto

    data = [[P(h, ST_HDR) for h in hdrs]]
    tot_stock = 0; tot_compra = 0.0; tot_venta = 0.0

    for p in productos:
        stock  = _stock(p.get('StockenTienda', 0))
        compra = _num(p.get('PrecioCompra', 0))
        venta  = _num(p.get('PrecioVenta',  0))
        margen = (venta - compra) / compra * 100 if compra > 0 else 0
        tot_stock  += stock
        tot_compra += compra
        tot_venta  += venta

        mg_color = '#28a745' if margen >= 50 else '#17a2b8' if margen >= 20 else '#ffc107' if margen > 0 else '#6b7280'
        mg_cell  = Paragraph('<font color="{}">{}</font>'.format(
            mg_color, '{:.1f}%'.format(margen) if compra > 0 else '—'), ST_CELL_C)

        stock_color = '#dc3545' if stock == 0 else '#856404' if stock <= 5 else '#28a745'
        stock_cell  = Paragraph('<font color="{}">{}</font>'.format(stock_color, stock), ST_BOLD_C)

        if mostrar_tienda:
            row = [
                P(p.get('NombreTienda', ''),   ST_CELL),
                P(p.get('CodigoProducto', ''), ST_CELL_C),
                P(p.get('NombreProducto', ''), ST_CELL),
                stock_cell,
                P(gs(compra), ST_CELL_R),
                P(gs(venta),  ST_CELL_R),
                mg_cell,
            ]
        else:
            row = [
                P(p.get('CodigoProducto', ''), ST_CELL_C),
                P(p.get('NombreProducto', ''), ST_CELL),
                stock_cell,
                P(gs(compra), ST_CELL_R),
                P(gs(venta),  ST_CELL_R),
                mg_cell,
            ]
        data.append(row)

    # Fila totales
    if mostrar_tienda:
        tot_row = [
            P('TOTAL: {} producto(s)'.format(len(productos)), _sty(
                fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO)),
            P('', ST_CELL), P('', ST_CELL),
            P(str(tot_stock), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
            P(gs(tot_compra), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
            P(gs(tot_venta),  _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
            P('', ST_CELL),
        ]
        span = (0, len(data)), (2, len(data))
    else:
        tot_row = [
            P('TOTAL: {} producto(s)'.format(len(productos)), _sty(
                fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO)),
            P('', ST_CELL),
            P(str(tot_stock), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
            P(gs(tot_compra), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
            P(gs(tot_venta),  _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
            P('', ST_CELL),
        ]
        span = (0, len(data)), (1, len(data))

    data.append(tot_row)
    tot_idx = len(data) - 1

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0),     (-1, 0),       AZUL),
        ('ROWBACKGROUNDS', (0, 1),     (-1, tot_idx-1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0),     (-1, -1),      0.3, GRIS_M),
        ('BACKGROUND',     (0, tot_idx), (-1, tot_idx), GRIS_OS),
        ('SPAN',           span[0],    span[1]),
    ]))
    return t


# ── 8. Totalizadores (cajas 4×2) ─────────────────────────────────────────────
def totales_table(productos):
    total     = len(productos)
    stock_tot = sum(_stock(p.get('StockenTienda', 0)) for p in productos)
    val_costo = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioCompra', 0)) for p in productos)
    pot_venta = sum(_stock(p.get('StockenTienda', 0)) * _num(p.get('PrecioVenta',  0)) for p in productos)
    sin_stock = sum(1 for p in productos if _stock(p.get('StockenTienda', 0)) == 0)
    critico   = sum(1 for p in productos if 0 < _stock(p.get('StockenTienda', 0)) <= 5)
    margenes  = [(_num(p.get('PrecioVenta', 0)) - _num(p.get('PrecioCompra', 0))) / _num(p.get('PrecioCompra', 0)) * 100
                 for p in productos if _num(p.get('PrecioCompra', 0)) > 0]
    mg_prom   = sum(margenes) / len(margenes) if margenes else 0
    ganancia  = pot_venta - val_costo

    w = PAGE_W / 4.0

    def mini(label, valor):
        mt = Table(
            [[P(label, ST_KPI_L)],
             [P(str(valor), ST_KPI_S if len(str(valor)) > 12 else ST_KPI_V)]],
            colWidths=[w - 0.4 * cm]
        )
        mt.setStyle(TableStyle([
            ('TOPPADDING',    (0,0), (-1,-1), 3),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3),
            ('LEFTPADDING',   (0,0), (-1,-1), 4),
            ('RIGHTPADDING',  (0,0), (-1,-1), 4),
            ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        ]))
        return mt

    data = [
        [mini('TOTAL PRODUCTOS',  str(total)),
         mini('STOCK TOTAL',      '{:,}'.format(stock_tot).replace(',','.')),
         mini('VALOR A COSTO',    gs(val_costo)),
         mini('POTENCIAL VENTA',  gs(pot_venta))],
        [mini('SIN STOCK',        str(sin_stock)),
         mini('STOCK CRÍTICO',    str(critico)),
         mini('MARGEN PROMEDIO',  '{:.1f}%'.format(mg_prom)),
         mini('GANANCIA POTENCIAL', gs(ganancia))],
    ]

    t = Table(data, colWidths=[w] * 4)
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AZUL_CLR),
        ('GRID',          (0,0), (-1,-1), 0.8, INFO),
        ('TOPPADDING',    (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING',   (0,0), (-1,-1), 0),
        ('RIGHTPADDING',  (0,0), (-1,-1), 0),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    empresa        = data.get('NombreEmpresa',  '')
    id_tienda      = int(data.get('IdTienda',   0) or 0)
    nombre_tienda  = data.get('NombreTienda',   'Todas las sucursales')
    codigo_filtro  = data.get('CodigoFiltro',   '')
    nombre_usuario = data.get('NombreUsuario',  '')
    reporte_id     = data.get('ReporteId',      '')
    logo_path      = data.get('LogoPath',       '')
    productos      = data.get('Productos',      [])

    mostrar_tienda = (id_tienda == 0)

    partes = []
    if not mostrar_tienda: partes.append('Sucursal: ' + nombre_tienda)
    if codigo_filtro:      partes.append('Código: ' + codigo_filtro)
    filtros = '   '.join(partes) if partes else 'Todos los productos'

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Productos'
    )

    cb = _Canvas('Reporte Gerencial de Productos', empresa,
                 '', filtros, nombre_usuario, reporte_id, logo_path)

    story = []

    if not productos:
        story.append(P('Sin resultados para los filtros seleccionados.', _sty(fontSize=9)))
    else:
        # 1. Resumen Ejecutivo
        story.append(P('Resumen Ejecutivo', ST_SEC))
        story.append(resumen_ejecutivo_table(productos))

        # 2. Top por Stock
        story.append(P('Top Productos por Stock', ST_SEC))
        story.append(top_stock_table(productos))

        # 3. Sin Stock
        story.append(P('Productos Sin Stock', ST_SEC))
        story.append(sin_stock_table(productos))

        # 4. Rango de Precios
        story.append(P('Distribución por Rango de Precio', ST_SEC))
        story.append(rango_precios_table(productos))

        # 5. Top Margen
        story.append(P('Top Productos por Margen', ST_SEC))
        story.append(top_margen_table(productos))

        # 6. Análisis Gerencial
        story.append(P('Análisis Gerencial', ST_SEC))
        story.append(analisis_table(productos))

        # 7. Detalle Completo
        story.append(P('Detalle Completo', ST_SEC))
        story.append(detalle_table(productos, mostrar_tienda))

        # 8. Totalizadores
        story.append(Spacer(1, 8))
        story.append(P('Totalizadores', ST_SEC))
        story.append(totales_table(productos))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_productos_tienda.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
