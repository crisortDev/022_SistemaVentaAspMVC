# ============================================================
#  generar_reporte_traslados.py
#  Reporte de Traslados de Productos — Portrait A4
#  Uso: python generar_reporte_traslados.py <json> <pdf>
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
PAGE     = A4                      # 210 × 297 mm portrait
MARG_BOT = 1.5 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # 18.0 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL    = colors.HexColor('#1a3566')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
VERDE_L = colors.HexColor('#d1fae5')
AMBAR_L = colors.HexColor('#fef3c7')
ROJO_L  = colors.HexColor('#fee2e2')
AZUL_L  = colors.HexColor('#dbeafe')
BLANCO  = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_NRM   = _sty(fontSize=8, leading=11)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO,
                alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7, leading=9)
ST_CELL_R= _sty(fontSize=7, leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=7, leading=9, alignment=TA_CENTER)
ST_SMALL = _sty(fontSize=5.5, leading=7.5, textColor=GRIS_T)
ST_TOT   = _sty(fontSize=7.5, fontName='Helvetica-Bold', leading=10)
ST_TOT_C = _sty(fontSize=7.5, fontName='Helvetica-Bold', leading=10, alignment=TA_CENTER)
ST_OK    = _sty(fontSize=6, leading=8, textColor=colors.HexColor('#065f46'))
ST_ERR   = _sty(fontSize=6, leading=8, textColor=colors.HexColor('#991b1b'))

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)


# ── Columnas — 9 cols fijos (18.0 cm) ────────────────────────────────────────
#   Nro  | Fecha | Código | Producto | Cant. | Origen | Destino | Estado | Registró
#   1.8  | 2.0   | 1.5    | 3.2      | 1.0   | 2.5    | 2.5     | 1.5    | 2.0
#   Sum = 18.0 cm ✓

COL_W = [1.8, 2.0, 1.5, 3.2, 1.0, 2.5, 2.5, 1.5, 2.0]
HDRS  = ['Nro', 'Fecha', 'Código', 'Producto', 'Cant.', 'Origen', 'Destino', 'Estado', 'Registró']


def _estado_cell(tr):
    """Celda Estado con detalle adicional."""
    estado = tr.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'
    lines  = [P(estado, ST_CELL_C)]

    if estado == 'Aprobada':
        if tr.get('FechaAprobacion'):
            lines.append(P(tr['FechaAprobacion'], ST_SMALL))
        if tr.get('UsuarioAprueba'):
            lines.append(P(tr['UsuarioAprueba'], ST_OK))
    elif estado == 'Rechazada':
        if tr.get('MotivoRechazo'):
            lines.append(P(tr['MotivoRechazo'], ST_ERR))

    if len(lines) == 1:
        return lines[0]

    inner = Table([[l] for l in lines], colWidths=[None])
    inner.setStyle(TableStyle([
        ('TOPPADDING',    (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING',   (0,0), (-1,-1), 0),
        ('RIGHTPADDING',  (0,0), (-1,-1), 0),
    ]))
    return inner


def traslados_table(traslados):
    data   = [[P(h, ST_HDR) for h in HDRS]]
    styles = list(CELL_PAD) + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]

    for idx, t in enumerate(traslados):
        row_num = idx + 1
        estado  = t.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'

        row = [
            P(t.get('Numero', '')        or '', ST_CELL_C),
            P(t.get('FechaTraslado', '') or '', ST_CELL_C),
            P(t.get('CodigoProducto', '') or '', ST_CELL_C),
            P(t.get('NombreProducto', '') or '', ST_CELL),
            P(str(t.get('Cantidad', 0)),         ST_CELL_C),
            P(t.get('TiendaOrigen', '')  or '', ST_CELL),
            P(t.get('TiendaDestino', '') or '', ST_CELL),
            _estado_cell(t),
            P(t.get('Usuario', '')       or '', ST_CELL),
        ]
        data.append(row)

        if estado == 'Pendiente':
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num), AMBAR_L))
        elif estado == 'Rechazada':
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num), ROJO_L))
        else:
            bg = BLANCO if row_num % 2 == 1 else GRIS_L
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num), bg))

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    t.setStyle(TableStyle(styles))
    return t


def totales_table(traslados):
    n_total = len(traslados)
    n_pend  = sum(1 for t in traslados if (t.get('EstadoAprobacion') or '') == 'Pendiente')
    n_apro  = sum(1 for t in traslados if (t.get('EstadoAprobacion') or '') == 'Aprobada')
    n_rech  = sum(1 for t in traslados if (t.get('EstadoAprobacion') or '') == 'Rechazada')
    tot_cant= sum(int(t.get('Cantidad', 0) or 0) for t in traslados)

    label = 'TOTAL: {} traslado(s)   Pendiente: {}   Aprobada: {}   Rechazada: {}'.format(
        n_total, n_pend, n_apro, n_rech)

    # Span cols 0-3 (Nro, Fecha, Código, Producto), Cant en col 4, vacío en 5-8
    row = [P(label, ST_TOT)] + [P('', ST_CELL)] * 3 + \
          [P(str(tot_cant), ST_TOT_C)] + [P('', ST_CELL)] * 4

    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('TEXTCOLOR',  (0,0), (-1,0), BLANCO),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
        ('SPAN',       (0,0), (3,0)),
    ]))
    return t


def leyenda():
    data = [[
        P('Pendiente',              _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#92400e'))),
        P('Aprobada (fondo normal)',_sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#065f46'))),
        P('Rechazada',             _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#991b1b'))),
    ]]
    col_w = [4.5, 4.5, 4.5]
    t = Table(data, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle([
        ('TOPPADDING',    (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING',   (0,0), (-1,-1), 5),
        ('RIGHTPADDING',  (0,0), (-1,-1), 3),
        ('BACKGROUND', (0,0), (0,0), AMBAR_L),
        ('BACKGROUND', (1,0), (1,0), GRIS_L),
        ('BACKGROUND', (2,0), (2,0), ROJO_L),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda        = data.get('NombreTienda',  'Todas las sucursales')
    empresa       = data.get('NombreEmpresa', tienda)
    fi            = data.get('FechaInicio',   '—')
    ff            = data.get('FechaFin',      '—')
    estado_filtro = data.get('EstadoFiltro',  '') or ''
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')
    traslados     = data.get('Traslados', [])

    periodo = '{} — {}'.format(fi, ff) if fi != '—' else ''
    filtros = ('Estado: ' + estado_filtro) if estado_filtro else ''

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte de Traslados de Productos'
    )

    cb    = _Canvas('Reporte de Traslados de Productos', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    if traslados:
        story.append(traslados_table(traslados))
        story.append(Spacer(1, 0))
        story.append(totales_table(traslados))
        story.append(Spacer(1, 0.3 * cm))
        story.append(leyenda())
    else:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_NRM))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_reporte_traslados.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
