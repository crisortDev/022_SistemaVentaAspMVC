# ============================================================
#  generar_reporte_ventas_gerencia.py
#  Reporte de Ventas para Alta Gerencia — Portrait A4
#  Uso: python generar_reporte_ventas_gerencia.py <json> <pdf>
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
PAGE     = A4                         # 21 × 29.7 cm
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

ST_TITULO = _sty(fontSize=13, fontName='Helvetica-Bold', textColor=AZUL,
                 alignment=TA_CENTER, spaceAfter=2)
ST_SUBTIT = _sty(fontSize=8.5, textColor=colors.HexColor('#6b7280'),
                 alignment=TA_CENTER, spaceAfter=6)
ST_SEC    = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=AZUL,
                 spaceBefore=8, spaceAfter=3)
ST_NRM    = _sty(fontSize=8, leading=11)
ST_HDR    = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO,
                 alignment=TA_CENTER)
ST_CELL   = _sty(fontSize=7.5, leading=10)
ST_CELL_R = _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_CELL_C = _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)
ST_KPI_L  = _sty(fontSize=7,   textColor=BLANCO, alignment=TA_CENTER)
ST_KPI_V  = _sty(fontSize=11,  fontName='Helvetica-Bold', textColor=BLANCO,
                 alignment=TA_CENTER)
ST_KPI_S  = _sty(fontSize=6.5, textColor=BLANCO, alignment=TA_CENTER)

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v)).replace(',', '.')
    except: return 'Gs. 0'

def num(v):
    try:    return '{:,.0f}'.format(float(v)).replace(',', '.')
    except: return '0'

def pct(v):
    try:
        f = float(v)
        return ('+' if f > 0 else '') + '{:.1f}%'.format(f)
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

# ── KPI strip (3 columnas de 2 filas) ────────────────────────────────────────
def kpi_strip(items):
    """items = [(label, valor, color, sublabel_opt), ...]"""
    n  = len(items)
    cw = [PAGE_W / n] * n
    rows = [
        [P(it[0], ST_KPI_L) for it in items],
        [P(it[1], ST_KPI_V) for it in items],
    ]
    if any(len(it) > 3 for it in items):
        rows.append([P(it[3] if len(it) > 3 else '', ST_KPI_S) for it in items])

    t  = Table(rows, colWidths=cw)
    ts = TableStyle(CELL_PAD + [
        ('GRID',          (0,0), (-1,-1), 0.5, BLANCO),
        ('TOPPADDING',    (0,0), (-1,0),  4),
        ('BOTTOMPADDING', (0,-1),(-1,-1), 5),
    ])
    for i, it in enumerate(items):
        ts.add('BACKGROUND', (i,0), (i,-1), it[2])
    t.setStyle(ts)
    return t

# ── Tabla de datos genérica (ancho PAGE_W, repite encabezado) ────────────────
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

# ── Línea separadora ──────────────────────────────────────────────────────────
def hr():
    return HRFlowable(width='100%', thickness=0.5, color=GRIS_M, spaceAfter=4)

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

        # Barra azul superior
        canvas.setFillColor(AZUL)
        canvas.rect(0, h - 2.0*cm, w, 2.0*cm, fill=True, stroke=False)
        canvas.setFillColor(BLANCO)
        canvas.setFont('Helvetica-Bold', 12)
        canvas.drawString(MARG_H, h - 1.1*cm, 'Reporte de Ventas — Alta Gerencia')
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
        canvas.drawRightString(w - MARG_H, 0.35*cm,
                               'Pag. %d' % self._pg[0])

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
        title='Reporte Ventas Gerencia'
    )

    kpis       = data.get('KPIs', {})
    por_mes    = data.get('VentasPorMes', [])
    top_prod   = data.get('TopProductos', [])
    utilidad   = data.get('ProductosUtilidad', [])
    por_tienda = data.get('VentasPorTienda', [])
    vendedores = data.get('VentasPorVendedor', [])
    clientes   = data.get('TopClientes', [])
    inventario = data.get('Inventario', [])
    tienda     = data.get('NombreTienda', '')
    periodo    = 'Periodo: {} al {}'.format(
        data.get('FechaInicio', ''), data.get('FechaFin', ''))

    cb    = _Canvas(tienda, periodo)
    story = []

    # ── Banda KPIs (2 filas de 3) ────────────────────────────────────────
    var_m = kpis.get('VariacionMontoPct')
    var_lbl = ('vs. per. ant.: ' + pct(var_m)) if var_m is not None else ''

    story.append(kpi_strip([
        ('Ventas Efectivas',   num(kpis.get('VentasEfectivas', 0)),  AZUL),
        ('Monto Neto',         gs(kpis.get('MontoNeto', 0)),         VERDE,  var_lbl),
        ('Ticket Promedio',    gs(kpis.get('TicketPromedio', 0)),     CYAN),
    ]))
    story.append(Spacer(1, 4))
    story.append(kpi_strip([
        ('Notas de Credito',   num(kpis.get('TotalNC', 0)) + '  (' + gs(kpis.get('MontoNC', 0)) + ')', ROJO),
        ('Clientes Atendidos', num(kpis.get('CantidadClientes', 0)), MORADO),
        ('Unidades Vendidas',  num(kpis.get('TotalUnidades', 0)),    AMBAR),
    ]))
    story.append(Spacer(1, 10))

    # ── Comparativo vs. período anterior ─────────────────────────────────
    var_v = kpis.get('VariacionVentasPct')
    fi_ant = kpis.get('FechaIniAnt', data.get('FechaInicio', ''))  # fallback
    ff_ant = kpis.get('FechaFinAnt', data.get('FechaFin', ''))

    story.append(P('Comparativo vs. Periodo Anterior', ST_SEC))
    story.append(data_table(
        ['Indicador', 'Periodo Actual', 'Periodo Anterior', 'Variacion'],
        [
            ['Ventas (cant.)', num(kpis.get('VentasEfectivas',0)),
             num(kpis.get('VentasAnterior',0)), pct(var_v)],
            ['Monto Neto',     gs(kpis.get('MontoNeto',0)),
             gs(kpis.get('MontoAnterior',0)),   pct(var_m)],
        ],
        [6.0, 4.0, 4.0, 4.0],
        ['L','R','R','C']
    ))
    story.append(Spacer(1, 10))

    # ── Evolución por mes ─────────────────────────────────────────────────
    story.append(P('Evolucion de Ventas por Mes', ST_SEC))
    if por_mes:
        story.append(data_table(
            ['Año', 'Mes', 'Cantidad Ventas', 'Monto Total (Gs.)'],
            [[r['Anio'], r['MesNombre'], num(r['Cantidad']), gs(r['MontoTotal'])]
             for r in por_mes],
            [2.5, 5.5, 4.5, 5.5],
            ['C','L','C','R']
        ))
    else:
        story.append(P('Sin datos en el periodo.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Ventas por sucursal ───────────────────────────────────────────────
    story.append(P('Ventas por Sucursal', ST_SEC))
    if por_tienda:
        story.append(data_table(
            ['Sucursal', 'Cantidad Ventas', 'Monto Total (Gs.)', '% del Total'],
            [[r['Tienda'], num(r['Cantidad']), gs(r['MontoTotal']),
              '{:.1f}%'.format(float(r['PorcentajePct'] or 0))]
             for r in por_tienda],
            [6.5, 3.5, 5.0, 3.0],
            ['L','C','R','C']
        ))
    else:
        story.append(P('Sin datos de sucursales.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Ventas por vendedor ───────────────────────────────────────────────
    story.append(P('Ventas por Vendedor', ST_SEC))
    if vendedores:
        story.append(data_table(
            ['Vendedor', 'Sucursal', 'Cant.', 'Monto Total (Gs.)', 'Ticket Prom. (Gs.)'],
            [[r['Vendedor'], r['Tienda'], r['Cantidad'],
              gs(r['MontoTotal']), gs(r['TicketPromedio'])]
             for r in vendedores],
            [5.0, 4.0, 2.0, 4.0, 3.0],
            ['L','L','C','R','R'], max_rows=20
        ))
    else:
        story.append(P('Sin datos de vendedores.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Top 10 productos por unidades ─────────────────────────────────────
    story.append(P('Top 10 Productos mas Vendidos (por unidades)', ST_SEC))
    if top_prod:
        story.append(data_table(
            ['#', 'Codigo', 'Producto', 'Categoria', 'Unidades', 'Monto (Gs.)'],
            [[r['Ranking'], r['Codigo'], r['Producto'][:32], r['Categoria'][:20],
              num(r['UnidadesVendidas']), gs(r['MontoTotal'])]
             for r in top_prod],
            [0.8, 2.0, 6.0, 3.5, 2.3, 3.4],
            ['C','C','L','L','R','R'], max_rows=10
        ))
    else:
        story.append(P('Sin datos de productos.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Top 10 productos por utilidad ─────────────────────────────────────
    story.append(P('Top 10 Productos por Utilidad Bruta', ST_SEC))
    if utilidad:
        story.append(data_table(
            ['#', 'Producto', 'Venta (Gs.)', 'Costo (Gs.)', 'Utilidad (Gs.)', 'Margen'],
            [[r['Ranking'], r['Producto'][:32],
              gs(r['VentaTotal']), gs(r['CostoTotal']),
              gs(r['Utilidad']), '{:.1f}%'.format(float(r['MargenPct'] or 0))]
             for r in utilidad],
            [0.8, 6.0, 3.2, 3.2, 3.2, 1.6],
            ['C','L','R','R','R','C'], max_rows=10
        ))
    else:
        story.append(P('Sin datos de utilidad.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Top 10 clientes ───────────────────────────────────────────────────
    story.append(P('Top 10 Clientes por Monto Comprado', ST_SEC))
    if clientes:
        story.append(data_table(
            ['#', 'Cliente', 'Facturas', 'Monto Total (Gs.)', 'Ticket Prom. (Gs.)'],
            [[r['Ranking'], r['Cliente'][:30], r['CantidadFacturas'],
              gs(r['MontoTotal']), gs(r['TicketPromedio'])]
             for r in clientes],
            [0.8, 6.5, 2.5, 5.0, 3.2],
            ['C','L','C','R','R'], max_rows=10
        ))
    else:
        story.append(P('Sin datos de clientes.', ST_NRM))
    story.append(Spacer(1, 10))

    # ── Notas de crédito ──────────────────────────────────────────────────
    story.append(P('Resumen de Notas de Credito (Ventas)', ST_SEC))
    story.append(data_table(
        ['Indicador', 'Valor'],
        [
            ['Cantidad de NC',  num(kpis.get('TotalNC', 0))],
            ['Monto total NC',  gs(kpis.get('MontoNC', 0))],
        ],
        [10.0, 8.0],
        ['L','R']
    ))
    story.append(Spacer(1, 10))

    # ── Relación con inventario ───────────────────────────────────────────
    if inventario:
        story.append(P('Relacion con Inventario — Estado de Stock por Sucursal', ST_SEC))
        story.append(data_table(
            ['Sucursal', 'Agotados', 'Bajo Stock (≤5)', 'Total Prod.', 'Inv. Aprobados', 'Dif. Prom.'],
            [[r['Tienda'],
              num(r['ProductosAgotados']),
              num(r['ProductosBajoStock']),
              num(r['TotalProductos']),
              num(r['InventariosAprobados']),
              '{:.2f}%'.format(float(r['PctDiferenciaProm'] or 0))]
             for r in inventario],
            [4.5, 2.3, 2.8, 2.5, 3.0, 2.9],
            ['L','C','C','C','C','C']
        ))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_ventas_gerencia.py <json> <pdf>',
              file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
