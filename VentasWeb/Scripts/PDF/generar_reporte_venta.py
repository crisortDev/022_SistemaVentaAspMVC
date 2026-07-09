# ============================================================
#  generar_reporte_venta.py
#  Reporte Gerencial de Ventas — Landscape A4
#  Uso: python generar_reporte_venta.py <json> <pdf>
# ============================================================

import sys
import os
import json

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
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7.5, leading=10)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=AZUL,
                spaceBefore=10, spaceAfter=4)
ST_HDR   = _sty(fontSize=7,   fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_HDR_L = _sty(fontSize=7,   fontName='Helvetica-Bold', textColor=BLANCO)
ST_CELL  = _sty(fontSize=7,   leading=9)
ST_CELL_C= _sty(fontSize=7,   leading=9, alignment=TA_CENTER)
ST_CELL_R= _sty(fontSize=7,   leading=9, alignment=TA_RIGHT)
ST_BOLD  = _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold')
ST_BOLD_C= _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold', alignment=TA_CENTER)
ST_BOLD_R= _sty(fontSize=7,   leading=9, fontName='Helvetica-Bold', alignment=TA_RIGHT)
ST_KPI_L = _sty(fontSize=6.5, textColor=GRIS_T, alignment=TA_CENTER)
ST_KPI_V = _sty(fontSize=10,  fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER)
ST_KPI_S = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER, leading=10)

CELL_PAD = [
    ('TOPPADDING',    (0, 0), (-1, -1), 2),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ('LEFTPADDING',   (0, 0), (-1, -1), 4),
    ('RIGHTPADDING',  (0, 0), (-1, -1), 4),
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

def es_anulada(est):
    return (est or '').strip().lower() in ('anulada', 'anulado', 'cancelada', 'cancelado')

def normalizar_estado(est):
    est = (est or '').strip()
    if not est or est.lower().startswith('activ'): return 'Efectiva'
    return est

def barra(n, maximo, largo=16):
    if maximo <= 0: return ''
    b = max(1, round(n / maximo * largo)) if n > 0 else 0
    return '█' * b


# ── 1. Resumen Ejecutivo ─────────────────────────────────────────────────────
def resumen_ejecutivo_table(ventas):
    total     = len(ventas)
    monto     = 0.0
    efectivas = 0
    anuladas  = 0
    unidades  = 0
    montos    = []

    for v in ventas:
        estado = normalizar_estado(v.get('Estado'))
        m      = _num(v.get('TotalVenta', 0))
        u      = int(v.get('CantidadUnidadesVendidas', 0) or 0)
        if es_anulada(estado):
            anuladas += 1
        else:
            efectivas += 1
            monto += m
            unidades += u
            montos.append(m)

    promedio   = monto / efectivas if efectivas else 0
    mayor      = max(montos) if montos else 0
    pct_anul   = '{:.1f}%'.format(anuladas / total * 100) if total else '0%'

    st_lbl = _sty(fontSize=7, fontName='Helvetica-Bold')
    st_val = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_RIGHT)

    rows = [
        [P('Indicador', ST_HDR_L),                          P('Valor', ST_HDR)],
        [P('Total ventas registradas',           st_lbl),   P(str(total),                                 st_val)],
        [P('Ventas efectivas',                   st_lbl),   P('{} ({:.1f}%)'.format(efectivas, efectivas/total*100 if total else 0), st_val)],
        [P('Ventas anuladas',                    st_lbl),   P('{} ({})'.format(anuladas, pct_anul),       st_val)],
        [P('Monto total del período',            st_lbl),   P(gs(monto),                                  st_val)],
        [P('Promedio por venta efectiva',        st_lbl),   P(gs(promedio),                               st_val)],
        [P('Mayor venta individual',             st_lbl),   P(gs(mayor),                                  st_val)],
        [P('Total unidades vendidas',            st_lbl),   P('{:,}'.format(unidades).replace(',','.'),   st_val)],
    ]

    t = Table(rows, colWidths=[10 * cm, 6 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 2. Estado ─────────────────────────────────────────────────────────────────
def estado_table(ventas):
    total     = len(ventas) or 1
    efectivas = 0; mEfect = 0.0
    anuladas  = 0; mAnul  = 0.0

    for v in ventas:
        m = _num(v.get('TotalVenta', 0))
        if es_anulada(normalizar_estado(v.get('Estado'))):
            anuladas += 1; mAnul  += m
        else:
            efectivas += 1; mEfect += m

    max_cant = max(efectivas, anuladas, 1)

    def fila(label, n, monto, color):
        pct = '{:.1f}%'.format(n / total * 100)
        return [P(label, ST_CELL), P(str(n), ST_BOLD_C), P(gs(monto), ST_CELL_R),
                P(pct, ST_CELL_C),
                Paragraph('<font color="{}">{}</font>'.format(color, barra(n, max_cant)), ST_CELL)]

    rows = [
        [P('Estado', ST_HDR), P('Cant.', ST_HDR), P('Monto', ST_HDR),
         P('%', ST_HDR), P('Gráfico', ST_HDR_L)],
        fila('Efectivas', efectivas, mEfect, '#28a745'),
        fila('Anuladas',  anuladas,  mAnul,  '#dc3545'),
    ]

    w = [4.0, 2.0, 4.0, 1.8, PAGE_W / cm - 11.8]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',    (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS',(0, 1), (-1, -1), [VERDE_L, ROJO_L]),
        ('GRID',          (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 3. Top Empleados ──────────────────────────────────────────────────────────
def top_empleados_table(ventas):
    mapa = {}
    for v in ventas:
        if es_anulada(normalizar_estado(v.get('Estado'))): continue
        emp  = (v.get('NombreEmpleado') or 'Sin nombre').strip()
        m    = _num(v.get('TotalVenta', 0))
        if emp not in mapa: mapa[emp] = {'monto': 0.0, 'cant': 0}
        mapa[emp]['monto'] += m
        mapa[emp]['cant']  += 1

    sorted_emp  = sorted(mapa.items(), key=lambda x: x[1]['monto'], reverse=True)
    monto_total = sum(v['monto'] for _, v in sorted_emp) or 1
    max_monto   = sorted_emp[0][1]['monto'] if sorted_emp else 1

    rows = [[P('Empleado', ST_HDR_L), P('Ventas', ST_HDR),
             P('Monto', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for emp, d in sorted_emp:
        pct = '{:.1f}%'.format(d['monto'] / monto_total * 100)
        rows.append([
            P(emp,              ST_CELL),
            P(str(d['cant']),   ST_CELL_C),
            P(gs(d['monto']),   ST_BOLD_R),
            P(pct,              ST_CELL_C),
            Paragraph('<font color="#1a3566">{}</font>'.format(barra(d['monto'], max_monto)), ST_CELL),
        ])

    w = [6.0, 2.0, 4.0, 2.0, PAGE_W / cm - 14.0]
    t = Table(rows, colWidths=[x * cm for x in w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 4. Forma de Cobro ─────────────────────────────────────────────────────────
def forma_cobro_table(ventas):
    mapa = {}
    for v in ventas:
        if es_anulada(normalizar_estado(v.get('Estado'))): continue
        f = (v.get('FormaCobro') or 'Sin especificar').strip()
        m = _num(v.get('TotalVenta', 0))
        if f not in mapa: mapa[f] = {'monto': 0.0, 'cant': 0}
        mapa[f]['monto'] += m
        mapa[f]['cant']  += 1

    sorted_f    = sorted(mapa.items(), key=lambda x: x[1]['monto'], reverse=True)
    monto_total = sum(v['monto'] for _, v in sorted_f) or 1
    max_monto   = sorted_f[0][1]['monto'] if sorted_f else 1
    bar_colors  = ['#28a745', '#1a3566', '#17a2b8', '#ffc107', '#6c757d']

    rows = [[P('Forma de Cobro', ST_HDR_L), P('Ventas', ST_HDR),
             P('Monto', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for i, (forma, d) in enumerate(sorted_f):
        pct   = '{:.1f}%'.format(d['monto'] / monto_total * 100)
        color = bar_colors[i % len(bar_colors)]
        rows.append([
            P(forma,            ST_CELL),
            P(str(d['cant']),   ST_CELL_C),
            P(gs(d['monto']),   ST_BOLD_R),
            P(pct,              ST_CELL_C),
            Paragraph('<font color="{}">{}</font>'.format(color, barra(d['monto'], max_monto)), ST_CELL),
        ])

    w = [5.0, 2.0, 4.0, 2.0, PAGE_W / cm - 13.0]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 5. Top Clientes ───────────────────────────────────────────────────────────
def top_clientes_table(ventas):
    mapa = {}
    for v in ventas:
        if es_anulada(normalizar_estado(v.get('Estado'))): continue
        cli = (v.get('Cliente') or 'Consumidor Final').strip()
        m   = _num(v.get('TotalVenta', 0))
        if cli not in mapa: mapa[cli] = {'monto': 0.0, 'cant': 0}
        mapa[cli]['monto'] += m
        mapa[cli]['cant']  += 1

    sorted_c    = sorted(mapa.items(), key=lambda x: x[1]['monto'], reverse=True)[:10]
    monto_total = sum(v['monto'] for _, v in sorted_c) or 1
    max_monto   = sorted_c[0][1]['monto'] if sorted_c else 1

    rows = [[P('Cliente', ST_HDR_L), P('Compras', ST_HDR),
             P('Monto', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for cli, d in sorted_c:
        pct = '{:.1f}%'.format(d['monto'] / monto_total * 100)
        rows.append([
            P(cli[:35],         ST_CELL),
            P(str(d['cant']),   ST_CELL_C),
            P(gs(d['monto']),   ST_BOLD_R),
            P(pct,              ST_CELL_C),
            Paragraph('<font color="#ffc107">{}</font>'.format(barra(d['monto'], max_monto)), ST_CELL),
        ])

    w = [7.0, 2.0, 4.0, 2.0, PAGE_W / cm - 15.0]
    t = Table(rows, colWidths=[x * cm for x in w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 6. Análisis Gerencial ─────────────────────────────────────────────────────
def analisis_table(ventas):
    total     = len(ventas) or 1
    monto     = 0.0; efectivas = 0; anuladas = 0; unidades = 0
    emp_map   = {}; cli_map = {}; cob_map = {}; montos = []

    for v in ventas:
        estado = normalizar_estado(v.get('Estado'))
        m      = _num(v.get('TotalVenta', 0))
        u      = int(v.get('CantidadUnidadesVendidas', 0) or 0)
        if es_anulada(estado):
            anuladas += 1
        else:
            efectivas += 1; monto += m; unidades += u; montos.append(m)
            emp = (v.get('NombreEmpleado') or 'Sin nombre').strip()
            emp_map[emp] = emp_map.get(emp, 0) + m
            cli = (v.get('Cliente') or 'Consumidor Final').strip()
            cli_map[cli] = cli_map.get(cli, 0) + m
            cob = (v.get('FormaCobro') or 'Sin especificar').strip()
            cob_map[cob] = cob_map.get(cob, 0) + 1

    promedio = monto / efectivas if efectivas else 0
    mayor    = max(montos) if montos else 0
    emp_top  = max(emp_map, key=emp_map.get) if emp_map else '—'
    cli_top  = max(cli_map, key=cli_map.get) if cli_map else '—'
    cob_top  = max(cob_map, key=cob_map.get) if cob_map else '—'

    st_asp = _sty(fontSize=7, fontName='Helvetica-Bold')
    st_res = _sty(fontSize=7)

    filas = [
        (P('Total ventas registradas',            st_asp), P(str(total),                                       st_res)),
        (P('Ventas efectivas',                    st_asp), P('{} ({:.1f}%)'.format(efectivas, efectivas/total*100), st_res)),
        (P('Ventas anuladas',                     st_asp), P('{} ({:.1f}%)'.format(anuladas,  anuladas/total*100),  st_res)),
        (P('Monto total del período',             st_asp), P(gs(monto),                                        st_res)),
        (P('Promedio por venta efectiva',         st_asp), P(gs(promedio),                                     st_res)),
        (P('Mayor venta individual',              st_asp), P(gs(mayor),                                        st_res)),
        (P('Total unidades vendidas',             st_asp), P('{:,}'.format(unidades).replace(',','.'),         st_res)),
        (P('Empleado con mayor facturación',      st_asp), P(emp_top + ' — ' + gs(emp_map.get(emp_top, 0)),   st_res)),
        (P('Cliente con mayor compra acumulada',  st_asp), P(cli_top + ' — ' + gs(cli_map.get(cli_top, 0)),   st_res)),
        (P('Forma de cobro más utilizada',        st_asp), P(cob_top,                                         st_res)),
    ]

    data = [[P('Aspecto', ST_HDR_L), P('Resultado', ST_HDR)]] + [[f[0], f[1]] for f in filas]
    t = Table(data, colWidths=[10 * cm, PAGE_W - 10 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 7. Detalle Completo ───────────────────────────────────────────────────────
def detalle_table(ventas):
    col_w = [2.2, 3.5, 1.8, 2.0, 4.5, 3.0, 4.0, 1.5]
    resto  = PAGE_W / cm - sum(col_w)
    col_w.append(max(resto, 2.0))

    hdrs = ['Fecha', 'N° Documento', 'Tipo', 'Estado',
            'Cliente', 'Forma Cobro', 'Empleado', 'Unid.', 'Total (Gs.)']

    data       = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []
    total_monto= 0.0; total_unid = 0

    for i, v in enumerate(ventas):
        estado = normalizar_estado(v.get('Estado'))
        anul   = es_anulada(estado)
        m      = _num(v.get('TotalVenta', 0))
        u      = int(v.get('CantidadUnidadesVendidas', 0) or 0)
        if not anul: total_monto += m; total_unid += u

        est_color = ROJO if anul else VERDE
        st_est = _sty(fontSize=7, leading=9, alignment=TA_CENTER,
                      textColor=est_color, fontName='Helvetica-Bold')

        data.append([
            P(v.get('FechaVenta', ''),                       ST_CELL_C),
            P(v.get('NumeroDocumento', ''),                  ST_CELL),
            P(v.get('TipoDocumento', ''),                    ST_CELL_C),
            P(estado,                                        st_est),
            P((v.get('Cliente') or 'Consumidor Final')[:30], ST_CELL),
            P((v.get('FormaCobro') or '—'),                  ST_CELL),
            P((v.get('NombreEmpleado') or '')[:25],          ST_CELL),
            P(str(u),                                        ST_CELL_C),
            P(gs(m),                                         ST_CELL_R),
        ])

        if anul:
            row_styles.append(('TEXTCOLOR', (0, i+1), (-1, i+1), GRIS_T))
        elif i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), GRIS_L))

    # Fila total
    tot_idx = len(data)
    data.append([
        P('TOTAL PERÍODO: {} venta(s)'.format(len(ventas)), _sty(
            fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
        '', '', '', '', '',
        P('', ST_CELL),
        P(str(total_unid), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)),
        P(gs(total_monto), _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
    ])
    row_styles += [
        ('BACKGROUND', (0, tot_idx), (-1, tot_idx), GRIS_OS),
        ('SPAN',       (0, tot_idx), (6, tot_idx)),
    ]

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ── 8. Totalizadores (4×2) ────────────────────────────────────────────────────
def totales_table(ventas):
    total     = len(ventas)
    monto     = 0.0; efectivas = 0; anuladas = 0; unidades = 0; montos = []
    emp_map   = {}; cob_map = {}

    for v in ventas:
        estado = normalizar_estado(v.get('Estado'))
        m      = _num(v.get('TotalVenta', 0))
        u      = int(v.get('CantidadUnidadesVendidas', 0) or 0)
        if es_anulada(estado):
            anuladas += 1
        else:
            efectivas += 1; monto += m; unidades += u; montos.append(m)
            emp = (v.get('NombreEmpleado') or 'Sin nombre').strip()
            emp_map[emp] = emp_map.get(emp, 0) + m
            cob = (v.get('FormaCobro') or 'Sin especificar').strip()
            cob_map[cob] = cob_map.get(cob, 0) + 1

    promedio = monto / efectivas if efectivas else 0
    mayor    = max(montos) if montos else 0
    emp_top  = max(emp_map, key=emp_map.get) if emp_map else '—'
    cob_top  = max(cob_map, key=cob_map.get) if cob_map else '—'

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
        [mini('TOTAL VENTAS',         str(total)),
         mini('MONTO TOTAL',          gs(monto)),
         mini('EFECTIVAS',            str(efectivas)),
         mini('ANULADAS',             str(anuladas))],
        [mini('PROMEDIO POR VENTA',   gs(promedio)),
         mini('TOTAL UNIDADES',       '{:,}'.format(unidades).replace(',','.')),
         mini('EMPLEADO ESTRELLA',    emp_top[:22]),
         mini('COBRO MÁS FRECUENTE', cob_top[:22])],
    ]

    t = Table(data, colWidths=[w] * 4)
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AZUL_CLR),
        ('GRID',          (0,0), (-1,-1), 0.8, AZUL),
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
    nombre_tienda  = data.get('NombreTienda',   '')
    fi_str         = data.get('FechaInicio',    '')
    ff_str         = data.get('FechaFin',       '')
    estado_filtro  = data.get('EstadoFiltro',   '') or ''
    reporte_id     = data.get('ReporteId',      '')
    nombre_usuario = data.get('NombreUsuario',  '')
    logo_path      = data.get('LogoPath',       '')
    ventas         = data.get('Ventas',         [])

    periodo = (fi_str + ' — ' + ff_str) if fi_str and ff_str else ''

    partes = []
    if nombre_tienda:  partes.append('Sucursal: ' + nombre_tienda)
    if estado_filtro:  partes.append('Estado: ' + estado_filtro)
    filtros = '   '.join(partes) if partes else 'Todas las sucursales'

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Ventas'
    )

    cb = _Canvas('Reporte Gerencial de Ventas', empresa,
                 periodo, filtros, nombre_usuario, reporte_id, logo_path)

    story = []

    if not ventas:
        story.append(P('Sin ventas registradas para los filtros seleccionados.', _sty(fontSize=9)))
    else:
        # 1. Resumen Ejecutivo
        story.append(P('Resumen Ejecutivo', ST_SEC))
        story.append(resumen_ejecutivo_table(ventas))

        # 2. Estado
        story.append(P('Estado de las Ventas', ST_SEC))
        story.append(estado_table(ventas))

        # 3. Top Empleados
        story.append(P('Top Empleados por Facturación', ST_SEC))
        story.append(top_empleados_table(ventas))

        # 4. Forma de Cobro
        story.append(P('Distribución por Forma de Cobro', ST_SEC))
        story.append(forma_cobro_table(ventas))

        # 5. Top Clientes
        story.append(P('Top Clientes por Monto Acumulado', ST_SEC))
        story.append(top_clientes_table(ventas))

        # 6. Análisis Gerencial
        story.append(P('Análisis Gerencial', ST_SEC))
        story.append(analisis_table(ventas))

        # 7. Detalle Completo
        story.append(P('Detalle Completo', ST_SEC))
        story.append(detalle_table(ventas))

        # 8. Totalizadores
        story.append(Spacer(1, 8))
        story.append(P('Totalizadores', ST_SEC))
        story.append(totales_table(ventas))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_venta.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
