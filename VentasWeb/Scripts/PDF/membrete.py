# ============================================================
#  membrete.py
#  Cabecera y pie de página uniformes para todos los reportes PDF.
#
#  Uso en cada script:
#      import os, sys
#      sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
#      from membrete import _Canvas, MARG_TOP
#
#  La clase _Canvas se pasa como callback a SimpleDocTemplate:
#      cb = _Canvas(titulo, empresa, periodo, filtros,
#                   nombre_usuario, reporte_id, logo_path)
#      doc.build(story, onFirstPage=cb, onLaterPages=cb)
# ============================================================

import os
from datetime import datetime

from reportlab.lib.units import cm
from reportlab.lib       import colors

# ── Constantes exportadas ────────────────────────────────────────────────────
MARG_H   = 1.5 * cm
_BAR_H   = 1.2 * cm   # altura barra de título (líneas + texto)
_INFO_H  = 1.65 * cm  # altura banda informativa
_FOOT_H  = 0.9  * cm  # altura footer

MARG_TOP = _BAR_H + _INFO_H + 0.35 * cm   # ≈ 3.2 cm — topMargin del documento

# ── Colores (re-exportados para uso en scripts si se desea) ──────────────────
AZUL    = colors.HexColor('#1a3566')
GRIS_L  = colors.HexColor('#f3f4f6')
GRIS_M  = colors.HexColor('#d1d5db')
GRIS_T  = colors.HexColor('#6b7280')
GRIS_OS = colors.HexColor('#1f2937')
BLANCO  = colors.white


class _Canvas:
    """
    Dibuja el membrete ejecutivo en cada página del PDF.

    Parámetros
    ----------
    titulo         : Nombre del reporte en texto plano (se pondrá en mayúsculas).
                     Ej.: 'Reporte de Ventas'
    empresa        : Nombre de la empresa / tienda principal.
                     Ej.: 'Compu Space Central'
    periodo        : Rango de fechas como string, o '' si no aplica.
                     Ej.: '01/07/2026 — 08/07/2026'
    filtros        : Información adicional (sucursal, estado, código…).
                     Se muestra en la 3.ª línea del lado derecho. '' = omitir.
    nombre_usuario : Usuario que generó el reporte.
    reporte_id     : ID único  Ej.: 'RPT-20260708-150322'.  '' = omitir.
    logo_path      : Ruta absoluta al logo PNG.  None / ruta inexistente = sin logo.
    """

    def __init__(self, titulo, empresa, periodo, filtros,
                 nombre_usuario, reporte_id, logo_path=None):
        self.titulo         = titulo        or ''
        self.empresa        = empresa       or ''
        self.periodo        = periodo       or ''
        self.filtros        = filtros       or ''
        self.nombre_usuario = nombre_usuario or ''
        self.reporte_id     = reporte_id    or ''
        self.logo_path      = logo_path
        self._pg            = [0]

    # ── Dibuja cabecera y pie en cada página ──────────────────────────────────
    def __call__(self, canvas, doc):
        self._pg[0] += 1
        canvas.saveState()
        w, h = doc.pagesize

        # ── 1. Línea azul superior ────────────────────────────────────────────
        canvas.setStrokeColor(AZUL)
        canvas.setLineWidth(2.5)
        canvas.line(0, h - 2.5 / 72 * 2.54 * cm, w, h - 2.5 / 72 * 2.54 * cm)

        # ── 2. Logo + Título ──────────────────────────────────────────────────
        logo_size = _BAR_H - 0.15 * cm   # ~1.05 cm
        title_x   = MARG_H

        if self.logo_path and os.path.exists(self.logo_path):
            try:
                logo_y = h - _BAR_H + 0.08 * cm
                canvas.drawImage(
                    self.logo_path,
                    MARG_H, logo_y,
                    width=logo_size, height=logo_size,
                    mask='auto', preserveAspectRatio=True
                )
                title_x = MARG_H + logo_size + 0.25 * cm
            except Exception:
                pass   # Si falla la imagen, el título sigue en posición normal

        canvas.setFillColor(AZUL)
        canvas.setFont('Helvetica-Bold', 11.5)
        # Centrar verticalmente en la banda del título
        title_y = h - _BAR_H + (_BAR_H - 0.42 * cm) / 2
        canvas.drawString(title_x, title_y, self.titulo.upper())

        # ID del reporte — esquina superior derecha, texto pequeño
        if self.reporte_id:
            canvas.setFont('Helvetica', 6.5)
            canvas.setFillColor(GRIS_T)
            canvas.drawRightString(w - MARG_H, title_y + 0.05 * cm,
                                   'ID: ' + self.reporte_id)

        # ── 3. Línea azul inferior (debajo del título) ────────────────────────
        sep_y = h - _BAR_H - 0.02 * cm
        canvas.setStrokeColor(AZUL)
        canvas.setLineWidth(1.5)
        canvas.line(0, sep_y, w, sep_y)

        # ── 4. Banda informativa (fondo gris claro) ───────────────────────────
        info_top = sep_y
        info_bot = info_top - _INFO_H

        canvas.setFillColor(GRIS_L)
        canvas.rect(0, info_bot, w, _INFO_H, fill=True, stroke=False)

        # Distribuir 3 líneas dentro de la banda
        dy    = _INFO_H / 3.8
        y_l1  = info_top - dy * 0.85
        y_l2  = y_l1    - dy
        y_l3  = y_l2    - dy

        LBL_W = 1.6 * cm   # ancho aproximado del label
        VAL_X = MARG_H + LBL_W

        # — Columna izquierda: Empresa / Período / Usuario —
        canvas.setFillColor(GRIS_OS)
        canvas.setFont('Helvetica-Bold', 7)
        canvas.drawString(MARG_H, y_l1, 'Empresa:')
        canvas.drawString(MARG_H, y_l2, 'Periodo:')
        canvas.drawString(MARG_H, y_l3, 'Usuario:')

        canvas.setFont('Helvetica', 7)
        canvas.drawString(VAL_X, y_l1, self.empresa  or '—')
        canvas.drawString(VAL_X, y_l2, self.periodo  or '—')
        canvas.drawString(VAL_X, y_l3, self.nombre_usuario or '—')

        # — Columna derecha: Generado / ID / Filtros —
        now_str = datetime.now().strftime('%d/%m/%Y %H:%M')
        canvas.setFont('Helvetica', 7)
        canvas.drawRightString(w - MARG_H, y_l1, 'Generado: ' + now_str)
        if self.reporte_id:
            canvas.drawRightString(w - MARG_H, y_l2, 'ID: ' + self.reporte_id)
        if self.filtros:
            canvas.drawRightString(w - MARG_H, y_l3, self.filtros)

        # Línea divisoria inferior de la banda
        canvas.setStrokeColor(GRIS_M)
        canvas.setLineWidth(0.5)
        canvas.line(0, info_bot, w, info_bot)

        # ── 5. Footer ─────────────────────────────────────────────────────────
        canvas.setFillColor(GRIS_L)
        canvas.rect(0, 0, w, _FOOT_H, fill=True, stroke=False)
        canvas.setStrokeColor(GRIS_M)
        canvas.setLineWidth(0.4)
        canvas.line(0, _FOOT_H, w, _FOOT_H)

        canvas.setFillColor(GRIS_T)
        canvas.setFont('Helvetica', 6.5)
        canvas.drawString(MARG_H, _FOOT_H * 0.38,
                          'Sistema de Ventas — Compu Space')
        canvas.drawCentredString(w / 2, _FOOT_H * 0.38,
                                 'Documento confidencial')
        canvas.drawRightString(w - MARG_H, _FOOT_H * 0.38,
                               'Pag. %d' % self._pg[0])

        canvas.restoreState()
