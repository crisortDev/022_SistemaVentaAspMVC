# ============================================================
#  generar_reporte_compras.py  —  v2 (una sola página, landscape)
#  Uso: python generar_reporte_compras.py <ruta_json> <ruta_pdf>
#  Dependencias: reportlab   (pip install reportlab)
# ============================================================

import sys
import json
from datetime import datetime

from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)

# ── Página ────────────────────────────────────────────────────────────────────
PAGE      = landscape(A4)          # 29.7 × 21 cm
MARG_H    = 1.2 * cm
MARG_TOP  = 2.2 * cm
MARG_BOT  = 1.3 * cm
PAGE_W    = PAGE[0] - 2 * MARG_H  # ≈ 27.3 cm útil
COL_GAP   = 0.4 * cm
COL_L     = PAGE_W * 0.52
COL_R     = PAGE_W - COL_L - COL_GAP

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL      = colors.HexColor('#1a3566')
VERDE     = colors.HexColor('#059669')
CYAN      = colors.HexColor('#0891b2')
AMBAR     = colors.HexColor('#b45309')
ROJO      = colors.HexColor('#dc2626')
GRIS_L    = colors.HexColor('#f3f4f6')
GRIS_M    = colors.HexColor('#d1d5db')
BLANCO    = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']

_sty_counter = [0]
def _sty(**kw):
    _sty_counter[0] += 1
    name = 'sty_%d' % _sty_counter[0]
    defaults = dict(name=name, parent=_base, fontSize=7.5, leading=10)
    defaults.update(kw)
    return ParagraphStyle(**defaults)

ST_SECCION = _sty(fontSize=8.5, fontName='Helvetica-Bold', textColor=AZUL,
                  spaceBefore=4, spaceAfter=2)
ST_NORMAL  = _sty(fontSize=7.5, leading=10)
ST_HDR     = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO,
                  alignment=TA_CENTER)
ST_CELL    = _sty(fontSize=7, leading=9)
ST_CELL_R  = _sty(fontSize=7, leading=9, alignment=TA_RIGHT)
ST_CELL_C  = _sty(fontSize=7, leading=9, alignment=TA_CENTER)
ST_KPI_LBL = _sty(fontSize=6.5, textColor=BLANCO, alignment=TA_CENTER)
ST_KPI_VAL = _sty(fontSize=10, fontName='Helvetica-Bold', textColor=BLANCO,
                  alignment=TA_CENTER)

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v)).replace(',', '.')
    except: return 'Gs. 0'

def num(v):
    try:    return str(int(v))
    except: return '0'

def P(txt, sty):
    return Paragraph(str(txt), sty)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── KPI strip ─────────────────────────────────────────────────────────────────
def kpi_strip(items):
    n   = len(items)
    cw  = [PAGE_W / n] * n
    r1  = [P(it[0], ST_KPI_LBL) for it in items]
    r2  = [P(it[1], ST_KPI_VAL) for it in items]
    t   = Table([r1, r2], colWidths=cw)
    ts  = TableStyle(CELL_PAD + [
        ('GRID', (0,0), (-1,-1), 0.5, BLANCO),
        ('TOPPADDING',    (0,0), (-1,0), 3),
        ('BOTTOMPADDING', (0,1), (-1,1), 5),
    ])
    for i, it in enumerate(items):
        ts.add('BACKGROUND', (i,0), (i,1), it[2])
    t.setStyle(ts)
    return t

# ── Tabla de datos ────────────────────────────────────────────────────────────
def data_table(headers, rows, col_w_cm, aligns=None, max_rows=None):
    if aligns is None:
        aligns = ['L'] * len(headers)
    if max_rows is not None:
        rows = rows[:max_rows]
    _st = {'L': ST_CELL, 'R': ST_CELL_R, 'C': ST_CELL_C}
    data = [[P(h, ST_HDR) for h in headers]]
    for row in rows:
        data.append([P(str(c), _st.get(aligns[j], ST_CELL))
                     for j, c in enumerate(row)])
    cw = [w * cm for w in col_w_cm]
    t  = Table(data, colWidths=cw, repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t

# ── Tabla NC compacta ─────────────────────────────────────────────────────────
def nc_mini(nc, col_w_cm):
    items = [
        ('Total NC',    num(nc.get('TotalNC',0))),
        ('Pendientes',  num(nc.get('Pendientes',0))),
        ('Recibidas',   num(nc.get('Recibidas',0))),
        ('Rechazadas',  num(nc.get('Rechazadas',0))),
        ('Morosas',     num(nc.get('Morosas',0))),
        ('Monto Total', gs(nc.get('MontoTotal',0))),
    ]
    data = [[P('<b>'+r[0]+'</b>', ST_CELL), P(r[1], ST_CELL_R)] for r in items]
    cw   = [col_w_cm * 0.55 * cm, col_w_cm * 0.45 * cm]
    t    = Table(data, colWidths=cw)
    t.setStyle(TableStyle(CELL_PAD + [
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t

# ── Wrapper de columna ────────────────────────────────────────────────────────
def col_wrap(items, width):
    """Envuelve varios flowables en una tabla de 1 columna para layout lateral."""
    data = [[it] for it in items]
    t    = Table(data, colWidths=[width])
    t.setStyle(TableStyle([
        ('TOPPADDING',    (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING',   (0,0), (-1,-1), 0),
        ('RIGHTPADDING',  (0,0), (-1,-1), 0),
        ('VALIGN',        (0,0), (-1,-1), 'TOP'),
    ]))
    return t

# ── Header / Footer en canvas ─────────────────────────────────────────────────
class _Canvas:
    def __init__(self, tienda, periodo):
        self.tienda  = tienda
        self.periodo = periodo

    def __call__(self, canvas, doc):
        canvas.saveState()
        w, h = PAGE

        # Header
        canvas.setFillColor(AZUL)
        canvas.rect(0, h - 1.6*cm, w, 1.6*cm, fill=True, stroke=False)
        canvas.setFillColor(BLANCO)
        canvas.setFont('Helvetica-Bold', 11)
        canvas.drawString(MARG_H, h - 1.0*cm, 'Reporte de Gerencia — Módulo Compras')
        canvas.setFont('Helvetica', 8)
        canvas.drawRightString(w - MARG_H, h - 0.9*cm, self.tienda)
        canvas.setFont('Helvetica', 7)
        canvas.drawRightString(w - MARG_H, h - 1.35*cm, self.periodo)

        # Footer
        canvas.setFillColor(GRIS_L)
        canvas.rect(0, 0, w, 0.9*cm, fill=True, stroke=False)
        canvas.setFillColor(colors.HexColor('#6b7280'))
        canvas.setFont('Helvetica', 7)
        canvas.drawString(MARG_H, 0.3*cm,
                          'Generado: ' + datetime.now().strftime('%d/%m/%Y %H:%M'))
        canvas.drawCentredString(w/2, 0.3*cm, 'Sistema de Ventas — Confidencial')
        canvas.drawRightString(w - MARG_H, 0.3*cm, 'Pagina 1 de 1')

        canvas.restoreState()


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencia Compras'
    )

    kpis     = data.get('KPIs', {})
    nc       = data.get('NotasCredito', {})
    mensual  = data.get('ComprasMensuales', [])
    estados  = data.get('OrdenesPorEstado', [])
    top_prov = data.get('TopProveedores', [])
    oc_fuera = data.get('OCsFueraDePlazo', [])
    tienda   = data.get('NombreTienda', '')
    periodo  = ('Periodo: ' + data.get('FechaInicio','') +
                ' al ' + data.get('FechaFin',''))

    cb    = _Canvas(tienda, periodo)
    story = []

    # ── Banda KPIs ───────────────────────────────────────────
    story.append(kpi_strip([
        ('Total Compras',  num(kpis.get('TotalCompras',0)),     AZUL),
        ('Monto Total',    gs(kpis.get('MontoTotalCompras',0)), VERDE),
        ('OC Pendientes',  num(kpis.get('OCPendientes',0)),     CYAN),
        ('OC Fuera Plazo', num(kpis.get('OCFueraPlazo',0)),     ROJO),
        ('NC — Monto',     gs(kpis.get('MontoTotalNC',0)),      AMBAR),
    ]))
    story.append(Spacer(1, 6))

    # ── Fila 1: Compras x Mes  |  OC Estado + NC ────────────
    col_l_w_cm = COL_L / cm
    col_r_w_cm = COL_R / cm

    lft = []
    lft.append(P('Evolucion de Compras por Mes', ST_SECCION))
    if mensual:
        last_col_w = col_l_w_cm - 8.0
        lft.append(data_table(
            ['Anio', 'Mes', 'Cant.', 'Monto (Gs.)'],
            [[r['Anio'], r['MesNombre'], num(r['Cantidad']), gs(r['Monto'])]
             for r in mensual],
            [2.0, 3.0, 2.5, max(last_col_w, 2.5)],
            ['C','L','C','R'], max_rows=12
        ))
    else:
        lft.append(P('Sin datos en el periodo.', ST_NORMAL))

    rgt = []
    rgt.append(P('OC por Estado', ST_SECCION))
    if estados:
        w1 = col_r_w_cm * 0.44
        w2 = col_r_w_cm * 0.20
        w3 = col_r_w_cm * 0.36
        rgt.append(data_table(
            ['Estado', 'Cant.', 'Monto (Gs.)'],
            [[r['Estado'], num(r['Cantidad']), gs(r['MontoTotal'])]
             for r in estados],
            [w1, w2, w3], ['L','C','R']
        ))
    else:
        rgt.append(P('Sin ordenes en el periodo.', ST_NORMAL))

    rgt.append(Spacer(1, 5))
    rgt.append(P('Resumen Notas de Credito', ST_SECCION))
    rgt.append(nc_mini(nc, col_r_w_cm))

    story.append(Table(
        [[col_wrap(lft, COL_L), col_wrap(rgt, COL_R)]],
        colWidths=[COL_L + COL_GAP/2, COL_R + COL_GAP/2]
    ))
    story.append(Spacer(1, 5))

    # ── Fila 2: Top Proveedores  |  OC Fuera de Plazo ───────
    lft2 = []
    lft2.append(P('Top Proveedores', ST_SECCION))
    if top_prov:
        w_num  = 0.8
        w_prov = col_l_w_cm - 8.8
        lft2.append(data_table(
            ['#', 'Proveedor', 'Compras', 'Monto (Gs.)', 'NC'],
            [[str(i+1), r['Proveedor'], num(r['TotalCompras']),
              gs(r['MontoTotal']), num(r.get('CantidadNC', 0))]
             for i, r in enumerate(top_prov)],
            [w_num, max(w_prov, 2.0), 2.5, 3.5, 1.5],
            ['C','L','C','R','C'], max_rows=8
        ))
    else:
        lft2.append(P('Sin datos de proveedores.', ST_NORMAL))

    rgt2 = []
    rgt2.append(P('OC Fuera de Plazo', ST_SECCION))
    if oc_fuera:
        w1 = col_r_w_cm * 0.24
        w2 = col_r_w_cm * 0.36
        w3 = col_r_w_cm * 0.22
        w4 = col_r_w_cm * 0.18
        rgt2.append(data_table(
            ['N. Orden', 'Proveedor', 'Tope', 'Dias'],
            [[r['NumeroOrden'], r['Proveedor'],
              r['FechaTopeEntrega'], str(r['DiasVencida'])]
             for r in oc_fuera],
            [w1, w2, w3, w4], ['C','L','C','C'], max_rows=8
        ))
    else:
        rgt2.append(P('Sin OC fuera de plazo.', ST_NORMAL))

    story.append(Table(
        [[col_wrap(lft2, COL_L), col_wrap(rgt2, COL_R)]],
        colWidths=[COL_L + COL_GAP/2, COL_R + COL_GAP/2]
    ))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_compras.py <json> <pdf>',
              file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
