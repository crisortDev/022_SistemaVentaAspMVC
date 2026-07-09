# ============================================================
#  generar_stock_pdf.py
#  Reporte Gerencial de Productos por Tienda — Landscape A4
#  Uso: python generar_stock_pdf.py <json> <pdf>
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
from reportlab.platypus      import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = landscape(A4)
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 26.7 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#28a745')
ROJO    = colors.HexColor('#dc3545')
AMBAR   = colors.HexColor('#856404')
AMBAR_L = colors.HexColor('#fff3cd')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
GRIS_OS = colors.HexColor('#1f2937')
GRIS_H  = colors.HexColor('#dcdcdc')
CIAN    = colors.HexColor('#17a2b8')
VERDE_L = colors.HexColor('#d4edda')
ROJO_L  = colors.HexColor('#f8d7da')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=8, leading=10)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=AZUL, spaceBefore=6, spaceAfter=4)
ST_HDR   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7.5, leading=10)
ST_CELL_C= _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_CELL_R= _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_SMALL = _sty(fontSize=6.5, leading=9,  textColor=GRIS_T)
ST_TIEND = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=BLANCO)
ST_CAT   = _sty(fontSize=8,   fontName='Helvetica-Bold', textColor=GRIS_OS)
ST_SUB   = _sty(fontSize=7.5, fontName='Helvetica-Oblique', textColor=GRIS_T, alignment=TA_RIGHT)
ST_TOT_C = _sty(fontSize=8,   fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)
ST_TOT_G = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)
ST_KPI_L = _sty(fontSize=8,   fontName='Helvetica-Bold')
ST_KPI_V = _sty(fontSize=8,   alignment=TA_RIGHT)
ST_KPI_H = _sty(fontSize=8,   fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)

CELL_PAD = [
    ('TOPPADDING',    (0, 0), (-1, -1), 2),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ('LEFTPADDING',   (0, 0), (-1, -1), 4),
    ('RIGHTPADDING',  (0, 0), (-1, -1), 4),
    ('VALIGN',        (0, 0), (-1, -1), 'MIDDLE'),
]


def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '', sty)


def gs(v):
    """Formatea un número como Guaraníes: Gs. 1.234.567"""
    try:
        return 'Gs. {:,.0f}'.format(float(str(v).replace(',', ''))).replace(',', '.')
    except:
        return 'Gs. 0'


def pct(v, denom):
    """Calcula porcentaje con denominador seguro."""
    try:
        d = float(denom)
        return '{:.1f} %'.format(float(v) / d * 100) if d != 0 else '—'
    except:
        return '—'


def estado_color(est, stock):
    e = (est or '').upper()
    s = float(stock or 0)
    if s == 0:       return colors.HexColor('#6c757d')  # gris — SIN STOCK
    if e == 'CRITICO': return ROJO
    if e == 'BAJO':    return AMBAR
    return VERDE


# ════════════════════════════════════════════════════════════════════════════
#  1. RESUMEN EJECUTIVO (KPIs)
# ════════════════════════════════════════════════════════════════════════════
def kpi_table(items):
    ids     = set()
    tiendas = set()
    total_u = 0; inversion = 0; valor_v = 0
    sin_stock = 0; criticos = 0

    for r in items:
        ids.add(r.get('IdProducto'))
        tiendas.add(r.get('NombreTienda'))
        s  = float(r.get('Stock', 0)         or 0)
        c  = float(r.get('CostoUnitario', 0) or 0)
        pv = float(r.get('PrecioVenta', 0)   or 0)
        total_u   += s
        inversion += s * c
        valor_v   += s * pv
        if s == 0: sin_stock += 1
        if (r.get('EstadoStock') or '').upper() == 'CRITICO': criticos += 1

    ganancia = valor_v - inversion
    margen   = pct(ganancia, inversion)

    rows = [
        [P('Indicador', ST_KPI_H),              P('Resultado', ST_KPI_H)],
        [P('Total de productos registrados', ST_KPI_L), P(str(len(ids)),            ST_KPI_V)],
        [P('Total de sucursales',            ST_KPI_L), P(str(len(tiendas)),        ST_KPI_V)],
        [P('Total unidades en stock',        ST_KPI_L), P('{:,.0f}'.format(total_u).replace(',','.'), ST_KPI_V)],
        [P('Inversión en inventario',        ST_KPI_L), P(gs(inversion),            ST_KPI_V)],
        [P('Valor potencial de venta',       ST_KPI_L), P(gs(valor_v),              ST_KPI_V)],
        [P('Ganancia potencial estimada',    ST_KPI_L), P(gs(ganancia),             ST_KPI_V)],
        [P('Margen potencial',               ST_KPI_L), P(margen,                   ST_KPI_V)],
        [P('Productos sin stock',            ST_KPI_L), P(str(sin_stock),           ST_KPI_V)],
        [P('Productos con stock crítico',    ST_KPI_L), P(str(criticos),            ST_KPI_V)],
    ]

    ancho = PAGE_W / cm
    t = Table(rows, colWidths=[(ancho - 5) * cm, 5 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('BACKGROUND', (0, 1), (-1, -1), GRIS_L),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  2. RESUMEN POR SUCURSAL
# ════════════════════════════════════════════════════════════════════════════
def resumen_sucursal_table(items):
    suc = {}
    for r in items:
        n = r.get('NombreTienda') or '(Sin tienda)'
        if n not in suc:
            suc[n] = {'prods': set(), 'stock': 0, 'compra': 0, 'venta': 0}
        suc[n]['prods'].add(r.get('IdProducto'))
        s = float(r.get('Stock', 0) or 0)
        suc[n]['stock']  += s
        suc[n]['compra'] += s * float(r.get('CostoUnitario', 0) or 0)
        suc[n]['venta']  += s * float(r.get('PrecioVenta',   0) or 0)

    hdrs = ['Sucursal', 'Productos', 'Stock Total', 'Valor Compra', 'Valor Venta', 'Ganancia Potencial']
    data = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    tot_prods = set(); tot_s = 0; tot_c = 0; tot_v = 0
    for r in items:
        tot_prods.add(r.get('IdProducto'))
        s = float(r.get('Stock', 0) or 0)
        tot_s += s
        tot_c += s * float(r.get('CostoUnitario', 0) or 0)
        tot_v += s * float(r.get('PrecioVenta',   0) or 0)

    for i, n in enumerate(sorted(suc.keys())):
        d = suc[n]
        gan = d['venta'] - d['compra']
        st_gan = _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT,
                      textColor=VERDE if gan >= 0 else ROJO, fontName='Helvetica-Bold')
        data.append([
            P(n,                        ST_CELL),
            P(str(len(d['prods'])),     ST_CELL_C),
            P('{:,.0f}'.format(d['stock']).replace(',','.'), ST_CELL_C),
            P(gs(d['compra']),          ST_CELL_R),
            P(gs(d['venta']),           ST_CELL_R),
            P(gs(gan),                  st_gan),
        ])
        if i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), GRIS_L))

    # Total
    gan_tot = tot_v - tot_c
    data.append([
        P('TOTAL GENERAL', _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO)),
        P(str(len(tot_prods)), _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
        P('{:,.0f}'.format(tot_s).replace(',','.'), _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
        P(gs(tot_c), _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
        P(gs(tot_v), _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
        P(gs(gan_tot), _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
    ])
    tot_row = len(data) - 1
    row_styles.append(('BACKGROUND', (0, tot_row), (-1, tot_row), GRIS_OS))

    # Column widths: Sucursal | Prods | Stock | Compra | Venta | Ganancia
    ancho = PAGE_W / cm
    col_w = [ancho - 3.0 - 2.5 - 4.0 - 4.0 - 4.0, 3.0, 2.5, 4.0, 4.0, 4.0]
    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  3. DETALLE DE PRODUCTOS POR SUCURSAL (agrupado Tienda → Categoría)
# ════════════════════════════════════════════════════════════════════════════
# Columnas (26.7 cm):
# Código | Producto | Descripción | Stock | Costo Unit. | Venta Unit. | Valor Inv. | Margen | Estado
# 2.5    | 6.0      | 4.5         | 1.6   | 2.6         | 2.6         | 2.6        | 1.8    | 2.5
NCOLS = 9
COL_W = [2.5, 6.0, 4.5, 1.6, 2.6, 2.6, 2.6, 1.8, 2.5]

HDRS = ['Código', 'Producto', 'Descripción', 'Stock',
        'Costo Unit.', 'Venta Unit.', 'Valor Inv.', 'Margen', 'Estado']


def build_stock_table(items):
    grupos = {}
    for r in items:
        tienda = r.get('NombreTienda') or '(Sin tienda)'
        cat    = r.get('Categoria')    or '(Sin categoría)'
        grupos.setdefault(tienda, {}).setdefault(cat, []).append(r)

    col_w_pts = [w * cm for w in COL_W]
    data       = [[P(h, ST_HDR) for h in HDRS]]
    row_styles = []
    row_idx    = 1

    total_general = 0

    for tienda in sorted(grupos.keys()):
        total_tienda = 0

        # Encabezado tienda
        data.append([P('●  TIENDA: ' + tienda.upper(), ST_TIEND)] + [''] * (NCOLS - 1))
        row_styles += [
            ('SPAN',       (0, row_idx), (-1, row_idx)),
            ('BACKGROUND', (0, row_idx), (-1, row_idx), VERDE),
        ]
        row_idx += 1

        for cat in sorted(grupos[tienda].keys()):
            prods     = grupos[tienda][cat]
            total_cat = 0

            # Encabezado categoría
            data.append([P('   ▸  Categoría: ' + cat, ST_CAT)] + [''] * (NCOLS - 1))
            row_styles += [
                ('SPAN',       (0, row_idx), (-1, row_idx)),
                ('BACKGROUND', (0, row_idx), (-1, row_idx), GRIS_H),
            ]
            row_idx += 1

            for i, p in enumerate(prods):
                stock = float(p.get('Stock', 0) or 0)
                costo = float(p.get('CostoUnitario', 0) or 0)
                pv    = float(p.get('PrecioVenta', 0)   or 0)
                val   = stock * costo
                margen_val = ((pv - costo) / costo * 100) if costo > 0 else None
                margen_txt = '{:.0f}%'.format(margen_val) if margen_val is not None else '—'

                try: total_cat += int(stock)
                except: pass

                est   = (p.get('EstadoStock') or '').upper()
                ec    = estado_color(est, stock)
                lbl   = 'SIN STOCK' if stock == 0 else est
                st_est = _sty(fontSize=7, leading=9, alignment=TA_CENTER,
                              textColor=ec, fontName='Helvetica-Bold')
                st_mg  = _sty(fontSize=7, leading=9, alignment=TA_CENTER,
                              textColor=(ROJO if (margen_val or 0) < 0 else (VERDE if (margen_val or 0) > 0 else GRIS_T)),
                              fontName='Helvetica-Bold')

                desc = (p.get('Descripcion') or '').strip()
                data.append([
                    P(p.get('Codigo', ''),      ST_CELL_C),
                    P(p.get('NombreProducto', ''), ST_CELL),
                    P(desc,                     ST_SMALL),
                    P(str(int(stock)),          ST_CELL_C),
                    P(gs(costo),                ST_CELL_R),
                    P(gs(pv),                   ST_CELL_R),
                    P(gs(val),                  ST_CELL_R),
                    P(margen_txt,               st_mg),
                    P(lbl,                      st_est),
                ])
                if i % 2 == 1:
                    row_styles.append(('BACKGROUND', (0, row_idx), (-1, row_idx), GRIS_L))
                row_idx += 1

            total_tienda += total_cat

            # Subtotal categoría
            data.append([P('Subtotal ' + cat + ': ' + str(total_cat) + ' u.', ST_SUB)]
                        + [''] * (NCOLS - 1))
            row_styles += [
                ('SPAN',       (0, row_idx), (-1, row_idx)),
                ('BACKGROUND', (0, row_idx), (-1, row_idx), colors.HexColor('#f8f9fa')),
            ]
            row_idx += 1

        total_general += total_tienda

        # Total tienda
        data.append([P('TOTAL ' + tienda.upper() + ': ' + str(total_tienda) + ' unidades', ST_TOT_C)]
                    + [''] * (NCOLS - 1))
        row_styles += [
            ('SPAN',       (0, row_idx), (-1, row_idx)),
            ('BACKGROUND', (0, row_idx), (-1, row_idx), CIAN),
        ]
        row_idx += 1

    # Total general
    data.append([P('TOTAL GENERAL: ' + str(total_general) + ' unidades', ST_TOT_G)]
                + [''] * (NCOLS - 1))
    row_styles += [
        ('SPAN',       (0, row_idx), (-1, row_idx)),
        ('BACKGROUND', (0, row_idx), (-1, row_idx), GRIS_OS),
    ]

    t = Table(data, colWidths=col_w_pts, repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  4. PRODUCTOS SIN STOCK
# ════════════════════════════════════════════════════════════════════════════
def sin_stock_table(sin_stock):
    hdrs = ['Código', 'Producto', 'Sucursal']
    data = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    for i, p in enumerate(sin_stock):
        data.append([
            P(p.get('Codigo', ''),         ST_CELL_C),
            P(p.get('NombreProducto', ''), ST_CELL),
            P(p.get('NombreTienda', ''),   ST_CELL),
        ])
        row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), ROJO_L))

    ancho  = PAGE_W / cm
    col_w  = [2.5, ancho - 2.5 - 6.0, 6.0]
    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), ROJO),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  5. MAYOR VALOR INMOVILIZADO (Top 5)
# ════════════════════════════════════════════════════════════════════════════
def top_inmovilizado_table(items):
    mp = {}
    for r in items:
        pid = r.get('IdProducto')
        s   = float(r.get('Stock', 0)         or 0)
        c   = float(r.get('CostoUnitario', 0) or 0)
        if pid not in mp:
            mp[pid] = {'nombre': r.get('NombreProducto', ''), 'stock': 0, 'valor': 0}
        mp[pid]['stock'] += s
        mp[pid]['valor'] += s * c

    top = sorted([v for v in mp.values() if v['valor'] > 0],
                 key=lambda x: -x['valor'])[:5]

    hdrs = ['Producto', 'Stock Total', 'Valor Compra']
    data = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    for i, v in enumerate(top):
        st_v = _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT,
                    fontName='Helvetica-Bold', textColor=GRIS_OS)
        data.append([
            P(v['nombre'],                  ST_CELL),
            P(str(int(v['stock'])),         ST_CELL_C),
            P(gs(v['valor']),               st_v),
        ])
        if i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), GRIS_L))

    ancho = PAGE_W / cm
    col_w = [ancho - 3.0 - 4.0, 3.0, 4.0]
    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), GRIS_OS),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  6. DISTRIBUCIÓN DEL INVENTARIO
# ════════════════════════════════════════════════════════════════════════════
def distribucion_table(items):
    suc = {}
    total = 0
    for r in items:
        n = r.get('NombreTienda') or '(Sin tienda)'
        s = float(r.get('Stock', 0) or 0)
        suc[n] = suc.get(n, 0) + s
        total += s

    hdrs = ['Sucursal', '%', 'Distribución']
    data = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    for i, n in enumerate(sorted(suc.keys())):
        p_val = (suc[n] / total * 100) if total > 0 else 0
        bars  = max(1, round(p_val / 5))
        bar_txt = '█' * bars
        st_bar = _sty(fontSize=10, leading=12, textColor=VERDE)
        data.append([
            P(n,                           ST_CELL),
            P('{:.1f}%'.format(p_val),     ST_CELL_C),
            P(bar_txt + '  ' + '{:,.0f}'.format(suc[n]).replace(',','.') + ' u.', st_bar),
        ])
        if i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), GRIS_L))

    ancho = PAGE_W / cm
    col_w = [ancho - 2.5 - 10.0, 2.5, 10.0]
    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), CIAN),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  7. ESTADO DEL STOCK
# ════════════════════════════════════════════════════════════════════════════
def estado_stock_table(items):
    ok = bajo = critico = sin_s = 0
    for r in items:
        s = float(r.get('Stock', 0) or 0)
        e = (r.get('EstadoStock') or '').upper()
        if s == 0:           sin_s   += 1
        elif e == 'CRITICO': critico += 1
        elif e == 'BAJO':    bajo    += 1
        else:                ok      += 1

    st_lbl_ok  = _sty(fontSize=8, fontName='Helvetica-Bold', textColor=VERDE)
    st_lbl_baj = _sty(fontSize=8, fontName='Helvetica-Bold', textColor=AMBAR)
    st_lbl_cri = _sty(fontSize=8, fontName='Helvetica-Bold', textColor=ROJO)
    st_lbl_sin = _sty(fontSize=8, fontName='Helvetica-Bold', textColor=GRIS_T)
    st_val     = _sty(fontSize=8, alignment=TA_RIGHT)

    data = [
        [P('Estado',      ST_KPI_H), P('Registros', ST_KPI_H)],
        [P('OK — Disponible',       st_lbl_ok),  P(str(ok),      st_val)],
        [P('BAJO — Stock bajo',     st_lbl_baj), P(str(bajo),    st_val)],
        [P('CRÍTICO — Stock crítico', st_lbl_cri), P(str(critico), st_val)],
        [P('Sin stock',             st_lbl_sin), P(str(sin_s),   st_val)],
    ]

    ancho = PAGE_W / cm
    t = Table(data, colWidths=[(ancho - 3) * cm, 3 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0),  AZUL),
        ('BACKGROUND', (0, 1), (-1, 1),  VERDE_L),
        ('BACKGROUND', (0, 2), (-1, 2),  AMBAR_L),
        ('BACKGROUND', (0, 3), (-1, 3),  ROJO_L),
        ('BACKGROUND', (0, 4), (-1, 4),  GRIS_L),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    empresa        = data.get('NombreEmpresa',   '')
    nombre_usuario = data.get('NombreUsuario',   '')
    reporte_id     = data.get('ReporteId',       '')
    logo_path      = data.get('LogoPath',        '')
    tienda_filtro  = data.get('NombreTienda',    '') or 'Todas las tiendas'
    cat_filtro     = data.get('CategoriaFiltro', '') or ''
    estado_filtro  = data.get('EstadoFiltro',    '') or ''
    items          = data.get('Items',           [])

    partes_filtro = ['Tienda: ' + tienda_filtro]
    if cat_filtro:    partes_filtro.append('Cat.: '   + cat_filtro)
    if estado_filtro: partes_filtro.append('Estado: ' + estado_filtro)
    filtros = '   '.join(partes_filtro)

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Productos por Tienda'
    )

    periodo = 'Fecha: ' + datetime.now().strftime('%d/%m/%Y')
    cb = _Canvas('Reporte Gerencial de Productos por Tienda', empresa,
                 periodo, filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    # ── 1. Resumen ejecutivo ──────────────────────────────────────────────
    story.append(P('Resumen Ejecutivo de Inventario', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(kpi_table(items))
    story.append(Spacer(1, 8))

    # ── 2. Resumen por sucursal ───────────────────────────────────────────
    story.append(P('Resumen por Sucursal', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(resumen_sucursal_table(items))
    story.append(Spacer(1, 8))

    # ── 3. Detalle de productos ───────────────────────────────────────────
    story.append(P('Detalle de Productos por Sucursal', ST_SEC))
    story.append(Spacer(1, 2))
    if items:
        story.append(build_stock_table(items))
    else:
        story.append(P('Sin productos para los filtros seleccionados.', _sty(fontSize=9)))
    story.append(Spacer(1, 8))

    # ── 4. Productos sin stock ────────────────────────────────────────────
    sin_stock = [r for r in items if float(r.get('Stock', 0) or 0) == 0]
    story.append(P('Productos sin Stock (' + str(len(sin_stock)) + ')', ST_SEC))
    story.append(Spacer(1, 2))
    if sin_stock:
        story.append(sin_stock_table(sin_stock))
    else:
        story.append(P('Todos los productos registrados tienen stock disponible.', _sty(fontSize=8)))
    story.append(Spacer(1, 8))

    # ── 5. Mayor valor inmovilizado ───────────────────────────────────────
    story.append(P('Productos con Mayor Valor Inmovilizado (Top 5)', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(top_inmovilizado_table(items))
    story.append(Spacer(1, 8))

    # ── 6. Distribución del inventario ───────────────────────────────────
    story.append(P('Distribución del Inventario por Sucursal', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(distribucion_table(items))
    story.append(Spacer(1, 8))

    # ── 7. Estado del stock ───────────────────────────────────────────────
    story.append(P('Estado del Stock', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(estado_stock_table(items))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_stock_pdf.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
