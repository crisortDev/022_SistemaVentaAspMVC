# ============================================================
#  generar_reporte_compras.py
#  Reporte de Compras para Alta Gerencia — Portrait A4
#  Uso: python generar_reporte_compras.py <json> <pdf>
#  Dependencias: reportlab  (pip install reportlab)
# ============================================================

import sys
import json
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = A4
MARG_H   = 1.5 * cm
MARG_TOP = 2.6 * cm
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H      # ≈ 18 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
CYAN    = colors.HexColor('#0891b2')
AMBAR   = colors.HexColor('#b45309')
ROJO    = colors.HexColor('#dc2626')
MORADO  = colors.HexColor('#7c3aed')
TEAL    = colors.HexColor('#0f766e')
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=8, leading=10)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=AZUL,
                spaceBefore=8, spaceAfter=3)
ST_NRM   = _sty(fontSize=8, leading=11)
ST_HDR   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7.5, leading=10)
ST_CELL_R= _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_KPI_L = _sty(fontSize=7,   textColor=BLANCO, alignment=TA_CENTER)
ST_KPI_V = _sty(fontSize=11,  fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v)).replace(',', '.')
    except: return 'Gs. 0'

def num(v):
    try:    return '{:,.0f}'.format(float(v)).replace(',', '.')
    except: return '0'

def pct(v):
    try:    return '{:.1f}%'.format(float(v))
    except: return '—'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 4),
    ('RIGHTPADDING',  (0,0), (-1,-1), 4),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── KPI strip ────────────────────────────────────────────────────────────────
def kpi_strip(items):
    """items = [(label, valor, color), ...]"""
    n  = len(items)
    cw = [PAGE_W / n] * n
    t  = Table(
        [[P(it[0], ST_KPI_L) for it in items],
         [P(it[1], ST_KPI_V) for it in items]],
        colWidths=cw
    )
    ts = TableStyle(CELL_PAD + [
        ('GRID',          (0,0), (-1,-1), 0.5, BLANCO),
        ('TOPPADDING',    (0,0), (-1,0),  4),
        ('BOTTOMPADDING', (0,1), (-1,1),  5),
    ])
    for i, it in enumerate(items):
        ts.add('BACKGROUND', (i,0), (i,1), it[2])
    t.setStyle(ts)
    return t

# ── Tabla de datos genérica ───────────────────────────────────────────────────
def data_table(headers, rows, col_w_cm, aligns=None, max_rows=None):
    if aligns is None:
        aligns = ['L'] * len(headers)
    if max_rows:
        rows = rows[:max_rows]
    _st = {'L': ST_CELL, 'R': ST_CELL_R, 'C': ST_CELL_C}
    data = [[P(h, ST_HDR) for h in headers]]
    for row in rows:
        data.append([P(str(c) if c is not None else '—', _st.get(aligns[j], ST_CELL))
                     for j, c in enumerate(row)])
    cw = [w * cm for w in col_w_cm]
    t  = Table(data, colWidths=cw, repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t

# ── Header / Footer en canvas ─────────────────────────────────────────────────
class _Canvas:
    def __init__(self, tienda, periodo):
        self.tienda  = tienda
        self.periodo = periodo
        self._pg     = [0]

    def __call__(self, canvas, doc):
        self._pg[0] += 1
        canvas.saveState()
        w, h = PAGE

        # Barra azul superior (membrete)
        canvas.setFillColor(AZUL)
        canvas.rect(0, h - 2.0*cm, w, 2.0*cm, fill=True, stroke=False)
        canvas.setFillColor(BLANCO)
        canvas.setFont('Helvetica-Bold', 12)
        canvas.drawString(MARG_H, h - 1.1*cm, 'Reporte de Compras — Alta Gerencia')
        canvas.setFont('Helvetica', 8)
        canvas.drawRightString(w - MARG_H, h - 1.0*cm, self.tienda)
        canvas.setFont('Helvetica', 7.5)
        canvas.drawRightString(w - MARG_H, h - 1.55*cm, self.periodo)

        # Footer
        canvas.setFillColor(GRIS_L)
        canvas.rect(0, 0, w, 1.0*cm, fill=True, stroke=False)
        canvas.setFillColor(colors.HexColor('#6b7280'))
        canvas.setFont('Helvetica', 7)
        canvas.drawString(MARG_H, 0.35*cm,
                          'Generado: ' + datetime.now().strftime('%d/%m/%Y %H:%M'))
        canvas.drawCentredString(w/2, 0.35*cm, 'Sistema de Ventas — Confidencial')
        canvas.drawRightString(w - MARG_H, 0.35*cm, 'Pag. %d' % self._pg[0])

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

    kpis      = data.get('KPIs', {})
    mensual   = data.get('ComprasMensuales', [])
    top_prov  = data.get('TopProveedores', [])
    top_prod  = data.get('TopProductos', [])
    estados   = data.get('OrdenesPorEstado', [])
    por_tienda= data.get('ComprasPorTienda', [])
    relacion  = data.get('RelacionCV', {})
    nc        = data.get('NotasCredito', {})
    tienda    = data.get('NombreTienda', '')
    periodo   = 'Periodo: {} al {}'.format(
        data.get('FechaInicio', ''), data.get('FechaFin', ''))

    cb    = _Canvas(tienda, periodo)
    story = []

    # ── KPI strip fila 1 ─────────────────────────────────────────────────
    story.append(kpi_strip([
        ('Total Compras (Gs.)',    gs(kpis.get('MontoTotalCompras', 0)),  AZUL),
        ('Ordenes Emitidas',       num(kpis.get('TotalOC', 0)),           VERDE),
        ('Compras Recepcionadas',  num(kpis.get('Recepcionadas', 0)),     CYAN),
        ('OC Pendientes',          num(kpis.get('OCPendientes', 0)),      AMBAR),
    ]))
    story.append(Spacer(1, 4))
    story.append(kpi_strip([
        ('Gasto Promedio / Compra', gs(kpis.get('GastoPromedio', 0)),    TEAL),
        ('Proveedores Activos',     num(kpis.get('ProveedoresActivos',0)),MORADO),
        ('Productos Comprados',     num(kpis.get('ProductosComprados',0)),GRIS_OS),
        ('OC Anuladas/Rechazadas',  num(kpis.get('Anuladas', 0)),        ROJO),
    ]))
    story.append(Spacer(1, 10))

    # ── Compras por mes ───────────────────────────────────────────────────
    story.append(P('Compras por Mes', ST_SEC))
    if mensual:
        story.append(data_table(
            ['Año', 'Mes', 'Cantidad', 'Monto Total (Gs.)'],
            [[r['Anio'], r['MesNombre'], num(r['Cantidad']), gs(r['Monto'])]
             for r in mensual],
            [2.5, 5.5, 3.5, 6.5],
            ['C', 'L', 'C', 'R']
        ))
    else:
        story.append(P('Sin datos en el periodo.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Top 10 proveedores ────────────────────────────────────────────────
    story.append(P('Top 10 Proveedores con Mayor Volumen de Compras', ST_SEC))
    if top_prov:
        story.append(data_table(
            ['#', 'Proveedor', 'Compras', 'Monto Total (Gs.)', 'NC'],
            [[r['Ranking'], r['Proveedor'][:35], num(r['TotalCompras']),
              gs(r['MontoTotal']), num(r.get('CantidadNC', 0))]
             for r in top_prov],
            [0.8, 8.2, 2.5, 5.0, 1.5],
            ['C', 'L', 'C', 'R', 'C'], max_rows=10
        ))
    else:
        story.append(P('Sin datos de proveedores.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Top 10 productos más comprados ────────────────────────────────────
    story.append(P('Top 10 Productos mas Comprados', ST_SEC))
    if top_prod:
        story.append(data_table(
            ['#', 'Codigo', 'Producto', 'Categoria', 'Cantidad', 'Monto (Gs.)'],
            [[r['Ranking'], r['Codigo'], r['Producto'][:28], r['Categoria'][:18],
              num(r['CantidadTotal']), gs(r['MontoTotal'])]
             for r in top_prod],
            [0.8, 2.0, 5.5, 3.2, 2.5, 4.0],
            ['C', 'C', 'L', 'L', 'R', 'R'], max_rows=10
        ))
    else:
        story.append(P('Sin datos de productos.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Estado de OC ─────────────────────────────────────────────────────
    story.append(P('Estado de las Ordenes de Compra', ST_SEC))
    if estados:
        story.append(data_table(
            ['Estado', 'Cantidad', 'Monto Estimado (Gs.)'],
            [[r['Estado'], num(r['Cantidad']), gs(r['MontoTotal'])]
             for r in estados],
            [7.0, 4.0, 7.0],
            ['L', 'C', 'R']
        ))
    else:
        story.append(P('Sin ordenes de compra.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Compras por tienda ────────────────────────────────────────────────
    story.append(P('Compras por Sucursal', ST_SEC))
    if por_tienda:
        story.append(data_table(
            ['Sucursal', 'Compras', 'Monto Total (Gs.)', '% del Total'],
            [[r['Tienda'], num(r['CantidadCompras']), gs(r['MontoTotal']),
              pct(r['PorcentajePct'])]
             for r in por_tienda],
            [6.5, 3.0, 6.0, 2.5],
            ['L', 'C', 'R', 'C']
        ))
    else:
        story.append(P('Sin datos por sucursal.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Relación Compras vs Ventas ────────────────────────────────────────
    story.append(P('Relacion Compras vs Ventas', ST_SEC))
    comp  = float(relacion.get('TotalCompras', 0) or 0)
    vtas  = float(relacion.get('TotalVentas',  0) or 0)
    rel   = '{:.1f}%'.format(comp / vtas * 100) if vtas > 0 else '—'
    story.append(data_table(
        ['Concepto', 'Total (Gs.)', 'Relacion Compras/Ventas'],
        [
            ['Compras', gs(comp), rel],
            ['Ventas',  gs(vtas), ''],
        ],
        [5.0, 7.0, 6.0],
        ['L', 'R', 'C']
    ))
    story.append(Spacer(1, 10))

    # ── Resumen NC ────────────────────────────────────────────────────────
    story.append(P('Resumen de Notas de Credito (Compras)', ST_SEC))
    story.append(data_table(
        ['Indicador', 'Valor'],
        [
            ['Total NC',           num(nc.get('TotalNC', 0))],
            ['Pendientes',         num(nc.get('Pendientes', 0))],
            ['Recibidas',          num(nc.get('Recibidas', 0))],
            ['Rechazadas',         num(nc.get('Rechazadas', 0))],
            ['Morosas (+30 dias)', num(nc.get('Morosas', 0))],
            ['Monto Total NC',     gs(nc.get('MontoTotal', 0))],
        ],
        [10.0, 8.0],
        ['L', 'R']
    ))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_compras.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
