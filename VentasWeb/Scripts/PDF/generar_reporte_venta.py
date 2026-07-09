# ============================================================
#  generar_reporte_venta.py
#  Reporte Operativo de Ventas — Portrait A4
#  Uso: python generar_reporte_venta.py <json> <pdf>
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
PAGE     = A4
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 18 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
VERDE   = colors.HexColor('#059669')
ROJO    = colors.HexColor('#dc2626')
AMBAR   = colors.HexColor('#b45309')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
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
                spaceBefore=8, spaceAfter=4)
ST_NRM   = _sty(fontSize=8, leading=11)
ST_HDR   = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7.5, leading=10)
ST_CELL_R= _sty(fontSize=7.5, leading=10, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=7.5, leading=10, alignment=TA_CENTER)

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 4),
    ('RIGHTPADDING',  (0,0), (-1,-1), 4),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(str(v).replace(',', ''))).replace(',', '.')
    except: return 'Gs. 0'

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

def estado_badge(est):
    """Retorna el texto del estado (se colorea via TableStyle si es necesario)."""
    return str(est) if est else 'Efectiva'


# ── Tabla principal ───────────────────────────────────────────────────────────
def ventas_table(ventas):
    """
    Columnas (18 cm total):
    Fecha  | Nro Doc  | Tipo | Estado | Cliente       | Empleado  | Unid | Total
    2.0    | 3.5      | 1.8  | 1.8    | 3.5           | 2.5       | 1.0  | 1.9
    """
    col_w = [2.0, 3.5, 1.8, 1.8, 3.5, 2.5, 1.0, 1.9]
    hdrs  = ['Fecha', 'Nro Documento', 'Tipo', 'Estado',
             'Cliente', 'Empleado', 'Unid.', 'Total (Gs.)']
    aligns = ['C', 'L', 'C', 'C', 'L', 'L', 'C', 'R']

    _st = {'L': ST_CELL, 'R': ST_CELL_R, 'C': ST_CELL_C}

    data = [[P(h, ST_HDR) for h in hdrs]]
    estado_rows = []   # filas donde el estado es Anulada
    for i, v in enumerate(ventas):
        est = (v.get('Estado') or 'Efectiva').strip()
        if est.lower() in ('anulada', 'anulado', 'cancelada', 'cancelado'):
            estado_rows.append(i + 1)   # +1 por la fila de encabezado
        row = [
            P(v.get('FechaVenta', ''),               _st['C']),
            P(v.get('NumeroDocumento', ''),           _st['L']),
            P(v.get('TipoDocumento', ''),             _st['C']),
            P(est,                                    _st['C']),
            P((v.get('Cliente') or 'Consumidor Final')[:28], _st['L']),
            P((v.get('NombreEmpleado') or '')[:22],   _st['L']),
            P(v.get('CantidadUnidadesVendidas', '0'), _st['C']),
            P(gs(v.get('TotalVenta', '0')),           _st['R']),
        ]
        data.append(row)

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AZUL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    # Filas anuladas en rojo tenue
    for r in estado_rows:
        ts.add('TEXTCOLOR', (0,r), (-1,r), ROJO)
    t.setStyle(ts)
    return t


# ── Totalizador ───────────────────────────────────────────────────────────────
def totales_table(ventas):
    total = 0
    efectivas = 0
    anuladas  = 0
    for v in ventas:
        est = (v.get('Estado') or '').strip().lower()
        if est in ('anulada', 'anulado', 'cancelada', 'cancelado'):
            anuladas += 1
        else:
            efectivas += 1
            try:
                total += float(str(v.get('TotalVenta', '0')).replace(',', ''))
            except:
                pass

    data = [
        [P('Ventas Efectivas',  ST_CELL), P(str(efectivas), ST_CELL_R)],
        [P('Ventas Anuladas',   ST_CELL), P(str(anuladas),  ST_CELL_R)],
        [P('Total del Período', _sty(fontSize=8, fontName='Helvetica-Bold')),
         P(gs(total), _sty(fontSize=8, fontName='Helvetica-Bold', alignment=TA_RIGHT))],
    ]
    t = Table(data, colWidths=[PAGE_W - 4*cm, 4*cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',  (0,0), (-1,1),  GRIS_L),
        ('BACKGROUND',  (0,2), (-1,2),  AZUL),
        ('TEXTCOLOR',   (0,2), (-1,2),  BLANCO),
        ('GRID',        (0,0), (-1,-1), 0.3, GRIS_M),
        ('ALIGN',       (0,0), (0,-1),  'RIGHT'),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda        = data.get('NombreTienda',  '')
    ruc           = data.get('RucTienda',     '')
    empresa       = data.get('NombreEmpresa', tienda)
    fi_str        = data.get('FechaInicio',   '')
    ff_str        = data.get('FechaFin',      '')
    estado_filtro = data.get('EstadoFiltro',  '') or ''
    periodo       = '{} — {}'.format(fi_str, ff_str) if fi_str else ''
    partes_filtro = []
    if tienda:        partes_filtro.append('Sucursal: ' + tienda)
    if estado_filtro: partes_filtro.append('Estado: ' + estado_filtro)
    filtros       = '   '.join(partes_filtro)
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')
    ventas        = data.get('Ventas', [])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte de Ventas'
    )

    cb    = _Canvas('Reporte de Ventas', empresa, periodo, filtros,
                    nombre_usuario, reporte_id, logo_path)
    story = []

    # ── Encabezado del período ────────────────────────────────────────────
    story.append(P('Detalle de Ventas' + (' — ' + periodo if periodo else ''), ST_SEC))
    story.append(Spacer(1, 4))

    # ── Tabla de ventas ───────────────────────────────────────────────────
    if ventas:
        story.append(ventas_table(ventas))
    else:
        story.append(P('Sin ventas registradas en el período.', ST_NRM))

    story.append(Spacer(1, 10))

    # ── Totales ───────────────────────────────────────────────────────────
    story.append(P('Resumen del Período', ST_SEC))
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
