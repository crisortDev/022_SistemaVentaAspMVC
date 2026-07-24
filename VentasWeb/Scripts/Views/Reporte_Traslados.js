// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — TRASLADOS DE PRODUCTOS
//  Actualizado para flujo multi-producto 4 pasos (Script 230)
//  Estados: Solicitado | Aprobado | Rechazado | Despachado | Completado
// ═══════════════════════════════════════════════════════════

var _datosTraslados = [];

$(document).ready(function () {
    activarMenu("Reportes");

    var hoy = new Date().toISOString().split('T')[0];
    $('#txtFechaInicio').val(hoy);
    $('#txtFechaFin').val(hoy);

    if ($('#cboTienda').is('select')) {
        $.ajax({
            url: $.MisUrls.url._ObtenerTiendas,
            type: 'GET',
            dataType: 'json',
            success: function (data) {
                var $cbo = $('#cboTienda');
                $cbo.empty().append('<option value="0">-- Todas las sucursales --</option>');
                var lista = data.data || data;
                if (lista && lista.length > 0) {
                    $.each(lista, function (i, item) {
                        if (item.Activo)
                            $cbo.append($('<option>').val(item.IdTienda).text(item.Nombre));
                    });
                }
            }
        });
    }
});

// ── Buscar ────────────────────────────────────────────────
$('#btnBuscar').on('click', function () {
    var fi = $('#txtFechaInicio').val();
    var ff = $('#txtFechaFin').val();

    if (!fi || !ff) { Swal.fire('Atención', 'Debe seleccionar un rango de fechas.', 'warning'); return; }
    if (fi > ff)    { Swal.fire('Atención', 'Fecha inicio no puede ser mayor a fecha fin.', 'warning'); return; }

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteTraslados,
        type: 'GET',
        data: { fechainicio: fi, fechafin: ff, idtienda: $('#cboTienda').val(), estadotraslado: $('#cboEstado').val() },
        dataType: 'json',
        beforeSend: function () {
            $('#contenedorTraslados').html('<p class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</p>');
            $('#btnBuscar').prop('disabled', true);
            $('#btnExportarPDF').prop('disabled', true);
            $('#panelKPI').addClass('d-none');
            $('#panelAnalisis').addClass('d-none');
        },
        success: function (data) {
            _datosTraslados = data || [];
            renderizarTodo();
            $('#btnExportarPDF').prop('disabled', _datosTraslados.length === 0);
        },
        error: function () {
            $('#contenedorTraslados').html('<p class="text-danger text-center">Error al cargar los datos.</p>');
            Swal.fire('Error', 'No se pudo obtener el reporte.', 'error');
        },
        complete: function () { $('#btnBuscar').prop('disabled', false); }
    });
});

// ── Dispatcher ────────────────────────────────────────────
function renderizarTodo() {
    if (_datosTraslados.length === 0) {
        $('#contenedorTraslados').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        return;
    }
    renderizarKPIs();
    renderizarEstado();
    renderizarSucursales();
    renderizarTabla();
    $('#panelKPI').removeClass('d-none');
    $('#panelAnalisis').removeClass('d-none');
}

// ══════════════════════════════════════════════════════════
//  KPIs
// ══════════════════════════════════════════════════════════
function renderizarKPIs() {
    var totalTraslados  = _datosTraslados.length;
    var totalUnidades   = _datosTraslados.reduce(function (s, t) { return s + (t.TotalUnidades || 0); }, 0);
    var sucursales      = new Set();
    _datosTraslados.forEach(function (t) {
        if (t.TiendaOrigen)  sucursales.add(t.TiendaOrigen);
        if (t.TiendaDestino) sucursales.add(t.TiendaDestino);
    });

    $('#kpiTraslados').text(totalTraslados);
    $('#kpiProductos').text(totalUnidades);   // ahora = total unidades movilizadas
    $('#kpiSucursales').text(sucursales.size);
}

// ══════════════════════════════════════════════════════════
//  ESTADO DE TRASLADOS
// ══════════════════════════════════════════════════════════
function renderizarEstado() {
    var total      = _datosTraslados.length;
    var estados    = { Solicitado: 0, Aprobado: 0, Despachado: 0, Completado: 0, Rechazado: 0 };

    _datosTraslados.forEach(function (t) {
        var est = t.EstadoAprobacion || 'Solicitado';
        if (estados.hasOwnProperty(est)) estados[est]++;
    });

    function fila(label, n, cls) {
        var pct  = total > 0 ? (n / total * 100).toFixed(1) : '0.0';
        var bars = total > 0 ? Math.round(n / total * 20) : 0;
        var barHtml = bars > 0 ? '<span class="text-' + cls + '">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + label + '</td>' +
               '<td class="text-center font-weight-bold">' + n + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Estado</th><th class="text-center">Cantidad</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>' +
        fila('Solicitados',  estados.Solicitado,  'warning') +
        fila('Aprobados',    estados.Aprobado,    'primary') +
        fila('Despachados',  estados.Despachado,  'info') +
        fila('Completados',  estados.Completado,  'success') +
        fila('Rechazados',   estados.Rechazado,   'danger') +
        '</tbody></table>';

    $('#tablaEstado').html(html);
}

// ══════════════════════════════════════════════════════════
//  SUCURSALES QUE MÁS ENVÍAN
// ══════════════════════════════════════════════════════════
function renderizarSucursales() {
    var mapaSuc = {};
    _datosTraslados.forEach(function (t) {
        var suc = t.TiendaOrigen || '(Sin origen)';
        mapaSuc[suc] = (mapaSuc[suc] || 0) + 1;
    });

    var sorted = Object.keys(mapaSuc).map(function (k) { return { suc: k, cantidad: mapaSuc[k] }; });
    sorted.sort(function (a, b) { return b.cantidad - a.cantidad; });

    var total  = _datosTraslados.length;
    var maxVal = sorted.length > 0 ? sorted[0].cantidad : 1;

    var filas = sorted.map(function (s) {
        var pct  = total > 0 ? (s.cantidad / total * 100).toFixed(1) : '0.0';
        var bars = Math.round(s.cantidad / maxVal * 15);
        var barHtml = bars > 0 ? '<span class="text-info">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + s.suc + '</td>' +
               '<td class="text-center font-weight-bold">' + s.cantidad + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Sucursal</th><th class="text-center">Traslados</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaSucursales').html(html);
}

// ══════════════════════════════════════════════════════════
//  TABLA DETALLE
// ══════════════════════════════════════════════════════════
function renderizarTabla() {
    var estadoClsMap = {
        'Solicitado':  { badge: 'warning',  row: 'table-warning' },
        'Aprobado':    { badge: 'primary',  row: '' },
        'Despachado':  { badge: 'info',     row: '' },
        'Completado':  { badge: 'success',  row: '' },
        'Rechazado':   { badge: 'danger',   row: 'table-danger' }
    };

    var filas = '';
    _datosTraslados.forEach(function (t) {
        var estado   = t.EstadoAprobacion || 'Solicitado';
        var cls      = estadoClsMap[estado] || { badge: 'secondary', row: '' };

        filas += '<tr class="' + cls.row + '">' +
            '<td>' + (t.Numero        || '') + '</td>' +
            '<td>' + (t.FechaTraslado || '') + '</td>' +
            '<td class="text-center">' + (t.CantidadItems  || 0) + '</td>' +
            '<td class="text-center">' + (t.TotalUnidades  || 0) + '</td>' +
            '<td>' + (t.TiendaOrigen  || '') + '</td>' +
            '<td>' + (t.TiendaDestino || '') + '</td>' +
            '<td class="text-center"><span class="badge badge-' + cls.badge + '">' + estado + '</span></td>' +
            '<td class="small">' + (t.Usuario       || '') + '</td>' +
            '<td class="small">' + (t.UsuarioAprueba || '') + '</td>' +
            '</tr>';

        if (estado === 'Rechazado' && t.MotivoRechazo) {
            filas += '<tr class="table-danger"><td colspan="9" class="py-1 pl-4 text-muted small">' +
                '<i class="fas fa-exclamation-circle text-danger mr-1"></i>' +
                '<strong>Motivo:</strong> ' + $('<span>').text(t.MotivoRechazo).html() + '</td></tr>';
        }
    });

    var html = '<h6 class="font-weight-bold text-info border-bottom pb-1 mt-2">' +
        '<i class="fas fa-list mr-1"></i> Detalle Completo</h6>' +
        '<div style="overflow-x:auto;">' +
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Nro</th><th>Fecha</th>' +
        '<th class="text-center">Ítems</th><th class="text-center">Unidades</th>' +
        '<th>Origen</th><th>Destino</th>' +
        '<th class="text-center">Estado</th><th>Registró</th><th>Aprobó</th>' +
        '</tr></thead><tbody>' + filas + '</tbody></table></div>';

    $('#contenedorTraslados').html(html);
}

// ── Exportar PDF ──────────────────────────────────────────
function exportarPDF() {
    if (_datosTraslados.length === 0) {
        Swal.fire('Sin datos', 'No hay datos para exportar.', 'warning');
        return;
    }
    $('#hTrasladoFechaInicio').val($('#txtFechaInicio').val());
    $('#hTrasladoFechaFin').val($('#txtFechaFin').val());
    $('#hTrasladoIdTienda').val($('#cboTienda').val() || 0);
    $('#hTrasladoEstado').val($('#cboEstado').val() || '');
    $('#frmPDFTraslados').submit();
}
