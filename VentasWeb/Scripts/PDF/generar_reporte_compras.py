# ============================================================
#  generar_reporte_compras.py
#  Uso: python generar_reporte_compras.py <ruta_json> <ruta_pdf>
#
#  Dependencias: reportlab
#  Instalar:     pip install reportlab
# ============================================================

import sys
import json
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT

# ── Colores corporativos ──────────────────────────────────────────────────────
AZUL_CORP   = colors.HexColor('#1a3566')
AZUL_CLARO  = colors.HexColor('#2563eb')
VERDE       = colors.HexColor('#059669')
CYAN        = colors.HexColor('#0891b2')
AMBAR       = colors.HexColor('#b45309')
ROJO        = colors.HexColor('#991b1b')
GRIS_CLARO  = colors.HexColor('#f3f4f6')
GRIS_MEDIO  = colors.HexColor('#d1d5db')
BLANCO      = colors.white

# ── Helpers ───────────────────────────────────────────────────────────────────
def fmt_gs(valor):
    """Formatea número como guaraníes (sin decimales, separador de miles)."""
    try:
        return 'Gs. {:,.0f}'.format(float(valor)).replace(',', '.')
    except Exception:
        return 'Gs. 0'

def fmt_int(valor):
    try:
        return str(int(valor))
    except Exception:
        return '0'

# ── Estilos ───────────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()

st_titulo = ParagraphStyle(
    'titulo', parent=styles['Normal'],
    fontSize=16, textColor=AZUL_CORP, fontName='Helvetica-Bold',
    alignment=TA_CENTER, spaceAfter=2
)
st_subtitulo = ParagraphStyle(
    'subtitulo', parent=styles['Normal'],
    fontSize=10, textColor=colors.HexColor('#6b7280'),
    alignment=TA_CENTER, spaceAfter=8
)
st_seccion = ParagraphStyle(
    'seccion', parent=styles['Normal'],
    fontSize=11, textColor=AZUL_CORP, fontName='Helvetica-Bold',
    spaceBefore=12, spaceAfter=4
)
st_normal = ParagraphStyle(
    'normal_custom', parent=styles['Normal'],
    fontSize=8.5, leading=12
)
st_cell_header = ParagraphStyle(
    'cell_header', parent=styles['Normal'],
    fontSize=8, textColor=BLANCO, fontName='Helvetica-Bold',
    alignment=TA_CENTER
)
st_cell = ParagraphStyle(
    'cell', parent=styles['Normal'],
    fontSize=8, leading=11
)
st_cell_r = ParagraphStyle(
    'cell_r', parent=styles['Normal'],
    fontSize=8, leading=11, alignment=TA_RIGHT
)
st_cell_c = ParagraphStyle(
    'cell_c', parent=styles['Normal'],
    fontSize=8, leading=11, alignment=TA_CENTER
)
st_footer = ParagraphStyle(
    'footer', parent=styles['Normal'],
    fontSize=7, textColor=colors.HexColor('#9ca3af'),
    alignment=TA_CENTER
)

# ── KPI Box ───────────────────────────────────────────────────────────────────
def kpi_table(items):
    """items: lista de (etiqueta, valor, color_bg)"""
    n = len(items)
    col_w = (A4[0] - 4*cm) / n

    header_data = [[Paragraph('<b>' + it[0] + '</b>', ParagraphStyle(
        'kpi_lbl', parent=styles['Normal'], fontSize=7,
        textColor=BLANCO, alignment=TA_CENTER)) for it in items]]

    value_data  = [[Paragraph(it[1], ParagraphStyle(
        'kpi_val', parent=styles['Normal'], fontSize=13, fontName='Helvetica-Bold',
        textColor=BLANCO, alignment=TA_CENTER)) for it in items]]

    combined = [header_data[0], value_data[0]]
    t = Table(combined, colWidths=[col_w]*n)

    ts = TableStyle([
        ('GRID',        (0,0), (-1,-1), 0.5, BLANCO),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [AZUL_CORP, AZUL_CORP]),
        ('TOPPADDING',  (0,0), (-1,-1), 4),
        ('BOTTOMPADDING',(0,0),(-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING',(0,0), (-1,-1), 4),
        ('VALIGN',      (0,0), (-1,-1), 'MIDDLE'),
    ])
    # Colores individuales por columna
    for i, it in enumerate(items):
        bg = it[2] if len(it) > 2 else AZUL_CORP
        ts.add('BACKGROUND', (i, 0), (i, 1), bg)

    t.setStyle(ts)
    return t

# ── Tabla genérica ────────────────────────────────────────────────────────────
def make_table(headers, rows, col_widths, aligns=None):
    """
    headers: list of str
    rows: list of list of str
    col_widths: list of float (cm)
    aligns: list of 'L'|'C'|'R' per column (optional)
    """
    if aligns is None:
        aligns = ['L'] * len(headers)

    header_row = [Paragraph(h, st_cell_header) for h in headers]
    data = [header_row]

    for row in rows:
        dr = []
        for j, cell in enumerate(row):
            al = aligns[j] if j < len(aligns) else 'L'
            s = st_cell_r if al == 'R' else (st_cell_c if al == 'C' else st_cell)
            dr.append(Paragraph(str(cell), s))
        data.append(dr)

    col_w_pt = [w * cm for w in col_widths]
    t = Table(data, colWidths=col_w_pt, repeatRows=1)
    ts = TableStyle([
        ('BACKGROUND',  (0, 0), (-1, 0), AZUL_CORP),
        ('TEXTCOLOR',   (0, 0), (-1, 0), BLANCO),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [BLANCO, GRIS_CLARO]),
        ('GRID',        (0, 0), (-1, -1), 0.3, GRIS_MEDIO),
        ('TOPPADDING',  (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING',(0, 0),(-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING',(0, 0), (-1, -1), 4),
        ('FONTSIZE',    (0, 0), (-1, -1), 8),
        ('VALIGN',      (0, 0), (-1, -1), 'MIDDLE'),
    ])
    t.setStyle(ts)
    return t

# ── Header / Footer callbacks ─────────────────────────────────────────────────
class ReporteCanvas:
    def __init__(self, nombre_tienda, periodo):
        self.nombre_tienda = nombre_tienda
        self.periodo       = periodo

    def __call__(self, canvas, doc):
        canvas.saveState()
        w, h = A4

        # ── Header ──────────────────────────────────────────
        canvas.setFillColor(AZUL_CORP)
        canvas.rect(0, h - 1.8*cm, w, 1.8*cm, fill=True, stroke=False)

        canvas.setFillColor(BLANCO)
        canvas.setFont('Helvetica-Bold', 12)
        canvas.drawString(1.5*cm, h - 1.1*cm, 'Reporte de Gerencia — Módulo Compras')

        canvas.setFont('Helvetica', 8)
        canvas.drawRightString(w - 1.5*cm, h - 1.1*cm, self.nombre_tienda)
        canvas.setFont('Helvetica', 7)
        canvas.drawRightString(w - 1.5*cm, h - 1.5*cm, self.periodo)

        # ── Footer ──────────────────────────────────────────
        canvas.setFillColor(GRIS_CLARO)
        canvas.rect(0, 0, w, 1*cm, fill=True, stroke=False)

        canvas.setFillColor(colors.HexColor('#6b7280'))
        canvas.setFont('Helvetica', 7)
        canvas.drawString(1.5*cm, 0.35*cm,
                          'Generado el ' + datetime.now().strftime('%d/%m/%Y %H:%M'))
        canvas.drawCentredString(w / 2, 0.35*cm, 'Sistema de Ventas — Confidencial')
        canvas.drawRightString(w - 1.5*cm, 0.35*cm,
                               'Página %d' % doc.page)

        canvas.restoreState()


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=2*cm, rightMargin=2*cm,
        topMargin=2.5*cm, bottomMargin=1.8*cm,
        title='Reporte Gerencia Compras'
    )

    kpis       = data.get('KPIs', {})
    nc         = data.get('NotasCredito', {})
    mensual    = data.get('ComprasMensuales', [])
    por_estado = data.get('OrdenesPorEstado', [])
    top_prov   = data.get('TopProveedores', [])
    oc_fuera   = data.get('OCsFueraDePlazo', [])
    nombre_tienda = data.get('NombreTienda', '')
    fecha_ini  = data.get('FechaInicio', '')
    fecha_fin  = data.get('FechaFin', '')
    periodo    = 'Período: ' + fecha_ini + ' al ' + fecha_fin

    cb = ReporteCanvas(nombre_tienda, periodo)
    story = []

    # ── Título ───────────────────────────────────────────────
    story.append(Paragraph('Reporte de Gerencia — Compras', st_titulo))
    story.append(Paragraph(nombre_tienda + '  |  ' + periodo, st_subtitulo))
    story.append(HRFlowable(width='100%', thickness=1, color=AZUL_CLARO, spaceAfter=10))

    # ── KPIs ─────────────────────────────────────────────────
    story.append(Paragraph('Indicadores Clave (KPI)', st_seccion))
    kpi_items = [
        ('Total Compras',    fmt_int(kpis.get('TotalCompras',0)),      AZUL_CORP),
        ('Monto Total',      fmt_gs(kpis.get('MontoTotalCompras',0)),  VERDE),
        ('OC Pendientes',    fmt_int(kpis.get('OCPendientes',0)),       CYAN),
        ('OC Fuera Plazo',   fmt_int(kpis.get('OCFueraPlazo',0)),       ROJO),
        ('NC — Monto',       fmt_gs(kpis.get('MontoTotalNC',0)),        AMBAR),
    ]
    story.append(kpi_table(kpi_items))
    story.append(Spacer(1, 12))

    # ── Compras por mes ──────────────────────────────────────
    story.append(Paragraph('Evolución de Compras por Mes', st_seccion))
    if mensual:
        headers = ['Año', 'Mes', 'Cantidad', 'Monto (Gs.)']
        rows    = [[r['Anio'], r['MesNombre'], fmt_int(r['Cantidad']), fmt_gs(r['Monto'])]
                   for r in mensual]
        story.append(make_table(headers, rows, [2.5, 3.5, 3, 5.5], ['C','C','C','R']))
    else:
        story.append(Paragraph('Sin datos en el período seleccionado.', st_normal))
    story.append(Spacer(1, 10))

    # ── OC por estado ────────────────────────────────────────
    story.append(Paragraph('Órdenes de Compra por Estado', st_seccion))
    if por_estado:
        headers = ['Estado', 'Cantidad', 'Monto Total (Gs.)']
        rows    = [[r['Estado'], fmt_int(r['Cantidad']), fmt_gs(r['MontoTotal'])]
                   for r in por_estado]
        story.append(make_table(headers, rows, [6, 3.5, 5], ['L','C','R']))
    else:
        story.append(Paragraph('Sin órdenes de compra en el período.', st_normal))
    story.append(Spacer(1, 10))

    # ── Top proveedores ──────────────────────────────────────
    story.append(Paragraph('Top Proveedores por Monto Comprado', st_seccion))
    if top_prov:
        headers = ['#', 'Proveedor', 'Compras', 'Monto Total (Gs.)']
        rows    = [[str(i+1), r['Proveedor'], fmt_int(r['TotalCompras']), fmt_gs(r['MontoTotal'])]
                   for i, r in enumerate(top_prov)]
        story.append(make_table(headers, rows, [1, 8, 2.5, 4], ['C','L','C','R']))
    else:
        story.append(Paragraph('Sin datos de proveedores en el período.', st_normal))
    story.append(Spacer(1, 10))

    # ── Resumen NC ───────────────────────────────────────────
    story.append(Paragraph('Resumen de Notas de Crédito', st_seccion))
    nc_items = [
        ['Total NC',   fmt_int(nc.get('TotalNC',0))],
        ['Pendientes', fmt_int(nc.get('Pendientes',0))],
        ['Recibidas',  fmt_int(nc.get('Recibidas',0))],
        ['Rechazadas', fmt_int(nc.get('Rechazadas',0))],
        ['Morosas',    fmt_int(nc.get('Morosas',0))],
        ['Monto Total',fmt_gs(nc.get('MontoTotal',0))],
    ]
    nc_table_data = [[Paragraph('<b>' + r[0] + '</b>', st_cell), Paragraph(r[1], st_cell_r)]
                     for r in nc_items]
    nc_t = Table(nc_table_data, colWidths=[6*cm, 5*cm])
    nc_t.setStyle(TableStyle([
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [BLANCO, GRIS_CLARO]),
        ('GRID',    (0,0), (-1,-1), 0.3, GRIS_MEDIO),
        ('TOPPADDING',    (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(nc_t)
    story.append(Spacer(1, 10))

    # ── OCs fuera de plazo ───────────────────────────────────
    story.append(Paragraph('Órdenes de Compra Fuera de Plazo', st_seccion))
    if oc_fuera:
        headers = ['Nro. Orden', 'Proveedor', 'Tienda', 'Fecha Tope', 'Monto Est. (Gs.)', 'Estado', 'Días']
        rows    = [[r['NumeroOrden'], r['Proveedor'], r['Tienda'],
                    r['FechaTopeEntrega'], fmt_gs(r['MontoEstimado']),
                    r['Estado'], str(r['DiasVencida'])]
                   for r in oc_fuera]
        t = make_table(headers, rows, [2.5, 4.5, 3, 2.5, 3.5, 2.5, 1.5],
                       ['C','L','L','C','R','C','C'])
        story.append(KeepTogether(t))
    else:
        story.append(Paragraph(
            'No hay órdenes de compra fuera de plazo en el período seleccionado.',
            st_normal))

    # ── Build ────────────────────────────────────────────────
    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_compras.py <ruta_json> <ruta_pdf>',
              file=sys.stderr)
        sys.exit(1)

    json_path = sys.argv[1]
    pdf_path  = sys.argv[2]

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    build_pdf(data, pdf_path)
    print('PDF generado: ' + pdf_path)
