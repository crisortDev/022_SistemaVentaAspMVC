# ============================================================
#  generar_reporte_bajas.py
#  Reporte Gerencial de Bajas de Productos — Portrait A4
#  Uso: python generar_reporte_bajas.py <json> <pdf>
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
AZUL    = colors.HexColor('#1a3566')
ROJO    = colors.HexColor('#dc2626')
VERDE   = colors.HexColor('#059669')
AMBAR   = colors.HexColor('#b45309')
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

ST_SEC   = _sty(fontSize=9,   fontName='Helvetica-Bold', textColor=ROJO, spaceBefore=6, spaceAfter=3)
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

def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(v or 0)).replace(',', '.')
    except: return 'Gs. 0'

def pct(v):
    try:    return '{:.1f}%'.format(float(v or 0))
    except: return '0.0%'


# ════════════════════════════════════════════════════════════════════════════
#  1. RESUMEN EJECUTIVO
# ════════════════════════════════════════════════════════════════════════════
def kpi_table(bajas):
    solicitudes = len(bajas)
    unidades    = sum(int(b.get('Cantidad', 0) or 0) for b in bajas)
    productos   = len(set(b.get('CodigoProducto', '') for b in bajas))
    costo       = sum(int(b.get('Cantidad', 0) or 0) * float(b.get('CostoPromedio', 0) or 0) for b in bajas)

    st_h = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
    st_hr= _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_RIGHT)

    rows = [
        [P('Indicador', st_h), P('Valor', st_hr)],
        [P('Solicitudes de baja',           ST_LBL), P(str(solicitudes),  ST_VAL)],
        [P('Unidades dadas de baja',         ST_LBL), P(str(unidades),     ST_VAL)],
        [P('Productos afectados',            ST_LBL), P(str(productos),    ST_VAL)],
        [P('Costo estimado de todas las bajas', ST_LBL), P(gs(costo),     ST_VAL)],
    ]

    ancho = PAGE_W / cm
    t = Table(rows, colWidths=[(ancho - 4.0) * cm, 4.0 * cm])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  ROJO),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  2. ESTADO DE SOLICITUDES
# ════════════════════════════════════════════════════════════════════════════
def estado_table(bajas):
    total      = len(bajas)
    aprobadas  = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Aprobada')
    pendientes = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Pendiente')
    rechazadas = sum(1 for b in bajas if (b.get('EstadoAprobacion') or '') == 'Rechazada')

    rows = [[P(h, ST_HDR) for h in ['Estado', 'Cantidad', '%']]]

    def fila(label, n, bg, tc):
        p = (n / total * 100) if total > 0 else 0
        st_l = _sty(fontSize=7.5, fontName='Helvetica-Bold', textColor=tc)
        return [P(label, st_l), P(str(n), ST_VAL_C), P(pct(p), ST_VAL_C)], bg

    bgs = []
    for r, bg in [
        fila('Aprobadas',  aprobadas,  VERDE_L, VERDE),
        fila('Pendientes', pendientes, AMBAR_L, AMBAR),
        fila('Rechazadas', rechazadas, ROJO_L,  ROJO),
    ]:
        rows.append(r)
        bgs.append(bg)

    ancho = PAGE_W / cm
    col_w = [ancho - 2.5 - 2.5, 2.5, 2.5]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    ts = TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), ROJO),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ])
    for i, bg in enumerate(bgs):
        ts.add('BACKGROUND', (0, i+1), (-1, i+1), bg)
    t.setStyle(ts)
    return t


# ════════════════════════════════════════════════════════════════════════════
#  3. MOTIVOS DE BAJA
# ════════════════════════════════════════════════════════════════════════════
def motivos_table(bajas):
    mapa = {}
    for b in bajas:
        motivo = b.get('MotivoBaja') or 'Sin motivo'
        mapa[motivo] = mapa.get(motivo, 0) + int(b.get('Cantidad', 0) or 0)

    sorted_m = sorted(mapa.items(), key=lambda x: x[1], reverse=True)
    total    = sum(v for _, v in sorted_m)

    rows = [[P(h, ST_HDR) for h in ['Motivo', 'Unidades', '%']]]
    for i, (motivo, n) in enumerate(sorted_m):
        p  = (n / total * 100) if total > 0 else 0
        bg = BLANCO if i % 2 == 0 else GRIS_L
        rows.append([P(motivo, ST_CELL), P(str(n), ST_CELL_C), P(pct(p), ST_CELL_C)])

    ancho = PAGE_W / cm
    col_w = [ancho - 2.0 - 2.0, 2.0, 2.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  AMBAR),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  4. TOP 5 PRODUCTOS
# ════════════════════════════════════════════════════════════════════════════
def top_productos_table(bajas):
    mapa = {}
    for b in bajas:
        key = b.get('CodigoProducto') or '—'
        if key not in mapa:
            mapa[key] = {'nombre': b.get('NombreProducto') or key, 'cantidad': 0}
        mapa[key]['cantidad'] += int(b.get('Cantidad', 0) or 0)

    sorted_p = sorted(mapa.values(), key=lambda x: x['cantidad'], reverse=True)[:5]
    total    = sum(int(b.get('Cantidad', 0) or 0) for b in bajas)

    rows = [[P(h, ST_HDR) for h in ['#', 'Producto', 'Unidades', '%']]]
    for i, p in enumerate(sorted_p):
        pt   = (p['cantidad'] / total * 100) if total > 0 else 0
        bg   = ROJO_L if i == 0 else (BLANCO if i % 2 == 0 else GRIS_L)
        rows.append([
            P(str(i+1), ST_CELL_C),
            P(p['nombre'], ST_CELL),
            P(str(p['cantidad']), ST_CELL_C),
            P(pct(pt), ST_CELL_C),
        ])

    ancho = PAGE_W / cm
    col_w = [0.8, ancho - 0.8 - 2.0 - 2.0, 2.0, 2.0]
    t = Table(rows, colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',     (0,0), (-1,0),  GRIS_OS),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BLANCO, GRIS_L]),
        ('GRID',           (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  5+6. TABLA DETALLE + TOTALES (existentes, conservados)
# ════════════════════════════════════════════════════════════════════════════
COL_W_UNA   = [1.8, 2.0, 1.5, 3.8, 1.0, 2.7, 2.2, 3.0]
HDRS_UNA    = ['Nro', 'Fecha', 'Código', 'Producto', 'Cant.', 'Motivo', 'Estado', 'Registró']
COL_W_TODAS = [2.5, 1.5, 1.8, 1.5, 3.0, 0.8, 2.5, 2.2, 2.2]
HDRS_TODAS  = ['Tienda', 'Nro', 'Fecha', 'Código', 'Producto', 'Cant.', 'Motivo', 'Estado', 'Registró']


def _estado_cell(baja):
    estado = baja.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'
    lines  = [P(estado, ST_CELL_C)]
    if estado == 'Aprobada':
        if baja.get('FechaAprobacion'): lines.append(P(baja['FechaAprobacion'], ST_SMALL))
        if baja.get('UsuarioAprueba'):  lines.append(P(baja['UsuarioAprueba'],  ST_OK))
    elif estado == 'Rechazada':
        if baja.get('MotivoRechazo'):  lines.append(P(baja['MotivoRechazo'],   ST_ERR))
    if len(lines) == 1: return lines[0]
    inner = Table([[l] for l in lines], colWidths=[None])
    inner.setStyle(TableStyle([
        ('TOPPADDING',(0,0),(-1,-1),0), ('BOTTOMPADDING',(0,0),(-1,-1),0),
        ('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),
    ]))
    return inner


def detalle_table(bajas, mostrar_tienda):
    col_w = COL_W_TODAS if mostrar_tienda else COL_W_UNA
    hdrs  = HDRS_TODAS  if mostrar_tienda else HDRS_UNA
    data  = [[P(h, ST_HDR) for h in hdrs]]
    styles = list(CELL_PAD) + [
        ('BACKGROUND', (0,0), (-1,0),  AZUL),
        ('GRID',       (0,0), (-1,-1), 0.3, GRIS_M),
    ]
    for idx, b in enumerate(bajas):
        ri     = idx + 1
        estado = b.get('EstadoAprobacion', 'Pendiente') or 'Pendiente'
        fila_core = [
            P(b.get('Numero', '')         or '', ST_CELL_C),
            P(b.get('FechaMovimiento', '') or '', ST_CELL_C),
            P(b.get('CodigoProducto', '')  or '', ST_CELL_C),
            P(b.get('NombreProducto', '')  or '', ST_CELL),
            P(str(b.get('Cantidad', 0)),          ST_CELL_C),
            P(b.get('MotivoBaja', '')      or '', ST_CELL),
            _estado_cell(b),
            P(b.get('UsuarioRegistro', '') or '', ST_CELL),
        ]
        row = [[ P(b.get('NombreTienda','') or '', ST_CELL),
                 P(b.get('RucTienda','')    or '', ST_SMALL) ]] + fila_core \
              if mostrar_tienda else fila_core
        data.append(row)
        if   estado == 'Pendiente': styles.append(('BACKGROUND', (0,ri), (-1,ri), AMBAR_L))
        elif estado == 'Rechazada': styles.append(('BACKGROUND', (0,ri), (-1,ri), ROJO_L))
        else: styles.append(('BACKGROUND', (0,ri), (-1,ri), BLANCO if ri % 2 == 1 else GRIS_L))
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
    label    = 'TOTAL: {} baja(s)   Aprobada: {}   Pendiente: {}   Rechazada: {}'.format(
                n_total, n_apro, n_pend, n_rech)
    ncols = len(col_w)
    span_end = (4, 0) if ncols == 9 else (3, 0)
    cant_idx = 5 if ncols == 9 else 4

    row = [P(label, _sty(fontSize=7, fontName='Helvetica-Bold', textColor=BLANCO))]
    for j in range(1, ncols):
        if j == cant_idx:
            row.append(P(str(tot_cant), _sty(fontSize=7, fontName='Helvetica-Bold',
                                              textColor=BLANCO, alignment=TA_CENTER)))
        else:
            row.append(P('', _sty(fontSize=6, textColor=BLANCO)))

    t = Table([row], colWidths=[w * cm for w in col_w])
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND', (0,0), (-1,0), AZUL),
        ('GRID',       (0,0), (-1,0), 0.3, GRIS_M),
        ('SPAN',       (0,0), span_end),
    ]))
    return t


def leyenda():
    col_w = [PAGE_W / 3] * 3
    data = [[
        P('Pendiente', _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#92400e'))),
        P('Aprobada (fondo blanco/gris)', _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#065f46'))),
        P('Rechazada', _sty(fontSize=6.5, leading=8, textColor=colors.HexColor('#991b1b'))),
    ]]
    t = Table(data, colWidths=col_w)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0),(0,0), AMBAR_L),
        ('BACKGROUND', (1,0),(1,0), GRIS_L),
        ('BACKGROUND', (2,0),(2,0), ROJO_L),
        ('GRID',       (0,0),(-1,-1), 0.3, GRIS_M),
        ('ALIGN',      (0,0),(-1,-1), 'CENTER'),
        ('TOPPADDING', (0,0),(-1,-1), 3), ('BOTTOMPADDING',(0,0),(-1,-1), 3),
        ('LEFTPADDING',(0,0),(-1,-1), 4), ('RIGHTPADDING', (0,0),(-1,-1), 4),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    tienda         = data.get('NombreTienda',  'Todas las sucursales')
    empresa        = data.get('NombreEmpresa', tienda)
    id_tienda      = int(data.get('IdTienda',  0) or 0)
    fi             = data.get('FechaInicio',   '—')
    ff             = data.get('FechaFin',      '—')
    estado_filtro  = data.get('EstadoFiltro',  '') or ''
    reporte_id     = data.get('ReporteId',     '')
    nombre_usuario = data.get('NombreUsuario', '')
    logo_path      = data.get('LogoPath',      '')
    bajas          = data.get('Bajas',         [])

    mostrar_tienda = (id_tienda == 0)
    periodo  = '{} — {}'.format(fi, ff) if fi != '—' else ''
    filtros  = ('Estado: ' + estado_filtro) if estado_filtro else ''

    doc = SimpleDocTemplate(
        output_path, pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Reporte Gerencial de Bajas de Productos'
    )

    cb    = _Canvas('Reporte Gerencial de Bajas de Productos', empresa, periodo,
                    filtros, nombre_usuario, reporte_id, logo_path)
    story = []

    if not bajas:
        story.append(P('Sin resultados para los filtros seleccionados.', ST_CELL))
        doc.build(story, onFirstPage=cb, onLaterPages=cb)
        return

    # ── 1. Resumen Ejecutivo ──────────────────────────────────────────────
    story.append(P('Resumen Ejecutivo', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(kpi_table(bajas))
    story.append(Spacer(1, 8))

    # ── 2. Estado de Solicitudes ──────────────────────────────────────────
    story.append(P('Estado de Solicitudes', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(estado_table(bajas))
    story.append(Spacer(1, 8))

    # ── 3. Motivos de Baja ────────────────────────────────────────────────
    story.append(P('Motivos de Baja', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(motivos_table(bajas))
    story.append(Spacer(1, 8))

    # ── 4. Top 5 Productos ────────────────────────────────────────────────
    story.append(P('Productos con Mayor Cantidad de Bajas (Top 5)', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(top_productos_table(bajas))
    story.append(Spacer(1, 8))

    # ── 5. Detalle + leyenda + totales ────────────────────────────────────
    story.append(P('Detalle Completo', ST_SEC))
    story.append(Spacer(1, 2))
    story.append(leyenda())
    story.append(Spacer(1, 4))
    story.append(detalle_table(bajas, mostrar_tienda))
    story.append(Spacer(1, 0))
    story.append(totales_table(bajas, mostrar_tienda))

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
