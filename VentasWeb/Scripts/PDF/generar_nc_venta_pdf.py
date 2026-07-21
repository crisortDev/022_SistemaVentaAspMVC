# ============================================================
#  generar_nc_venta_pdf.py
#  Documento formal de Nota de Crédito de Venta — A4 Portrait
#  Uso: python generar_nc_venta_pdf.py <json> <pdf>
# ============================================================

import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from membrete import _Canvas, MARG_TOP, MARG_H

from reportlab.lib.pagesizes import A4
from reportlab.lib.units     import cm
from reportlab.lib           import colors
from reportlab.lib.styles    import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums     import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.platypus      import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable

# ── Página ────────────────────────────────────────────────────────────────────
PAGE     = A4
MARG_BOT = 2.0 * cm
PAGE_W   = PAGE[0] - 2 * MARG_H   # ancho útil ≈ 18 cm

# ── Colores ───────────────────────────────────────────────────────────────────
AZUL     = colors.HexColor('#1a3566')
AZUL_CLR = colors.HexColor('#e8edf5')
AMBAR    = colors.HexColor('#ffc107')
AMBAR_D  = colors.HexColor('#856404')
AMBAR_L  = colors.HexColor('#fff3cd')
VERDE    = colors.HexColor('#28a745')
VERDE_L  = colors.HexColor('#d4edda')
ROJO     = colors.HexColor('#dc3545')
ROJO_L   = colors.HexColor('#f8d7da')
GRIS_L   = colors.HexColor('#f8f9fa')
GRIS_M   = colors.HexColor('#dee2e6')
GRIS_T   = colors.HexColor('#6c757d')
GRIS_OS  = colors.HexColor('#343a40')
BLANCO   = colors.white

# ── Estilos ───────────────────────────────────────────────────────────────────
_base = getSampleStyleSheet()['Normal']
_cnt  = [0]

def _sty(**kw):
    _cnt[0] += 1
    d = dict(name='ncv%d' % _cnt[0], parent=_base, fontSize=9, leading=12)
    d.update(kw)
    return ParagraphStyle(**d)

ST_TITLE  = _sty(fontSize=16, fontName='Helvetica-Bold', textColor=AZUL,    alignment=TA_CENTER)
ST_NCV    = _sty(fontSize=13, fontName='Helvetica-Bold', textColor=AMBAR_D,  alignment=TA_CENTER)
ST_SEC    = _sty(fontSize=9,  fontName='Helvetica-Bold', textColor=BLANCO)
ST_LBL    = _sty(fontSize=8,  textColor=GRIS_T)
ST_VAL    = _sty(fontSize=9,  fontName='Helvetica-Bold', textColor=GRIS_OS)
ST_CELL   = _sty(fontSize=8,  leading=10)
ST_CELL_C = _sty(fontSize=8,  leading=10, alignment=TA_CENTER)
ST_CELL_R = _sty(fontSize=8,  leading=10, alignment=TA_RIGHT)
ST_HDR    = _sty(fontSize=8,  fontName='Helvetica-Bold', textColor=BLANCO, alignment=TA_CENTER)
ST_BOLD_R = _sty(fontSize=8,  fontName='Helvetica-Bold', alignment=TA_RIGHT)
ST_BOLD_C = _sty(fontSize=8,  fontName='Helvetica-Bold', alignment=TA_CENTER)
ST_NOTA   = _sty(fontSize=7.5, textColor=GRIS_T, leading=10)

CELL_PAD = [
    ('TOPPADDING',    (0, 0), (-1, -1), 3),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ('LEFTPADDING',   (0, 0), (-1, -1), 5),
    ('RIGHTPADDING',  (0, 0), (-1, -1), 5),
    ('VALIGN',        (0, 0), (-1, -1), 'MIDDLE'),
]

def P(txt, sty):
    return Paragraph(str(txt) if txt is not None else '—', sty)

def gs(v):
    try:    return 'Gs. {:,.0f}'.format(float(str(v).replace(',', ''))).replace(',', '.')
    except: return 'Gs. 0'

def lv(label, value):
    """Mini-tabla etiqueta + valor para sección de datos."""
    t = Table(
        [[P(label, ST_LBL)], [P(value or '—', ST_VAL)]],
        colWidths=[PAGE_W / 2 - 0.3 * cm]
    )
    t.setStyle(TableStyle([
        ('TOPPADDING',    (0,0), (-1,-1), 1),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1),
        ('LEFTPADDING',   (0,0), (-1,-1), 0),
        ('RIGHTPADDING',  (0,0), (-1,-1), 0),
    ]))
    return t


# ── Bloque de título ──────────────────────────────────────────────────────────
def titulo_block(cab):
    estado = (cab.get('Estado') or 'Pendiente').strip()
    color_est = {'Aprobada': VERDE, 'Rechazada': ROJO}.get(estado, AMBAR_D)
    bg_est    = {'Aprobada': VERDE_L,'Rechazada': ROJO_L}.get(estado, AMBAR_L)

    data = [
        [P('NOTA DE CRÉDITO DE VENTA', ST_TITLE)],
        [P(cab.get('NumeroNCV', '—'), ST_NCV)],
        [Paragraph(
            '<font color="#{}">{}</font>'.format(
                color_est.hexval()[2:], estado.upper()),
            _sty(fontSize=10, fontName='Helvetica-Bold', alignment=TA_CENTER,
                 textColor=color_est))],
    ]
    t = Table(data, colWidths=[PAGE_W])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0, 0), (-1, -1), AZUL_CLR),
        ('TOPPADDING',    (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING',   (0, 0), (-1, -1), 8),
        ('RIGHTPADDING',  (0, 0), (-1, -1), 8),
        ('ROUNDEDCORNERS', [4]),
        ('BOX',           (0, 0), (-1, -1), 1.2, AZUL),
    ]))
    return t


# ── Sección con cabecera coloreada ────────────────────────────────────────────
def sec_header(texto):
    t = Table([[P(texto, ST_SEC)]], colWidths=[PAGE_W])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AZUL),
        ('TOPPADDING',    (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
    ]))
    return t


# ── Datos en dos columnas ─────────────────────────────────────────────────────
def dos_cols(izq_label, izq_val, der_label, der_val):
    w = PAGE_W / 2
    data = [[lv(izq_label, izq_val), lv(der_label, der_val)]]
    t = Table(data, colWidths=[w, w])
    t.setStyle(TableStyle([
        ('VALIGN',        (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING',    (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING',   (0,0), (-1,-1), 4),
        ('RIGHTPADDING',  (0,0), (-1,-1), 4),
        ('LINEBELOW',     (0,0), (-1,-1), 0.3, GRIS_M),
    ]))
    return t


# ── Tabla de productos ────────────────────────────────────────────────────────
def productos_table(productos):
    col_w = [1.2*cm, PAGE_W - 1.2*cm - 2.8*cm - 3.2*cm - 3.2*cm,
             2.8*cm, 3.2*cm, 3.2*cm]
    hdrs  = ['#', 'Producto', 'Cant.', 'Precio Unit.', 'Subtotal']

    data  = [[P(h, ST_HDR) for h in hdrs]]
    total = 0.0

    for i, p in enumerate(productos):
        try:   cant  = float(str(p.get('Cantidad', 0)))
        except: cant = 0.0
        try:   precio = float(str(p.get('PrecioUnitario', 0)))
        except: precio = 0.0
        sub    = cant * precio
        total += sub

        cant_txt = str(int(cant)) if cant == int(cant) else '{:.2f}'.format(cant)
        data.append([
            P(str(i+1), ST_CELL_C),
            P(p.get('NombreProducto', '—'), ST_CELL),
            P(cant_txt, ST_CELL_C),
            P(gs(precio), ST_CELL_R),
            P(gs(sub),    ST_CELL_R),
        ])

    # Fila total
    data.append([
        P('', ST_CELL), P('', ST_CELL), P('', ST_CELL),
        P('TOTAL NC', _sty(fontSize=8, fontName='Helvetica-Bold', alignment=TA_RIGHT,
                           textColor=BLANCO)),
        P(gs(total), _sty(fontSize=8, fontName='Helvetica-Bold', alignment=TA_RIGHT,
                          textColor=BLANCO)),
    ])
    tot_row = len(data) - 1

    t = Table(data, colWidths=col_w, repeatRows=1)
    t.setStyle(TableStyle(CELL_PAD + [
        ('BACKGROUND',    (0, 0),       (-1, 0),         AZUL),
        ('ROWBACKGROUNDS',(0, 1),       (-1, tot_row-1), [BLANCO, GRIS_L]),
        ('BACKGROUND',    (0, tot_row), (-1, tot_row),   GRIS_OS),
        ('GRID',          (0, 0),       (-1, -1),        0.3, GRIS_M),
        ('LINEABOVE',     (0, tot_row), (-1, tot_row),   1.0, GRIS_OS),
    ]))
    return t


# ── Caja de monto total (para NC contado) ─────────────────────────────────────
def monto_box(monto):
    data = [
        [P('Monto de la Nota de Crédito', _sty(fontSize=8, textColor=AMBAR_D, alignment=TA_CENTER))],
        [P(gs(monto), _sty(fontSize=16, fontName='Helvetica-Bold',
                           textColor=AMBAR_D, alignment=TA_CENTER))],
    ]
    t = Table(data, colWidths=[PAGE_W])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), AMBAR_L),
        ('TOPPADDING',    (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING',   (0,0), (-1,-1), 8),
        ('RIGHTPADDING',  (0,0), (-1,-1), 8),
        ('BOX',           (0,0), (-1,-1), 1.0, AMBAR),
    ]))
    return t


# ── Firmas ────────────────────────────────────────────────────────────────────
def firmas_table(cab):
    reg_nombre = cab.get('NombreRegistro', '—')
    apr_nombre = cab.get('NombreAprobacion', '') or '—'
    apr_fecha  = cab.get('FechaAprobacion', '')  or '—'
    reg_fecha  = cab.get('FechaRegistro', '—')

    def firma_cell(nombre, rol, fecha):
        return Table([
            [P('_' * 32, _sty(fontSize=8, alignment=TA_CENTER, textColor=GRIS_M))],
            [P(nombre, _sty(fontSize=8,  fontName='Helvetica-Bold', alignment=TA_CENTER))],
            [P(rol,    _sty(fontSize=7.5, textColor=GRIS_T, alignment=TA_CENTER))],
            [P(fecha,  _sty(fontSize=7,  textColor=GRIS_T, alignment=TA_CENTER))],
        ], colWidths=[PAGE_W / 2 - 1*cm])

    t = Table([[firma_cell(reg_nombre, 'Registrado por', reg_fecha),
                firma_cell(apr_nombre, 'Aprobado por', apr_fecha)]],
              colWidths=[PAGE_W / 2, PAGE_W / 2])
    t.setStyle(TableStyle([
        ('VALIGN',  (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING',    (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ]))
    return t


# ════════════════════════════════════════════════════════════════════════════
#  BUILD PDF
# ════════════════════════════════════════════════════════════════════════════
def build_pdf(data, output_path):
    cab       = data.get('Cabecera', {})
    productos = data.get('Productos', [])
    empresa   = data.get('NombreEmpresa', '')
    logo      = data.get('LogoPath', '')
    usuario   = data.get('NombreUsuario', '')
    rpt_id    = data.get('ReporteId', '')

    doc = SimpleDocTemplate(
        output_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
        title='Nota de Crédito de Venta'
    )

    cb = _Canvas('Nota de Crédito de Venta', empresa, '', '', usuario, rpt_id, logo)

    story = []

    # ── Título / número NCV / estado
    story.append(titulo_block(cab))
    story.append(Spacer(1, 10))

    # ── Datos generales
    story.append(sec_header('Datos Generales'))
    story.append(dos_cols('Fecha de Registro', cab.get('FechaRegistro'),
                           'Tienda',            cab.get('NombreTienda')))
    story.append(dos_cols('Motivo',             cab.get('MotivoNC'),
                           'Modalidad de Pago', cab.get('ModalidadPago')))
    if cab.get('Observacion'):
        story.append(dos_cols('Observación', cab.get('Observacion'), '', ''))
    if cab.get('Estado') == 'Rechazada' and cab.get('MotivoRechazo'):
        story.append(dos_cols('Motivo de Rechazo', cab.get('MotivoRechazo'), '', ''))
    story.append(Spacer(1, 8))

    # ── Datos del cliente
    story.append(sec_header('Cliente'))
    story.append(dos_cols('Nombre', cab.get('NombreCliente'),
                           'Documento', cab.get('DocumentoCliente')))
    story.append(Spacer(1, 8))

    # ── Venta original
    story.append(sec_header('Venta Original'))
    story.append(dos_cols('N° Factura',   cab.get('NumeroFactura'),
                           'Fecha Venta', cab.get('FechaVenta')))
    story.append(dos_cols('Total Venta',  gs(cab.get('TotalCosto', 0)),
                           'N° Cuotas',   str(cab.get('NumeroCuotas') or '—')))
    story.append(Spacer(1, 8))

    # ── Detalle de productos (NC crédito) o caja de monto (NC contado)
    if productos:
        story.append(sec_header('Productos Incluidos en la NC'))
        story.append(Spacer(1, 4))
        story.append(productos_table(productos))
    else:
        story.append(sec_header('Monto de la Nota de Crédito'))
        story.append(Spacer(1, 6))
        story.append(monto_box(cab.get('Monto', 0)))

    story.append(Spacer(1, 14))
    story.append(HRFlowable(width=PAGE_W, thickness=0.5, color=GRIS_M))
    story.append(Spacer(1, 10))

    # ── Firmas
    story.append(firmas_table(cab))

    # ── Nota al pie
    story.append(Spacer(1, 10))
    story.append(P(
        'Este documento es una Nota de Crédito de Venta generada por el sistema. '
        'Su validez está sujeta a la aprobación del Encargado de Tienda.',
        ST_NOTA))

    doc.build(story, onFirstPage=cb, onLaterPages=cb)


# ════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python generar_nc_venta_pdf.py <json> <pdf>', file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    build_pdf(data, sys.argv[2])
    print('OK — PDF generado: ' + sys.argv[2])
