# ============================================================
#  generar_reporte_nc.py
#  Reporte de Notas de Crédito Asociadas — Landscape A4
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
VERDE   = colors.HexColor('#28a745')
ROJO    = colors.HexColor('#dc3545')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
GRIS_OS = colors.HexColor('#1f2937')
AMBAR   = colors.HexColor('#856404')
AMBAR_L = colors.HexColor('#fff3cd')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=8, leading=10)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=AZUL, spaceBefore=8, spaceAfter=4)
ST_HDR   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7.5, leading=10)
ST_CELL_C= _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_CELL_R= _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
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


# ── Tabla principal ───────────────────────────────────────────────────────────
# Columnas (26.7 cm):
# Fecha Reg | Proveedor/RUC | Tienda | Factura/Fecha | N° NC | F. Emisión | Monto | Estado | Motivo
# 2.2       | 5.5           | 4.0    | 3.5           | 3.5   | 2.5        | 3.0   | 2.5    | ← resto

def nc_table(items):
    col_w = [2.2, 5.5, 4.0, 3.5, 3.5, 2.5, 3.0, 2.5]
    # Motivo toma el espacio restante
    resto = PAGE_W / cm - sum(col_w)
    col_w.append(max(resto, 2.0))

    hdrs = ['Fecha Reg.', 'Proveedor', 'Tienda', 'Factura / Fecha',
            'N° NC', 'F. Emisión', 'Monto NC', 'Estado', 'Motivo']

    data       = [[P(h, ST_HDR) for h in hdrs]]
    row_styles = []

    total_monto = 0.0

    for i, nc in enumerate(items):
        estado = (nc.get('Estado') or 'Pendiente').strip()
        es_morosa = nc.get('EsMorosa', False)

        if estado == 'Recibida':
            est_color = VERDE
        elif estado == 'Rechazada':
            est_color = ROJO
        else:
            est_color = GRIS_T

        try:    monto = float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: monto = 0.0
        total_monto += monto

        st_est = _sty(fontSize=7.5, leading=10, alignment=TA_CENTER,
                      textColor=est_color, fontName='Helvetica-Bold')

        # Proveedor + RUC en una sola celda
        prov_txt = (nc.get('Proveedor') or '—')
        ruc_txt  = nc.get('RucProveedor') or ''
        prov_cell = Paragraph(
            prov_txt + ('<br/><font size="6" color="#6b7280">' + ruc_txt + '</font>' if ruc_txt else ''),
            ST_CELL)

        # Factura + fecha
        fac_txt = (nc.get('NumeroFactura') or '—')
        fac_fecha= nc.get('FechaFactura') or ''
        fac_cell = Paragraph(
            fac_txt + ('<br/><font size="6" color="#6b7280">' + fac_fecha + '</font>' if fac_fecha else ''),
            ST_CELL_C)

        # Estado + morosa
        est_label = estado + (' ⚠' if es_morosa else '')

        data.append([
            P(nc.get('FechaRegistro', ''), ST_CELL_C),
            prov_cell,
            P(nc.get('Tienda', ''), ST_CELL),
            fac_cell,
            P(nc.get('NumeroNC') or '—', ST_CELL_C),
            P(nc.get('FechaEmision') or '—', ST_CELL_C),
            P(gs(monto), ST_CELL_R),
            P(est_label, st_est),
            P(nc.get('MotivoNC') or '—', ST_CELL),
        ])

        if es_morosa:
            row_styles.append(('BACKGROUND', (0, i + 1), (-1, i + 1), AMBAR_L))
        elif i % 2 == 1:
            row_styles.append(('BACKGROUND', (0, i + 1), (-1, i + 1), GRIS_L))

    # Fila total
    ncols = len(col_w)
    data.append([
        P('TOTAL: ' + str(len(items)) + ' NC(s)', _sty(
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


# ── Tabla resumen ─────────────────────────────────────────────────────────────
def resumen_table(items):
    total_monto  = 0.0
    pendientes   = 0
    morosas      = 0
    recibidas    = 0
    rechazadas   = 0

    for nc in items:
        estado = (nc.get('Estado') or '').strip()
        try:    total_monto += float(str(nc.get('MontoNC', 0)).replace(',', ''))
        except: pass
        if estado == 'Recibida':  recibidas += 1
        elif estado == 'Rechazada': rechazadas += 1
        else: pendientes += 1
        if nc.get('EsMorosa'): morosas += 1

    st_lbl = _sty(fontSize=8, fontName='Helvetica-Bold')
    st_val = _sty(fontSize=8, alignment=TA_RIGHT)
    st_tot = _sty(fontSize=8, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)

    data = [
        [P('Total NCs',       st_lbl), P(str(len(items)),   st_val)],
        [P('Monto Total',     st_lbl), P(gs(total_monto),   st_val)],
        [P('Recibidas',       st_lbl), P(str(recibidas),    st_val)],
        [P('Pendientes',      st_lbl), P(str(pendientes),   st_val)],
        [P('Morosas (>30d)',  st_lbl), P(str(morosas),      st_val)],
        [P('Rechazadas',      st_lbl), P(str(rechazadas),   st_val)],
    ]
    ancho = PAGE_W / cm
    t = Table(data, colWidths=[(ancho - 4) * cm, 4 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0, 0), (-1, -1), GRIS_L),
        ('BACKGROUND', (0, 1), (-1, 1),  AZUL),
        ('TEXTCOLOR',  (0, 1), (-1, 1),  BLANCO),
        ('GRID',       (0, 0), (-1, -1), 0.3, GRIS_M),
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
        title='Reporte de Notas de Crédito'
    )

    cb    = _Canvas('Reporte de Notas de Crédito Asociadas', empresa,
                    periodo, filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    story.append(P('Detalle de Notas de Crédito' + (' — ' + periodo if periodo else ''), ST_SEC))
    story.append(Spacer(1, 4))

    if items:
        story.append(nc_table(items))
    else:
        story.append(P('Sin notas de crédito registradas para los filtros seleccionados.',
                       _sty(fontSize=9)))

    story.append(Spacer(1, 10))
    story.append(P('Resumen', ST_SEC))
    story.append(resumen_table(items))

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
