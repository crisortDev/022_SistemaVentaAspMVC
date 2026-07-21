# ============================================================
#  generar_nc_compra_pdf.py
#  Documento formal de Nota de Crédito de Compra — A4 Portrait
#  Uso: python generar_nc_compra_pdf.py <json> <pdf>
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
    d = dict(name='ncc%d' % _cnt[0], parent=_base, fontSize=9, leading=12)
    d.update(kw)
    return ParagraphStyle(**d)

ST_TITLE  = _sty(fontSize=16, fontName='Helvetica-Bold', textColor=AZUL,   alignment=TA_CENTER)
ST_NC     = _sty(fontSize=13, fontName='Helvetica-Bold', textColor=AMBAR_D, alignment=TA_CENTER)
ST_SEC    = _sty(fontSize=9,  fontName='Helvetica-Bold', textColor=BLANCO)
ST_LBL    = _sty(fontSize=8,  textColor=GRIS_T)
ST_VAL    = _sty(fontSize=9,  fontName='Helvetica-Bold', textColor=GRIS_OS)
ST_FOOT   = _sty(fontSize=8,  textColor=GRIS_T, alignment=TA_CENTER)

# ── Helpers ───────────────────────────────────────────────────────────────────
def gs(n):
    """Formatea número como guaraníes: Gs. 1.234.567"""
    try:
        return "Gs. {:,.0f}".format(float(n)).replace(",", ".")
    except:
        return "Gs. 0"

def _row(lbl, val, lbl_w=5*cm):
    return Table(
        [[Paragraph(lbl, ST_LBL), Paragraph(str(val or '—'), ST_VAL)]],
        colWidths=[lbl_w, PAGE_W - lbl_w],
        style=[
            ('VALIGN',  (0,0), (-1,-1), 'TOP'),
            ('TOPPADDING',    (0,0), (-1,-1), 2),
            ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ]
    )

def section_header(text):
    t = Table(
        [[Paragraph(text, ST_SEC)]],
        colWidths=[PAGE_W],
        style=[
            ('BACKGROUND',    (0,0), (-1,-1), AZUL),
            ('TOPPADDING',    (0,0), (-1,-1), 5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ('LEFTPADDING',   (0,0), (-1,-1), 8),
        ]
    )
    return t

def badge_estado(estado):
    color_map = {
        'Pendiente': (AMBAR_L, AMBAR_D),
        'Recibida':  (VERDE_L, VERDE),
        'Rechazada': (colors.HexColor('#f8d7da'), ROJO),
    }
    bg, fg = color_map.get(estado, (GRIS_L, GRIS_OS))
    sty = _sty(fontSize=9, fontName='Helvetica-Bold', textColor=fg, alignment=TA_CENTER)
    t = Table(
        [[Paragraph(estado or '—', sty)]],
        colWidths=[3.5*cm],
        style=[
            ('BACKGROUND',    (0,0), (-1,-1), bg),
            ('TOPPADDING',    (0,0), (-1,-1), 4),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
            ('ROUNDEDCORNERS',(0,0), (-1,-1), [4,4,4,4]),
        ]
    )
    return t

# ── Main ─────────────────────────────────────────────────────────────────────
def main(json_path, pdf_path):
    with open(json_path, encoding='utf-8') as f:
        data = json.load(f)

    cab = data.get('Cabecera', {})
    nombre_empresa = data.get('NombreEmpresa', 'COMPU SPACE')
    logo_path      = data.get('LogoPath', '')
    nombre_usuario = data.get('NombreUsuario', '')
    reporte_id     = data.get('ReporteId', '')

    def make_canvas(filename):
        return _Canvas(filename, nombre_empresa=nombre_empresa,
                       logo_path=logo_path, pagesize=PAGE)

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=PAGE,
        leftMargin=MARG_H, rightMargin=MARG_H,
        topMargin=MARG_TOP, bottomMargin=MARG_BOT,
    )

    story = []

    # ── Título ────────────────────────────────────────────────────────────────
    story.append(Paragraph("NOTA DE CRÉDITO DE COMPRA", ST_TITLE))
    story.append(Spacer(1, 4))

    # Número NC
    num_nc = cab.get('NumeroNC') or ''
    if num_nc:
        story.append(Paragraph(num_nc, ST_NC))
    story.append(Spacer(1, 6))

    # Estado badge
    estado = cab.get('Estado', '')
    estado_row = Table(
        [[badge_estado(estado)]],
        colWidths=[PAGE_W],
        style=[('ALIGN', (0,0), (-1,-1), 'CENTER')]
    )
    story.append(estado_row)
    story.append(Spacer(1, 10))
    story.append(HRFlowable(width=PAGE_W, thickness=1, color=AZUL_CLR))
    story.append(Spacer(1, 8))

    # ── Datos del Timbrado ────────────────────────────────────────────────────
    story.append(section_header("📋  DATOS DEL TIMBRADO"))
    story.append(Spacer(1, 6))

    timbrado_data = [
        ['Nro. Timbrado', cab.get('NumeroTimbrado', '—')],
        ['Fecha Venc. Timbrado', cab.get('FechaVencTimbrado', '—')],
        ['Fecha Emisión NC', cab.get('FechaEmision', '—')],
        ['Fecha Registro', cab.get('FechaRegistro', '—')],
    ]
    for lbl, val in timbrado_data:
        story.append(_row(lbl + ':', val))
    story.append(Spacer(1, 10))

    # ── Datos del Proveedor ───────────────────────────────────────────────────
    story.append(section_header("🚚  DATOS DEL PROVEEDOR"))
    story.append(Spacer(1, 6))
    story.append(_row('Razón Social:', cab.get('Proveedor', '—')))
    story.append(_row('RUC:', cab.get('RucProveedor', '—')))
    story.append(Spacer(1, 10))

    # ── Factura de Referencia ─────────────────────────────────────────────────
    story.append(section_header("🧾  FACTURA DE REFERENCIA"))
    story.append(Spacer(1, 6))
    story.append(_row('Nro. Compra:', cab.get('NumeroCompra', '—')))
    story.append(_row('Nro. Factura:', cab.get('NumeroFactura', '—')))
    story.append(_row('Fecha Factura:', cab.get('FechaFactura', '—')))
    total_fact = gs(cab.get('MontoFactura', 0))
    story.append(_row('Total Factura:', total_fact))
    story.append(Spacer(1, 10))

    # ── Detalle NC ───────────────────────────────────────────────────────────
    story.append(section_header("💰  MONTO DE LA NOTA DE CRÉDITO"))
    story.append(Spacer(1, 6))
    story.append(_row('Motivo:', cab.get('MotivoNC', '—')))
    story.append(_row('Observación:', cab.get('Observacion', '—')))

    # Monto destacado
    monto_nc = cab.get('MontoNC', 0)
    monto_sty = _sty(fontSize=14, fontName='Helvetica-Bold',
                     textColor=AZUL, alignment=TA_CENTER)
    monto_t = Table(
        [[Paragraph(gs(monto_nc), monto_sty)]],
        colWidths=[PAGE_W],
        style=[
            ('BACKGROUND',    (0,0), (-1,-1), AMBAR_L),
            ('TOPPADDING',    (0,0), (-1,-1), 8),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
            ('BOX', (0,0), (-1,-1), 1, AMBAR),
        ]
    )
    story.append(Spacer(1, 6))
    story.append(monto_t)
    story.append(Spacer(1, 10))

    # ── Tienda ───────────────────────────────────────────────────────────────
    story.append(section_header("🏪  TIENDA"))
    story.append(Spacer(1, 6))
    story.append(_row('Nombre:', cab.get('NombreTienda', '—')))
    if cab.get('DireccionTienda'):
        story.append(_row('Dirección:', cab.get('DireccionTienda')))
    if cab.get('RucTienda'):
        story.append(_row('RUC:', cab.get('RucTienda')))
    story.append(Spacer(1, 10))

    # ── Registrado por ───────────────────────────────────────────────────────
    story.append(section_header("👤  REGISTRADO POR"))
    story.append(Spacer(1, 6))
    story.append(_row('Usuario:', cab.get('UsuarioRegistro', '—')))
    if cab.get('FechaConfirmacion'):
        story.append(_row('Confirmado:', cab.get('FechaConfirmacion')))
    story.append(Spacer(1, 16))

    # ── Pie ──────────────────────────────────────────────────────────────────
    story.append(HRFlowable(width=PAGE_W, thickness=1, color=AZUL_CLR))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        f"Documento generado por {nombre_usuario}  •  {nombre_empresa}  •  {reporte_id}",
        ST_FOOT
    ))

    doc.build(story, canvasmaker=make_canvas)
    print("OK: PDF generado en", pdf_path)

# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Uso: python generar_nc_compra_pdf.py <json> <pdf>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
