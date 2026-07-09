// ═══════════════════════════════════════════════════════════
//  REPORTE — NOTAS DE CRÉDITO ASOCIADAS
// ═══════════════════════════════════════════════════════════

var _datosNC = [];

$(document).ready(function () {
    activarMenu("Reporte NC");
    cargarCombos();

    // Defaults: primer día del mes actual → hoy
    var hoy = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    $('#txtFechaInicio').val(primerDia.toISOString().slice(0, 10));
    $('#txtFechaFin').val(hoy.toISOString().slice(0, 10));
});

// ── Cargar combos Proveedor y Tienda ─────────────────────
function cargarCombos() {
    $.get($.MisUrls.url._Reporte_ProveedoresCombo, function (res) {
        var opts = '<option value="0">-- Todos los proveedores --</option>';
        (res.data || []).forEach(function (p) {
            opts += '<option value="' + p.IdProveedor + '">' + p.RazonSocial + ' (' + p.Ruc + ')</option>';
        });
        $('#cboProveedor').html(opts);
    });

    $.get($.MisUrls.url._Inv_ObtenerTiendas, function (res) {
        var opts = '<option value="0">-- Todas --</option>';
        (res.data || []).forEach(function (t) {
            if (t.Activo) opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $('#cboTienda').html(opts);
    });
}

// ── Buscar ────────────────────────────────────────────────
function buscarNC() {
    var fi = $('#txtFechaInicio').val();
    var ff = $('#txtFechaFin').val();

    if (!fi || !ff) {
        Swal.fire('Atención', 'Debe seleccionar un rango de fechas.', 'warning');
        return;
    }
    if (fi > ff) {
        Swal.fire('Atención', 'La fecha inicio no puede ser mayor a la fecha fin.', 'warning');
        return;
    }

    var params = {
        fechainicio: fi,
        fechafin:    ff,
        idproveedor: parseInt($('#cboProveedor').val()) || 0,
        idtienda:    parseInt($('#cboTienda').val())    || 0,
        estado:      $('#cboEstado').val()
    };

    $('body').LoadingOverlay('show');

    $.get($.MisUrls.url._Reporte_ObtenerNC, params, function (res) {
        _datosNC = res.data || [];
        renderizarTablaNC();
        $('#btnExportarPDF').prop('disabled', _datosNC.length === 0);
    }).fail(function () {
        $('#contenedorNC').html('<p class="text-danger">Error al cargar el reporte.</p>');
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Renderizar tabla ──────────────────────────────────────
function renderizarTablaNC() {
    if (_datosNC.length === 0) {
        $('#contenedorNC').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        $('#panelTotalesNC').addClass('d-none');
        return;
    }

    var totalMonto = 0, totalPendientes = 0, totalMorosas = 0;

    var filas = '';
    _datosNC.forEach(function (nc) {
        var badgeEstado = nc.Estado === 'Recibida'  ? 'badge-success'
                        : nc.Estado === 'Rechazada' ? 'badge-danger'
                        : 'badge-secondary';

        var morosaBadge = nc.EsMorosa
            ? ' <span class="badge badge-warning text-dark ml-1"><i class="fas fa-exclamation-triangle"></i> Morosa</span>'
            : '';

        totalMonto += nc.MontoNC;
        if (nc.Estado === 'Pendiente') totalPendientes++;
        if (nc.EsMorosa) totalMorosas++;

        filas +=
            '<tr class="' + (nc.EsMorosa ? 'table-warning' : '') + '">' +
            '<td>' + nc.FechaRegistro + '</td>' +
            '<td>' + nc.Proveedor + '<br><small class="text-muted">' + nc.RucProveedor + '</small></td>' +
            '<td>' + nc.Tienda + '</td>' +
            '<td class="text-center">' + nc.NumeroFactura + '<br><small class="text-muted">' + nc.FechaFactura + '</small></td>' +
            '<td class="text-center">' + (nc.NumeroNC || '<em class="text-muted">—</em>') + '</td>' +
            '<td class="text-center">' + (nc.FechaEmision || '—') + '</td>' +
            '<td class="text-right font-weight-bold">Gs. ' + formatGS(nc.MontoNC) + '</td>' +
            '<td class="text-center"><span class="badge ' + badgeEstado + '">' + nc.Estado + '</span>' + morosaBadge + '</td>' +
            '<td class="text-muted small">' + (nc.MotivoNC || '—') + '</td>' +
            '</tr>';
    });

    var html =
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark">' +
        '<tr>' +
        '<th>Fecha Registro</th>' +
        '<th>Proveedor</th>' +
        '<th>Tienda</th>' +
        '<th class="text-center">Factura / Fecha</th>' +
        '<th class="text-center">N° NC</th>' +
        '<th class="text-center">Fecha Emisión</th>' +
        '<th class="text-right">Monto NC</th>' +
        '<th class="text-center">Estado</th>' +
        '<th>Motivo</th>' +
        '</tr>' +
        '</thead>' +
        '<tbody>' + filas + '</tbody>' +
        '</table>';

    $('#contenedorNC').html(html);

    // Panel totales
    $('#tdTotalNCs').text(_datosNC.length + ' NC(s)');
    $('#tdMontoTotal').text('Gs. ' + formatGS(totalMonto));
    $('#tdPendientes').text(totalPendientes);
    $('#tdMorosas').text(totalMorosas);
    $('#panelTotalesNC').removeClass('d-none');
}

// ── Formatear números al estilo PY: 1.000.000 ─────────────
function formatGS(n) {
    return Number(n).toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

// ══════════════════════════════════════════════════════════
//  EXPORTAR PDF (Python backend — con membrete y logo)
// ══════════════════════════════════════════════════════════
function exportarPDF() {
    if (_datosNC.length === 0) {
        Swal.fire({ title: 'Sin datos', text: 'No hay datos para exportar.', icon: 'warning' });
        return;
    }

    $('#hNcFechaInicio').val($('#txtFechaInicio').val());
    $('#hNcFechaFin').val($('#txtFechaFin').val());
    $('#hNcIdProveedor').val(parseInt($('#cboProveedor').val()) || 0);
    $('#hNcIdTienda').val(parseInt($('#cboTienda').val())    || 0);
    $('#hNcEstado').val($('#cboEstado').val());
    $('#frmPDFNC').submit();
}
