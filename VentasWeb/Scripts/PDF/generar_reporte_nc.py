# ============================================================
#  generar_reporte_nc.py
#  Reporte Gerencial de Notas de Crédito — Landscape A4
#  Uso: python generar_reporte_nc.py <json> <pdf>
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
from reportlab.platypus      import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

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
AMBAR   = colors.HexColor('#856404')
AMBAR_L = colors.HexColor('#fff3cd')
AMBAR_M = colors.HexColor('#ffc107')
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
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=8, leading=10)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=AMBAR,
                spaceBefore=10, spaceAfter=4)
ST_HDR   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_HDR_L = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO)
ST_CELL  = _sty(fontSize=7.5, leading=10)
ST_CELL_C= _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_CELL_R= _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_BOLD  = _sty(fontSize=7.5, leading=10, fontName='Helvetica-Bold')
ST_BOLD_C= _sty(fontSize=7.5, leading=10, fontName='Helvetica-Bold', alignment=TA_CENTER)
ST_BOLD_R= _sty(fontSize=7.5, leading=10, fontName='Helvetica-Bold', alignment=TA_RIGHT)
ST_KPI_L = _sty(fontSize=7,   textColor=GRIS_T, alignment=TA_CENTER)
ST_KPI_V = _sty(fontSize=11,  fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER)
ST_KPI_S = _sty(fontSize=8,   fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_CENTER, leading=11)
ST_SMALL = _sty(fontSize=6.5, leading=9, textColor=GRIS_T)

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

def barra(n, maximo, largo=18):
    if maximo <= 0: return ''
    b = max(1, round(n / maximo * largo)) if n > 0 else 0
    return '█' * b


# ── 1. Resumen Ejecutivo (tabla KPI) ─────────────────────────────────────────
def resumen_ejecutivo_table(items):
    total      = len(items)
    monto_tot  = sum(float(str(nc.get('MontoNC', 0)).replace(',', '')) for nc in items if True)
    provs      = len(set(nc.get('Proveedor', '') for nc in items))
    promedio   = monto_tot / total if total > 0 else 0
    recibidas  = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Recibida')
    pendientes = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Pendiente')
    pct_rec    = '{:.1f}%'.format(recibidas  / total * 100) if total > 0 else '0%'
    pct_pend   = '{:.1f}%'.format(pendientes / total * 100) if total > 0 else '0%'

    st_lbl = _sty(fontSize=7.5, fontName='Helvetica-Bold')
    st_val = _sty(fontSize=8,   fontName='Helvetica-Bold', textColor=AZUL, alignment=TA_RIGHT)

    rows = [
        [P('Indicador', ST_HDR_L),              P('Valor', ST_HDR)],
        [P('NC Recibidas',             st_lbl), P(str(recibidas),         st_val)],
        [P('Proveedores involucrados', st_lbl), P(str(provs),             st_val)],
        [P('Monto Total NC',           st_lbl), P(gs(monto_tot),          st_val)],
        [P('Monto Promedio por NC',    st_lbl), P(gs(promedio),           st_val)],
        [P('NC Recibidas',             st_lbl), P('{} ({})'.format(recibidas,  pct_rec),  st_val)],
        [P('NC Pendientes',            st_lbl), P('{} ({})'.format(pendientes, pct_pend), st_val)],
    ]

    w_lbl = 8.0 * cm
    w_val = 4.0 * cm
    t = Table(rows, colWidths=[w_lbl, w_val])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 2. Estado de las NC ───────────────────────────────────────────────────────
def estado_table(items):
    total      = len(items)
    recibidas  = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Recibida')
    pendientes = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Pendiente')
    rechazadas = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Rechazada')
    max_val    = max(recibidas, pendientes, rechazadas, 1)

    def fila(label, n, color):
        pct = '{:.1f}%'.format(n / total * 100) if total > 0 else '0%'
        return [P(label, ST_CELL), P(str(n), ST_BOLD_C), P(pct, ST_CELL_C),
                Paragraph('<font color="#{}">{}</font>'.format(
                    color, barra(n, max_val)), ST_CELL)]

    rows = [
        [P('Estado', ST_HDR), P('Cantidad', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)],
        fila('Recibidas',  recibidas,  '28a745'),
        fila('Pendientes', pendientes, '6c757d'),
        fila('Rechazadas', rechazadas, 'dc3545'),
    ]

    w = [4.5, 2.5, 2.0, PAGE_W / cm - 9.0]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',    (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS',(0, 1), (-1, -1), [VERDE_L, AMBAR_L, ROJO_L]),
        ('GRID',          (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 3. Top Proveedores por Monto ──────────────────────────────────────────────
def top_proveedores_table(items):
    mapa = {}
    for nc in items:
        p = nc.get('Proveedor') or 'Sin proveedor'
        try: m = float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: m = 0.0
        if p not in mapa: mapa[p] = {'cantidad': 0, 'monto': 0.0}
        mapa[p]['cantidad'] += 1
        mapa[p]['monto']    += m

    sorted_provs = sorted(mapa.items(), key=lambda x: x[1]['monto'], reverse=True)
    monto_total  = sum(v['monto'] for _, v in sorted_provs) or 1
    max_monto    = sorted_provs[0][1]['monto'] if sorted_provs else 1

    rows = [[P('Proveedor', ST_HDR_L), P('Cant.', ST_HDR), P('Monto', ST_HDR),
             P('% del Total', ST_HDR), P('Gráfico', ST_HDR_L)]]

    for prov, v in sorted_provs:
        pct = '{:.1f}%'.format(v['monto'] / monto_total * 100)
        rows.append([
            P(prov, ST_CELL),
            P(str(v['cantidad']), ST_CELL_C),
            P(gs(v['monto']), ST_CELL_R),
            P(pct, ST_CELL_C),
            Paragraph('<font color="#ffc107">{}</font>'.format(
                barra(v['monto'], max_monto)), ST_CELL),
        ])

    w = [6.5, 2.0, 3.5, 2.5, PAGE_W / cm - 14.5]
    t = Table(rows, colWidths=[x * cm for x in w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 4. Motivos ────────────────────────────────────────────────────────────────
def motivos_table(items):
    mapa = {}
    for nc in items:
        m = nc.get('MotivoNC') or 'Sin motivo'
        mapa[m] = mapa.get(m, 0) + 1

    sorted_mot = sorted(mapa.items(), key=lambda x: x[1], reverse=True)
    total      = len(items) or 1
    max_val    = sorted_mot[0][1] if sorted_mot else 1

    rows = [[P('Motivo', ST_HDR_L), P('Cantidad', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)]]
    for motivo, n in sorted_mot:
        pct = '{:.1f}%'.format(n / total * 100)
        rows.append([
            P(motivo, ST_CELL),
            P(str(n), ST_BOLD_C),
            P(pct, ST_CELL_C),
            Paragraph('<font color="#ffc107">{}</font>'.format(barra(n, max_val)), ST_CELL),
        ])

    w = [8.0, 2.5, 2.0, PAGE_W / cm - 12.5]
    t = Table(rows, colWidths=[x * cm for x in w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 5. Impacto Económico ──────────────────────────────────────────────────────
def impacto_table(items):
    montos     = [float(str(nc.get('MontoNC', 0)).replace(',', '')) for nc in items]
    monto_tot  = sum(montos)
    mayor_nc   = max(montos) if montos else 0
    promedio   = monto_tot / len(items) if items else 0
    max_val    = monto_tot or 1

    def fila(label, valor, color):
        pct = '{:.1f}%'.format(valor / max_val * 100) if max_val > 0 else '0%'
        return [P(label, ST_CELL), P(gs(valor), ST_BOLD_R), P(pct, ST_CELL_C),
                Paragraph('<font color="{}">{}</font>'.format(color,
                    barra(valor, max_val)), ST_CELL)]

    rows = [
        [P('Concepto', ST_HDR_L), P('Valor', ST_HDR), P('%', ST_HDR), P('Gráfico', ST_HDR_L)],
        fila('Monto Total NC',      monto_tot, '#28a745'),
        fila('Mayor NC Individual', mayor_nc,  '#ffc107'),
        fila('Promedio por NC',     promedio,  '#17a2b8'),
    ]

    w = [6.0, 4.0, 2.0, PAGE_W / cm - 12.0]
    t = Table(rows, colWidths=[x * cm for x in w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [VERDE_L, AMBAR_L, GRIS_L]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 6. Análisis Gerencial ─────────────────────────────────────────────────────
def analisis_table(items):
    total      = len(items)
    monto_tot  = sum(float(str(nc.get('MontoNC', 0)).replace(',', '')) for nc in items)
    recibidas  = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Recibida')

    mapa_prov  = {}
    for nc in items:
        p = nc.get('Proveedor') or '—'
        try: m = float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: m = 0.0
        mapa_prov[p] = mapa_prov.get(p, 0.0) + m
    mayor_prov = max(mapa_prov, key=mapa_prov.get) if mapa_prov else '—'

    st_asp = _sty(fontSize=7.5, fontName='Helvetica-Bold')
    st_res = _sty(fontSize=7.5)

    rows = [
        [P('Aspecto', ST_HDR_L), P('Resultado', ST_HDR)],
        [P('Total de NC recibidas',              st_asp), P(str(recibidas), st_res)],
        [P('Monto total recuperado',             st_asp), P(gs(monto_tot),  st_res)],
        [P('Proveedor con mayor monto acumulado',st_asp), P(mayor_prov,     st_res)],
    ]

    w_asp = 8.0 * cm
    w_res = PAGE_W - w_asp
    t = Table(rows, colWidths=[w_asp, w_res])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0, 0), (-1, 0),  AZUL),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_L, BLANCO]),
        ('GRID',           (0, 0), (-1, -1), 0.3, GRIS_M),
    ]))
    return t


# ── 7. Detalle Completo ───────────────────────────────────────────────────────
def detalle_table(items):
    col_w = [2.2, 5.5, 4.0, 3.5, 3.5, 2.5, 3.0, 2.5]
    resto = PAGE_W / cm - sum(col_w)
    col_w.append(max(resto, 2.0))

    hdrs = ['Fecha Reg.', 'Proveedor', 'Tienda', 'Factura / Fecha',
            'N° NC', 'F. Emisión', 'Monto NC', 'Estado', 'Motivo']
    data       = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []
    total_monto= 0.0

    for i, nc in enumerate(items):
        estado    = (nc.get('Estado') or 'Pendiente').strip()
        es_morosa = nc.get('EsMorosa', False)
        try:    monto = float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: monto = 0.0
        total_monto += monto

        est_color = VERDE if estado == 'Recibida' else ROJO if estado == 'Rechazada' else GRIS_T
        st_est = _sty(fontSize=7.5, leading=10, alignment=TA_CENTER,
                      textColor=est_color, fontName='Helvetica-Bold')

        prov_txt  = nc.get('Proveedor') or '—'
        ruc_txt   = nc.get('RucProveedor') or ''
        prov_cell = Paragraph(
            prov_txt + ('<br/><font size="6" color="#6b7280">' + ruc_txt + '</font>' if ruc_txt else ''),
            ST_CELL)

        fac_txt  = nc.get('NumeroFactura') or '—'
        fac_fec  = nc.get('FechaFactura')  or ''
        fac_cell = Paragraph(
            fac_txt + ('<br/><font size="6" color="#6b7280">' + fac_fec + '</font>' if fac_fec else ''),
            ST_CELL_C)

        est_label = estado + (' ⚠' if es_morosa else '')

        data.append([
            P(nc.get('FechaRegistro', ''), ST_CELL_C),
            prov_cell,
            P(nc.get('Tienda', ''),        ST_CELL),
            fac_cell,
            P(nc.get('NumeroNC') or '—',   ST_CELL_C),
            P(nc.get('FechaEmision') or '—',ST_CELL_C),
            P(gs(monto),                   ST_CELL_R),
            P(est_label,                   st_est),
            P(nc.get('MotivoNC') or '—',   ST_CELL),
        ])

        if es_morosa:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), AMBAR_L))
        elif i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i+1), (-1, i+1), GRIS_L))

    # Fila total
    ncols = len(col_w)
    data.append([
        P('TOTAL: {} NC(s)'.format(len(items)), _sty(
            fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
        '', '', '', '', '',
        P(gs(total_monto), _sty(
            fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)),
        '', ''
    ])
    tot_row = len(data) - 1
    row_styles += [
        ('BACKGROUND', (0, tot_row), (-1, tot_row), GRIS_OS),
        ('SPAN',       (0, tot_row), (5, tot_row)),
        ('SPAN',       (7, tot_row), (8, tot_row)),
    ]

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
    ] + row_styles))
    return t


# ── 8. Totalizadores (8 cajas KPI) ───────────────────────────────────────────
def totales_table(items):
    total      = len(items)
    montos     = [float(str(nc.get('MontoNC', 0)).replace(',', '')) for nc in items]
    monto_tot  = sum(montos)
    promedio   = monto_tot / total if total > 0 else 0
    provs      = len(set(nc.get('Proveedor', '') for nc in items))
    recibidas  = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Recibida')
    pendientes = sum(1 for nc in items if (nc.get('Estado') or '').strip() == 'Pendiente')
    pct_rec    = '{:.1f}%'.format(recibidas  / total * 100) if total > 0 else '0%'
    pct_pend   = '{:.1f}%'.format(pendientes / total * 100) if total > 0 else '0%'

    mapa_mot   = {}
    for nc in items:
        m = nc.get('MotivoNC') or 'Sin motivo'
        mapa_mot[m] = mapa_mot.get(m, 0) + 1
    mot_keys   = sorted(mapa_mot, key=mapa_mot.get, reverse=True)
    mot_ppal   = mot_keys[0] if mot_keys else '—'
    pct_mot    = '{:.1f}%'.format(mapa_mot[mot_ppal] / total * 100) if total > 0 and mot_ppal != '—' else '0%'

    mapa_prov  = {}
    for nc in items:
        p = nc.get('Proveedor') or '—'
        try: m = float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: m = 0.0
        mapa_prov[p] = mapa_prov.get(p, 0.0) + m
    mayor_prov = max(mapa_prov, key=mapa_prov.get) if mapa_prov else '—'

    def caja(label, valor):
        return [P(label, ST_KPI_L),
                P(str(valor), ST_KPI_S if len(str(valor)) > 10 else ST_KPI_V)]

    w = PAGE_W / 4.0

    fila1 = [caja('TOTAL NC',          str(total)),
             caja('MONTO TOTAL NC',    gs(monto_tot)),
             caja('PROVEEDORES',       str(provs)),
             caja('PROMEDIO POR NC',   gs(promedio))]

    fila2 = [caja('RECIBIDAS',              '{} ({})'.format(recibidas, pct_rec)),
             caja('PENDIENTES',             '{} ({})'.format(pendientes, pct_pend)),
             caja('MOTIVO PRINCIPAL',       '{} ({})'.format(mot_ppal[:20], pct_mot)),
             caja('MAYOR PROV. AFECTADO',   mayor_prov[:25])]

    # Aplanar: cada celda de la grilla tiene 2 filas (label + valor)
    # Usamos una tabla de 4 cols × 2 filas, con cada celda conteniendo a su vez una mini-tabla
    def mini(label, valor):
        mt = Table([[P(label, ST_KPI_L)], [P(str(valor), ST_KPI_S if len(str(valor)) > 12 else ST_KPI_V)]],
                   colWidths=[w - 0.4 * cm])
        mt.setStyle(TableStyle([
            ('TOPPADDING',    (0,0), (-1,-1), 3),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3),
            ('LEFTPADDING',   (0,0), (-1,-1), 4),
            ('RIGHTPADDING',  (0,0), (-1,-1), 4),
            ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        ]))
        return mt

    data = [
        [mini('TOTAL NC',          str(total)),
         mini('MONTO TOTAL NC',    gs(monto_tot)),
         mini('PROVEEDORES',       str(provs)),
         mini('PROMEDIO POR NC',   gs(promedio))],
        [mini('RECIBIDAS',                '{} ({})'.format(recibidas, pct_rec)),
         mini('PENDIENTES',               '{} ({})'.format(pendientes, pct_pend)),
         mini('MOTIVO PRINCIPAL',         '{}\n({})'.format(mot_ppal[:22], pct_mot)),
         mini('MAYOR PROV. AFECTADO',     mayor_prov[:26])],
    ]

    t = Table(data, colWidths=[w] * 4)
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AZUL_CLR),
        ('GRID',          (0,0), (-1,-1), 0.8, AMBAR_M),
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
    nombre_usuario = data.get('NombreUsuario',  '')
    reporte_id     = data.get('ReporteId',      '')
    logo_path      = data.get('LogoPath',       '')
    fi             = data.get('FechaInicio',    '')
    ff             = data.get('FechaFin',       '')
    prov_filtro    = data.get('NombreProveedor','') or ''
    estado_filtro  = data.get('EstadoFiltro',  '') or ''
    items          = data.get('Items',          [])

    periodo = (fi + ' — ' + ff) if fi and ff else ''

    partes = []
    if prov_filtro:   partes.append('Proveedor: ' + prov_filtro)
    if estado_filtro: partes.append('Estado: '    + estado_filtro)
    filtros = '   '.join(partes)

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Notas de Crédito'
    )

    cb = _Canvas('Reporte Gerencial de Notas de Crédito', empresa,
                 periodo, filtros, nombre_usuario, reporte_id, logo_path)

    story = []

    # ── Resumen Ejecutivo
    story.append(P('Resumen Ejecutivo', ST_SEC))
    story.append(resumen_ejecutivo_table(items))

    # ── Estado
    story.append(P('Estado de las Notas de Crédito', ST_SEC))
    story.append(estado_table(items))

    # ── Top Proveedores
    story.append(P('Proveedores con Mayor Monto de NC', ST_SEC))
    story.append(top_proveedores_table(items))

    # ── Motivos
    story.append(P('Motivos de las Notas de Crédito', ST_SEC))
    story.append(motivos_table(items))

    # ── Impacto Económico
    story.append(P('Impacto Económico', ST_SEC))
    story.append(impacto_table(items))

    # ── Análisis Gerencial
    story.append(P('Análisis Gerencial', ST_SEC))
    story.append(analisis_table(items))

    # ── Detalle Completo
    story.append(P('Detalle Completo', ST_SEC))
    if items:
        story.append(detalle_table(items))
    else:
        story.append(P('Sin notas de crédito para los filtros seleccionados.',
                       _sty(fontSize=9)))

    # ── Totalizadores
    story.append(Spacer(1, 8))
    story.append(P('Totalizadores', ST_SEC))
    story.append(totales_table(items))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_nc.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
