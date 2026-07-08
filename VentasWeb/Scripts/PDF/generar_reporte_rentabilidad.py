# ============================================================
#  generar_reporte_rentabilidad.py
#  Reporte de Rentabilidad por Producto (CPP) — Landscape A4
#  Uso: python generar_reporte_rentabilidad.py <json> <pdf>
#  Dependencias: reportlab
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
PAGE     = landscape(A4)          # 297 × 210 mm en apaisado
MARG_H   = 1.5 * cm
MARG_TOP = 2.6 * cm
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H  # ≈ 26.7 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
AMBAR   = colors.HexColor('#b45309')
ROJO    = colors.HexColor('#dc2626')
GRIS_OS = colors.HexColor('#374151')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
VERDE_L = colors.HexColor('#d1fae5')
AMBAR_L = colors.HexColor('#fef3c7')
ROJO_L  = colors.HexColor('#fee2e2')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=AZUL,
                spaceBefore=6, spaceAfter=3)
ST_NRM   = _sty(fontSize=8, leading=11)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=6.5, leading=9)
ST_CELL_R= _sty(fontSize=6.5, leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=6.5, leading=9, alignment=TA_CENTER)
ST_TOT   = _sty(fontSize=7, fontName='Helvetica-Bold', leading=10)
ST_TOT_R = _sty(fontSize=7, fontName='Helvetica-Bold', leading=10, alignment=TA_RIGHT)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v)).replace(',', '.')
    except: return 'Gs. 0'

def pct(v):
    try:    return '{:.1f}%'.format(float(v))
    except: return '0.0%'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

# ── Header/Footer canvas ──────────────────────────────────────────────────────
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
        canvas.setFont('Helvetica-Bold', 11)
        canvas.drawString(MARG_H, h - 0.9*cm, 'Reporte de Rentabilidad por Producto — CPP')

        canvas.setFont('Helvetica', 7.5)
        canvas.drawString(MARG_H, h - 1.55*cm,
                          'Metodo: Costo Promedio Ponderado (Inventario Permanente Movil)')
        canvas.drawRightString(w - MARG_H, h - 0.9*cm,  self.tienda)
        canvas.drawRightString(w - MARG_H, h - 1.55*cm, self.periodo)

        # Footer
        canvas.setFillColor(GRIS_L)
        canvas.rect(0, 0, w, 1.0*cm, fill=True, stroke=False)
        canvas.setFillColor(GRIS_T)
        canvas.setFont('Helvetica', 7)
        canvas.drawString(MARG_H, 0.35*cm,
                          'Generado: ' + datetime.now().strftime('%d/%m/%Y %H:%M'))
        canvas.drawCentredString(w/2, 0.35*cm, 'Sistema de Ventas — Confidencial')
        canvas.drawRightString(w - MARG_H, 0.35*cm, 'Pag. %d' % self._pg[0])

        canvas.restoreState()


# ── Tabla principal ───────────────────────────────────────────────────────────
# Columnas (26.7 cm total):
# Cod  | Producto | Categ | Stock | CPP  | P.Vta | Uds  | Ingresos | Costo | Utilidad | Margen | Val.Inv
# 1.8  | 4.0      | 2.5   | 1.2   | 2.3  | 2.3   | 1.2  | 2.5      | 2.5   | 2.5      | 1.5    | 2.4
COL_W = [1.8, 4.0, 2.5, 1.2, 2.3, 2.3, 1.2, 2.5, 2.5, 2.5, 1.5, 2.4]
HDRS  = ['Código', 'Producto', 'Categoría', 'Stock',
         'CPP (Gs.)', 'P. Venta', 'Uds.', 'Ingresos',
         'Costo CPP', 'Utilidad', 'Margen %', 'Val. Inv.']
ALIGNS= ['C', 'L', 'L', 'C', 'R', 'R', 'C', 'R', 'R', 'R', 'C', 'R']

def rentabilidad_table(datos):
    _st = {'L': ST_CELL, 'R': ST_CELL_R, 'C': ST_CELL_C}

    data  = [[P(h, ST_HDR) for h in HDRS]]
    verde_rows = []
    ambar_rows = []
    rojo_rows  = []

    for i, r in enumerate(datos):
        margen = float(r.get('MargenBrutoPct', 0) or 0)
        ri = i + 1  # +1 por encabezado
        if margen >= 20:
            verde_rows.append(ri)
        elif margen >= 10:
            ambar_rows.append(ri)
        elif margen < 0:
            rojo_rows.append(ri)

        prod = (r.get('Producto') or '')[:30]
        cat  = (r.get('Categoria') or '—')[:20]

        row = [
            P(r.get('Codigo', ''),             _st['C']),
            P(prod,                            _st['L']),
            P(cat,                             _st['L']),
            P(str(r.get('StockActual', 0)),    _st['C']),
            P(gs(r.get('CostoPromedio', 0)),   _st['R']),
            P(gs(r.get('PrecioVentaVigente',0)),_st['R']),
            P(str(r.get('UnidadesVendidas',0)),_st['C']),
            P(gs(r.get('IngresosTotales', 0)), _st['R']),
            P(gs(r.get('CostoTotalVentas',0)), _st['R']),
            P(gs(r.get('UtilidadBruta',  0)),  _st['R']),
            P(pct(margen),                     _st['C']),
            P(gs(r.get('ValorInventarioCPP',0)),_st['R']),
        ]
        data.append(row)

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for r in verde_rows:
        ts.add('BACKGROUND', (0,r), (-1,r), VERDE_L)
    for r in ambar_rows:
        ts.add('BACKGROUND', (0,r), (-1,r), AMBAR_L)
    for r in rojo_rows:
        ts.add('BACKGROUND', (0,r), (-1,r), ROJO_L)
        ts.add('TEXTCOLOR',  (9,r), (10,r), ROJO)
    t.setStyle(ts)
    return t


# ── Fila de totales ───────────────────────────────────────────────────────────
def totales_table(datos):
    tot_ing  = sum(float(r.get('IngresosTotales', 0) or 0) for r in datos)
    tot_cost = sum(float(r.get('CostoTotalVentas',0) or 0) for r in datos)
    tot_util = sum(float(r.get('UtilidadBruta',  0) or 0) for r in datos)
    tot_inv  = sum(float(r.get('ValorInventarioCPP',0) or 0) for r in datos)
    marg_glb = (tot_util / tot_ing * 100) if tot_ing > 0 else 0

    # Mismos anchos que la tabla principal (12 columnas)
    row = [
        P('TOTALES', ST_TOT),
        P('', ST_CELL),
        P('', ST_CELL),
        P('', ST_CELL),
        P('', ST_CELL),
        P('', ST_CELL),
        P('', ST_CELL),
        P(gs(tot_ing),  ST_TOT_R),
        P(gs(tot_cost), ST_TOT_R),
        P(gs(tot_util), ST_TOT_R),
        P(pct(marg_glb), _sty(fontSize=7, fontName='Helvetica-Bold', leading=10, alignment=TA_CENTER)),
        P(gs(tot_inv),  ST_TOT_R),
    ]
    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('TEXTCOLOR',  (0,0), (-1,0), BLANCO),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
    ]))
    return t


# ── Leyenda de colores ────────────────────────────────────────────────────────
def leyenda():
    """Una fila de 4 celdas con fondo coloreado — sin tablas anidadas."""
    cw = PAGE_W / 4
    data = [[
        P('Margen >= 20%  — alta',       _sty(fontSize=7, leading=10, textColor=VERDE)),
        P('Margen 10–19% — media',       _sty(fontSize=7, leading=10, textColor=AMBAR)),
        P('Margen  0–9%  — baja',        _sty(fontSize=7, leading=10, textColor=GRIS_OS)),
        P('Margen < 0%   — bajo costo',  _sty(fontSize=7, leading=10, textColor=ROJO)),
    ]]
    t = Table(data, colWidths=[cw, cw, cw, cw])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (0,0), VERDE_L),
        ('BACKGROUND',    (1,0), (1,0), AMBAR_L),
        ('BACKGROUND',    (2,0), (2,0), GRIS_L),
        ('BACKGROUND',    (3,0), (3,0), ROJO_L),
        ('GRID',          (0,0), (-1,-1), 0.3, GRIS_M),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('TOPPADDING',    (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING',   (0,0), (-1,-1), 4),
        ('RIGHTPADDING',  (0,0), (-1,-1), 4),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda  = data.get('NombreTienda', '')
    periodo = 'Periodo: {} al {}'.format(
        data.get('FechaInicio',''), data.get('FechaFin',''))
    datos   = data.get('Datos', [])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Rentabilidad por Producto CPP'
    )

    cb    = _Canvas(tienda, periodo)
    story = []

    # Leyenda
    story.append(leyenda())
    story.append(Spacer(1, 6))

    # Tabla de datos
    if datos:
        story.append(rentabilidad_table(datos))
        story.append(Spacer(1, 0))
        story.append(totales_table(datos))
    else:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_NRM))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_rentabilidad.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
