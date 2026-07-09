# ============================================================
#  generar_reporte_bajas.py
#  Reporte de Bajas de Productos — Portrait A4
#  Uso: python generar_reporte_bajas.py <json> <pdf>
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
GRIS_OS = colors.HexColor('#374151')
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
ST_WARN  = _sty(fontSize=6, leading=8, textColor=colors.HexColor('#92400e'))
ST_ERR   = _sty(fontSize=6, leading=8, textColor=colors.HexColor('#991b1b'))
ST_OK    = _sty(fontSize=6, leading=8, textColor=colors.HexColor('#065f46'))

CELL_PAD = [
    ('TOPPADDING',    (0,0), (-1,-1), 2),
    ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ('LEFTPADDING',   (0,0), (-1,-1), 3),
    ('RIGHTPADDING',  (0,0), (-1,-1), 3),
    ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
]

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)


# ── Columnas ─────────────────────────────────────────────────────────────────
#
# Sin Tienda — 8 cols (18.0 cm):
#   Nro  | Fecha | Código | Producto | Cant. | Motivo | Estado | Registró
#   1.8  | 2.0   | 1.5    | 3.8      | 1.0   | 2.7    | 2.2    | 3.0
#
# Con Tienda — 9 cols (18.0 cm):
#   Tienda | Nro | Fecha | Código | Producto | Cant. | Motivo | Estado | Registró
#   2.5    | 1.5 | 1.8   | 1.5    | 3.0      | 0.8   | 2.5    | 2.2    | 2.2
#

COL_W_UNA   = [1.8, 2.0, 1.5, 3.8, 1.0, 2.7, 2.2, 3.0]
HDRS_UNA    = ['Nro', 'Fecha', 'Código', 'Producto', 'Cant.', 'Motivo', 'Estado', 'Registró']

COL_W_TODAS = [2.5, 1.5, 1.8, 1.5, 3.0, 0.8, 2.5, 2.2, 2.2]
HDRS_TODAS  = ['Tienda', 'Nro', 'Fecha', 'Código', 'Producto', 'Cant.', 'Motivo', 'Estado', 'Registró']


def _estado_cell(baja):
    """Celda de Estado con detalle adicional según el estado."""
    estado = baja.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'
    lines  = [P(estado, ST_CELL_C)]

    if estado == 'Aprobada':
        if baja.get('FechaAprobacion'):
            lines.append(P(baja['FechaAprobacion'], ST_SMALL))
        if baja.get('UsuarioAprueba'):
            lines.append(P(baja['UsuarioAprueba'], ST_OK))
    elif estado == 'Rechazada':
        if baja.get('MotivoRechazo'):
            lines.append(P(baja['MotivoRechazo'], ST_ERR))
    elif estado == 'Pendiente':
        pass  # sin detalle extra

    # Wrap lines in a mini-table to stack them
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


def bajas_table(bajas, mostrar_tienda):
    col_w = COL_W_TODAS if mostrar_tienda else COL_W_UNA
    hdrs  = HDRS_TODAS  if mostrar_tienda else HDRS_UNA

    data   = [[P(h, ST_HDR) for h in hdrs]]
    styles = list(CELL_PAD) + [
        ('BACKGROUND',  (0,0), (-1,0),  AZUL),
        ('GRID',        (0,0), (-1,-1), 0.3, GRIS_M),
    ]

    for idx, b in enumerate(bajas):
        row_num = idx + 1  # data row index (1 = first data row)
        estado  = b.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'

        fila_core = [
            P(b.get('Numero', '')         or '', ST_CELL_C),
            P(b.get('FechaMovimiento', '') or '', ST_CELL_C),
            P(b.get('CodigoProducto', '')  or '', ST_CELL_C),
            P(b.get('NombreProducto', '')  or '', ST_CELL),
            P(str(b.get('Cantidad', 0)),         ST_CELL_C),
            P(b.get('MotivoBaja', '')      or '', ST_CELL),
            _estado_cell(b),
            P(b.get('UsuarioRegistro', '') or '', ST_CELL),
        ]

        if mostrar_tienda:
            tienda_cell = [
                P(b.get('NombreTienda', '') or '', ST_CELL),
                P(b.get('RucTienda',    '') or '', ST_SMALL),
            ]
            row = [tienda_cell] + fila_core
        else:
            row = fila_core

        data.append(row)

        # Row background by EstadoAprobacion
        if estado == 'Pendiente':
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num), AMBAR_L))
        elif estado == 'Rechazada':
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num), ROJO_L))
        elif estado == 'Aprobada':
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num),
                           BLANCO if row_num % 2 == 1 else GRIS_L))
        else:
            styles.append(('BACKGROUND', (0, row_num), (-1, row_num),
                           BLANCO if row_num % 2 == 1 else GRIS_L))

    t = Table(data, colWidths=[w * cm for w in col_w], repeatRows=1)
    t.setStyle(TableStyle(styles))
    return t


def totales_table(bajas, mostrar_tienda):
    col_w    = COL_W_TODAS if mostrar_tienda else COL_W_UNA
    n_total  = len(bajas)
    n_pend   = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Pendiente')
    n_apro   = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Aprobada')
    n_rech   = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Rechazada')
    tot_cant = sum(int(b.get('Cantidad', 0) or 0) for b in bajas)

    label = 'TOTAL: {} baja(s)   Pendiente: {}   Aprobada: {}   Rechazada: {}'.format(
        n_total, n_pend, n_apro, n_rech)

    ncols = len(col_w)
    if ncols == 9:
        # Con tienda: label ocupa cols 0-5, cant en col 6, vacío en 7-8
        row = [P(label, ST_TOT)] + [P('', ST_CELL)] * 4 + \
              [P(str(tot_cant), ST_TOT_C)] + [P('', ST_CELL)] * 3
        # SPAN cols 0-4 (5 cols)
        span_end = (4, 0)
    else:
        # Sin tienda: label ocupa cols 0-3, cant en col 4, vacío en 5-7
        row = [P(label, ST_TOT)] + [P('', ST_CELL)] * 3 + \
              [P(str(tot_cant), ST_TOT_C)] + [P('', ST_CELL)] * 3
        span_end = (3, 0)

    t = Table([row], colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('TEXTCOLOR',  (0,0), (-1,0), BLANCO),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
        ('SPAN',       (0,0), span_end),
    ]))
    return t


def leyenda():
    data = [
        [P('Pendiente', _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#92400e'))),
         P('Aprobada (fondo normal)',     _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#065f46'))),
         P('Rechazada', _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#991b1b'))),
        ]
    ]
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
    id_tienda     = int(data.get('IdTienda',  0) or 0)
    fi            = data.get('FechaInicio',   '—')
    ff            = data.get('FechaFin',      '—')
    estado_filtro = data.get('EstadoFiltro',  '') or ''
    reporte_id    = data.get('ReporteId',     '')
    nombre_usuario= data.get('NombreUsuario', '')
    logo_path     = data.get('LogoPath',      '')
    bajas         = data.get('Bajas', [])

    mostrar_tienda = (id_tienda == 0)
    periodo  = '{} — {}'.format(fi, ff) if fi != '—' else ''
    filtros  = ('Estado: ' + estado_filtro) if estado_filtro else ''

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte de Bajas de Productos'
    )

    cb    = _Canvas('Reporte de Bajas de Productos', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    if bajas:
        story.append(bajas_table(bajas, mostrar_tienda))
        story.append(Spacer(1, 0))
        story.append(totales_table(bajas, mostrar_tienda))
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
        print('Uso: python generar_reporte_bajas.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
