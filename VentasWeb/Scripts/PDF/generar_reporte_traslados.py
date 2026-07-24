# ============================================================
#  generar_reporte_traslados.py
#  Reporte Gerencial de Traslados entre Tiendas — Portrait A4
#  Flujo multi-producto 4 pasos (Script 230)
#  Estados: Solicitado | Aprobado | Rechazado | Despachado | Completado
#  Uso: python generar_reporte_traslados.py <json> <pdf>
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
PAGE_W   = PAGE[0] - 2 * MARG_H   # ≈ 18.0 cm útil

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL     = colors.HexColor('#1a3566')
CIAN     = colors.HexColor('#17a2b8')
VERDE    = colors.HexColor('#059669')
AMBAR    = colors.HexColor('#b45309')
ROJO     = colors.HexColor('#dc2626')
AZUL_C   = colors.HexColor('#1d4ed8')
INFO     = colors.HexColor('#0891b2')
GRIS_OS  = colors.HexColor('#374151')
GRIS_L   = colors.HexColor('#f3f4f6')
GRIS_M   = colors.HexColor('#d1d5db')
GRIS_T   = colors.HexColor('#6b7280')
VERDE_L  = colors.HexColor('#d1fae5')
AMBAR_L  = colors.HexColor('#fef3c7')
ROJO_L   = colors.HexColor('#fee2e2')
AZUL_L   = colors.HexColor('#dbeafe')
CIAN_L   = colors.HexColor('#d1ecf1')
INFO_L   = colors.HexColor('#cffafe')
BLANCO   = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='s%d' % _cnt[0], parent=_base, fontSize=7, leading=9)
    d.update(kw)
    return ParagraphStyle(**d)

ST_SEC   = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=CIAN, spaceBefore=6, spaceAfter=3)
ST_HDR   = _sty(fontSize=6.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_CELL  = _sty(fontSize=7,   leading=9)
ST_CELL_R= _sty(fontSize=7,   leading=9, alignment=TA_RIGHT)
ST_CELL_C= _sty(fontSize=7,   leading=9, alignment=TA_CENTER)
ST_SMALL = _sty(fontSize=5.5, leading=7.5, textColor=GRIS_T)
ST_LBL   = _sty(fontSize=7.5, fontName='Helvetica-Bold')
ST_VAL   = _sty(fontSize=7.5, alignment=TA_RIGHT)
ST_VAL_C = _sty(fontSize=7.5, alignment=TA_CENTER)
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

def pct(v):
    try:    return '{:.1f}%'.format(float(v or 0))
    except: return '0.0%'


# ════════════════════════════════════════════════════════════════════════════
#  1. RESUMEN EJECUTIVO
# ════════════════════════════════════════════════════════════════════════════
def kpi_table(traslados):
    n_traslados = len(traslados)
    total_unid  = sum(int(t.get('TotalUnidades', 0) or 0) for t in traslados)
    sucursales  = set()
    for t in traslados:
        if t.get('TiendaOrigen'):  sucursales.add(t['TiendaOrigen'])
        if t.get('TiendaDestino'): sucursales.add(t['TiendaDestino'])

    st_h = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
    st_hr= _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)

    rows = [
        [P('Indicador', st_h), P('Valor', st_hr)],
        [P('Traslados registrados',   ST_LBL), P(str(n_traslados),     ST_VAL)],
        [P('Unidades movilizadas',    ST_LBL), P(str(total_unid),      ST_VAL)],
        [P('Sucursales involucradas', ST_LBL), P(str(len(sucursales)), ST_VAL)],
    ]

    ancho = PAGE_W / cm
    t = Table(rows, colWidths=[(ancho - 3.0) * cm, 3.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  CIAN),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  2. ESTADO DE TRASLADOS (flujo 4 pasos)
# ════════════════════════════════════════════════════════════════════════════
def estado_table(traslados):
    total = len(traslados)
    conteo = {'Solicitado': 0, 'Aprobado': 0, 'Despachado': 0, 'Completado': 0, 'Rechazado': 0}
    for t in traslados:
        est = (t.get('EstadoAprobacion') or 'Solicitado')
        if est in conteo:
            conteo[est] += 1

    rows = [[P(h, ST_HDR) for h in ['Estado', 'Cantidad', '%']]]

    def fila(label, n, bg, tc):
        p = (n / total * 100) if total > 0 else 0
        st_l = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=tc)
        return [P(label, st_l), P(str(n), ST_VAL_C), P(pct(p), ST_VAL_C)], bg

    bgs = []
    for r, bg in [
        fila('Solicitados', conteo['Solicitado'], AMBAR_L, AMBAR),
        fila('Aprobados',   conteo['Aprobado'],   AZUL_L,  AZUL_C),
        fila('Despachados', conteo['Despachado'],  CIAN_L,  INFO),
        fila('Completados', conteo['Completado'],  VERDE_L, VERDE),
        fila('Rechazados',  conteo['Rechazado'],   ROJO_L,  ROJO),
    ]:
        rows.append(r)
        bgs.append(bg)

    ancho = PAGE_W / cm
    col_w = [ancho - 2.5 - 2.5, 2.5, 2.5]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), CIAN),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for i, bg in enumerate(bgs):
        ts.add('BACKGROUND', (0, i+1), (-1, i+1), bg)
    t.setStyle(ts)
    return t


# ════════════════════════════════════════════════════════════════════════════
#  3. SUCURSALES QUE MÁS ENVÍAN
# ════════════════════════════════════════════════════════════════════════════
def sucursales_table(traslados):
    mapa = {}
    for t in traslados:
        suc = t.get('TiendaOrigen') or '(Sin origen)'
        mapa[suc] = mapa.get(suc, 0) + 1

    sorted_s = sorted(mapa.items(), key=lambda x: x[1], reverse=True)
    total    = len(traslados)

    rows = [[P(h, ST_HDR) for h in ['Sucursal', 'Traslados', '%']]]
    for i, (suc, n) in enumerate(sorted_s):
        p  = (n / total * 100) if total > 0 else 0
        bg = CIAN_L if i == 0 else (BLANCO if i % 2 == 0 else GRIS_L)
        rows.append([P(suc, ST_CELL), P(str(n), ST_CELL_C), P(pct(p), ST_CELL_C)])

    ancho = PAGE_W / cm
    col_w = [ancho - 2.0 - 2.0, 2.0, 2.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  CIAN),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  4. DETALLE POR TRASLADO
# ════════════════════════════════════════════════════════════════════════════
# Columnas: Nro | Fecha | Ítems | Unidades | Origen | Destino | Estado | Registró
COL_W = [1.8, 2.0, 1.5, 1.8, 2.8, 2.8, 2.0, 2.8]
HDRS  = ['Nro', 'Fecha', 'Ítems', 'Unidades', 'Origen', 'Destino', 'Estado', 'Registró']

# Mapa de colores por estado
_ESTADO_BG = {
    'Solicitado': AMBAR_L,
    'Aprobado':   AZUL_L,
    'Despachado': CIAN_L,
    'Completado': VERDE_L,
    'Rechazado':  ROJO_L,
}


def _estado_cell(tr):
    estado = tr.get('EstadoAprobacion', 'Solicitado') or 'Solicitado'
    lines  = [P(estado, ST_CELL_C)]
    if estado == 'Aprobado':
        if tr.get('FechaAprobacion'): lines.append(P(tr['FechaAprobacion'], ST_SMALL))
        if tr.get('UsuarioAprueba'):  lines.append(P(tr['UsuarioAprueba'],  ST_OK))
    elif estado == 'Rechazado':
        if tr.get('MotivoRechazo'):  lines.append(P(tr['MotivoRechazo'],   ST_ERR))
    if len(lines) == 1: return lines[0]
    inner = Table([[l] for l in lines], colWidths=[None])
    inner.setStyle(TableStyle([
        ('TOPPADDING',    (0,0),(-1,-1), 0),
        ('BOTTOMPADDING', (0,0),(-1,-1), 0),
        ('LEFTPADDING',   (0,0),(-1,-1), 0),
        ('RIGHTPADDING',  (0,0),(-1,-1), 0),
    ]))
    return inner


def detalle_table(traslados):
    data   = [[P(h, ST_HDR) for h in HDRS]]
    styles = list(CELL_PAD) + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]
    for idx, t in enumerate(traslados):
        ri     = idx + 1
        estado = t.get('EstadoAprobacion', 'Solicitado') or 'Solicitado'
        data.append([
            P(t.get('Numero', '')         or '', ST_CELL_C),
            P(t.get('FechaTraslado', '')  or '', ST_CELL_C),
            P(str(t.get('CantidadItems', 0) or 0),  ST_CELL_C),
            P(str(t.get('TotalUnidades', 0) or 0),  ST_CELL_C),
            P(t.get('TiendaOrigen', '')   or '', ST_CELL),
            P(t.get('TiendaDestino', '')  or '', ST_CELL),
            _estado_cell(t),
            P(t.get('Usuario', '')        or '', ST_CELL),
        ])
        bg = _ESTADO_BG.get(estado, BLANCO if ri % 2 == 1 else GRIS_L)
        styles.append(('BACKGROUND', (0,ri), (-1,ri), bg))

    t = Table(data, colWidths=[w * cm for w in COL_W], repeatRows=1)
    t.setStyle(TableStyle(styles))
    return t


def totales_table(traslados):
    n_total    = len(traslados)
    tot_unid   = sum(int(t.get('TotalUnidades', 0) or 0) for t in traslados)
    conteo     = {'Solicitado': 0, 'Aprobado': 0, 'Despachado': 0, 'Completado': 0, 'Rechazado': 0}
    for t in traslados:
        est = t.get('EstadoAprobacion') or 'Solicitado'
        if est in conteo: conteo[est] += 1

    st_w  = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO)
    st_wc = _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)

    label = 'TOTAL: {} traslado(s)  Sol:{} Apro:{} Desp:{} Comp:{} Rech:{}'.format(
        n_total,
        conteo['Solicitado'], conteo['Aprobado'],
        conteo['Despachado'], conteo['Completado'], conteo['Rechazado'])

    # col 3 (Unidades) lleva el total de unidades
    row = [P(label, st_w), P('', st_w), P('', st_w), P(str(tot_unid), st_wc)] + \
          [P('', st_w)] * 4

    t = Table([row], colWidths=[w * cm for w in COL_W])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
        ('SPAN',       (0,0), (2,0)),
    ]))
    return t


def leyenda():
    col_w = [PAGE_W / 5] * 5
    est_info = [
        ('Solicitado', AMBAR_L, colors.HexColor('#92400e')),
        ('Aprobado',   AZUL_L,  colors.HexColor('#1d4ed8')),
        ('Despachado', CIAN_L,  colors.HexColor('#0891b2')),
        ('Completado', VERDE_L, colors.HexColor('#065f46')),
        ('Rechazado',  ROJO_L,  colors.HexColor('#991b1b')),
    ]
    cells = [P(label, _sty(fontSize=6.5, leading=8, textColor=tc)) for label, _, tc in est_info]
    t = Table([cells], colWidths=col_w)
    ts = TableStyle([
        ('GRID',       (0,0),(-1,-1), 0.3, GRIS_M),
        ('ALIGN',      (0,0),(-1,-1), 'CENTER'),
        ('TOPPADDING', (0,0),(-1,-1), 3), ('BOTTOMPADDING',(0,0),(-1,-1), 3),
        ('LEFTPADDING',(0,0),(-1,-1), 4), ('RIGHTPADDING', (0,0),(-1,-1), 4),
    ])
    for i, (_, bg, _tc) in enumerate(est_info):
        ts.add('BACKGROUND', (i,0), (i,0), bg)
    t.setStyle(ts)
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda         = data.get('NombreTienda',  'Todas las sucursales')
    empresa        = data.get('NombreEmpresa', tienda)
    fi             = data.get('FechaInicio',   '—')
    ff             = data.get('FechaFin',      '—')
    estado_filtro  = data.get('EstadoFiltro',  '') or ''
    reporte_id     = data.get('ReporteId',     '')
    nombre_usuario = data.get('NombreUsuario', '')
    logo_path      = data.get('LogoPath',      '')
    traslados      = data.get('Traslados',     [])

    periodo = '{} — {}'.format(fi, ff) if fi != '—' else ''
    filtros = ('Estado: ' + estado_filtro) if estado_filtro else ''

    doc = SimpleDocTemplate(
        output_path, pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Traslados de Productos'
    )

    cb    = _Canvas('Reporte Gerencial de Traslados entre Tiendas', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    if not traslados:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_CELL))
        doc.build(story, onFirstPage=cb, onLaterPages=cb)
        return

    # ── 1. Resumen Ejecutivo ──────────────────────────────────────────────
    story.append(P('Resumen Ejecutivo', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(kpi_table(traslados))
    story.append(Spacer(1, 8))

    # ── 2. Estado de Traslados ────────────────────────────────────────────
    story.append(P('Estado de Traslados', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(estado_table(traslados))
    story.append(Spacer(1, 8))

    # ── 3. Sucursales que más envían ──────────────────────────────────────
    story.append(P('Sucursales que más Envían', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(sucursales_table(traslados))
    story.append(Spacer(1, 8))

    # ── 4. Detalle + leyenda + totales ────────────────────────────────────
    story.append(P('Detalle Completo', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(leyenda())
    story.append(Spacer(1, 4))
    story.append(detalle_table(traslados))
    story.append(Spacer(1, 0))
    story.append(totales_table(traslados))

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
