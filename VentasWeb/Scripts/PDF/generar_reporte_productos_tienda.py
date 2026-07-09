# ============================================================
#  generar_reporte_productos_tienda.py
#  Reporte de Productos por Tienda — Portrait A4
#  Uso: python generar_reporte_productos_tienda.py <json> <pdf>
#  Dependencias: reportlab
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
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = A4                      # 210 × 297 mm portrait
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # 18.0 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
VERDE_L = colors.HexColor('#d1fae5')
AMBAR_L = colors.HexColor('#fef3c7')
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
ST_CELL  = _sty(fontSize=7, leading=9)
ST_CELL_R= _sty(fontSize=7, leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=7, leading=9, alignment=TA_CENTER)
ST_SMALL = _sty(fontSize=5.5, leading=7.5, textColor=GRIS_T)
ST_TOT   = _sty(fontSize=7.5, fontName='Helvetica-Bold', leading=10)
ST_TOT_R = _sty(fontSize=7.5, fontName='Helvetica-Bold', leading=10, alignment=TA_RIGHT)
ST_TOT_C = _sty(fontSize=7.5, fontName='Helvetica-Bold', leading=10, alignment=TA_CENTER)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(str(v).replace(',', ''))).replace(',', '.')
    except: return 'Gs. 0'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)


# ── Helpers de parseo ────────────────────────────────────────────────────────
def _parse_num(v):
    """Convierte '50,000.00' o 50000 a float."""
    try:
        return float(str(v).replace(',', ''))
    except:
        return 0.0

def _parse_int(v):
    try:
        return int(str(v).replace(',', '') or 0)
    except:
        return 0

# ── Tabla principal ───────────────────────────────────────────────────────────
#
# Modo una sola sucursal — 6 columnas (18.0 cm):
#   Código | Producto | Descripción | Stock | P.Compra | P.Venta
#   1.8    |   5.5    |    4.5      |  1.2  |   2.5    |  2.5
#
# Modo todas las sucursales — 7 columnas (18.0 cm):
#   Tienda/RUC | Código | Producto | Descripción | Stock | P.Compra | P.Venta
#   3.5        |  1.8   |   4.2    |    3.5      |  1.2  |   2.0    |  1.8

COL_W_UNA   = [1.8, 5.5, 4.5, 1.2, 2.5, 2.5]
HDRS_UNA    = ['Código', 'Producto', 'Descripción', 'Stock', 'P. Compra', 'P. Venta']

COL_W_TODAS = [3.5, 1.8, 4.2, 3.5, 1.2, 2.0, 1.8]
HDRS_TODAS  = ['Tienda / RUC', 'Código', 'Producto', 'Descripción', 'Stock', 'P. Compra', 'P. Venta']

def productos_table(productos, mostrar_tienda):
    col_w = COL_W_TODAS if mostrar_tienda else COL_W_UNA
    hdrs  = HDRS_TODAS  if mostrar_tienda else HDRS_UNA

    data = [[P(h, ST_HDR) for h in hdrs]]

    for p in productos:
        tienda_nom  = p.get('NombreTienda', '') or ''
        tienda_ruc  = p.get('RucTienda',    '') or ''
        descripcion = (p.get('DescripcionProducto') or '—')[:45]

        fila_prod = [
            P(p.get('CodigoProducto', ''),    ST_CELL_C),
            P(p.get('NombreProducto', ''),    ST_CELL),
            P(descripcion,                    ST_CELL),
            P(str(p.get('StockenTienda', 0)), ST_CELL_C),
            P(gs(p.get('PrecioCompra', 0)),   ST_CELL_R),
            P(gs(p.get('PrecioVenta',  0)),   ST_CELL_R),
        ]

        if mostrar_tienda:
            tienda_cell = [
                P(tienda_nom, ST_CELL),
                P(tienda_ruc, ST_SMALL),
            ]
            row = [tienda_cell] + fila_prod
        else:
            row = fila_prod

        data.append(row)

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ── Fila de totales ───────────────────────────────────────────────────────────
def totales_table(productos, mostrar_tienda):
    col_w     = COL_W_TODAS if mostrar_tienda else COL_W_UNA
    n_prod    = len(productos)
    n_tiendas = len(set(p.get('NombreTienda', '') for p in productos))

    tot_stock  = sum(_parse_int(p.get('StockenTienda', 0)) for p in productos)
    tot_compra = sum(_parse_num(p.get('PrecioCompra',  0)) for p in productos)
    tot_venta  = sum(_parse_num(p.get('PrecioVenta',   0)) for p in productos)

    label = 'TOTAL: {} producto(s)'.format(n_prod)
    if mostrar_tienda and n_tiendas > 1:
        label += ' en {} sucursal(es)'.format(n_tiendas)

    if mostrar_tienda:
        # 7 cols: span cols 0-3 (Tienda,Código,Producto,Desc), luego Stock,Compra,Venta
        row = [
            P(label,           ST_TOT),
            P('', ST_CELL), P('', ST_CELL), P('', ST_CELL),
            P(str(tot_stock),  ST_TOT_C),
            P(gs(tot_compra),  ST_TOT_R),
            P(gs(tot_venta),   ST_TOT_R),
        ]
        span_end = (3, 0)
    else:
        # 6 cols: span cols 0-2 (Código,Producto,Desc), luego Stock,Compra,Venta
        row = [
            P(label,           ST_TOT),
            P('', ST_CELL), P('', ST_CELL),
            P(str(tot_stock),  ST_TOT_C),
            P(gs(tot_compra),  ST_TOT_R),
            P(gs(tot_venta),   ST_TOT_R),
        ]
        span_end = (2, 0)

    t = Table([row], colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('TEXTCOLOR',  (0,0), (-1,0), BLANCO),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
        ('SPAN',       (0,0), span_end),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda        = data.get('NombreTienda',  'Todas las sucursales')
    ruc           = data.get('RucTienda',     '')
    empresa       = data.get('NombreEmpresa', tienda)
    codigo        = data.get('CodigoFiltro',  '')
    id_tienda     = int(data.get('IdTienda',  0) or 0)
    productos     = data.get('Productos',     [])
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')

    # Columna Tienda solo cuando se consulta "todas las sucursales"
    mostrar_tienda = (id_tienda == 0)

    filtro_cod = ('Código: ' + codigo) if codigo else 'Todos los productos'
    filtros    = filtro_cod

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte de Productos por Tienda'
    )

    cb    = _Canvas('Reporte de Productos por Tienda', empresa, '',
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    if productos:
        story.append(productos_table(productos, mostrar_tienda))
        story.append(Spacer(1, 0))
        story.append(totales_table(productos, mostrar_tienda))
    else:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_NRM))

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
