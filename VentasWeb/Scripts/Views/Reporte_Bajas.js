// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — BAJAS DE PRODUCTOS
// ═══════════════════════════════════════════════════════════

var _datosBajas = [];

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
        url: $.MisUrls.url._ObtenerReporteBajas,
        type: 'GET',
        data: { fechainicio: fi, fechafin: ff, idtienda: $('#cboTienda').val(), estadobaja: $('#cboEstado').val() },
        dataType: 'json',
        beforeSend: function () {
            $('#contenedorBajas').html('<p class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</p>');
            $('#btnBuscar').prop('disabled', true);
            $('#btnExportarPDF').prop('disabled', true);
            $('#panelKPI').addClass('d-none');
            $('#panelAnalisis').addClass('d-none');
        },
        success: function (data) {
            _datosBajas = data || [];
            renderizarTodo();
            $('#btnExportarPDF').prop('disabled', _datosBajas.length === 0);
        },
        error: function () {
            $('#contenedorBajas').html('<p class="text-danger text-center">Error al cargar los datos.</p>');
            Swal.fire('Error', 'No se pudo obtener el reporte.', 'error');
        },
        complete: function () { $('#btnBuscar').prop('disabled', false); }
    });
});

// ── Dispatcher ────────────────────────────────────────────
function renderizarTodo() {
    if (_datosBajas.length === 0) {
        $('#contenedorBajas').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        return;
    }
    renderizarKPIs();
    renderizarEstado();
    renderizarMotivos();
    renderizarTopProductos();
    renderizarTabla();
    $('#panelKPI').removeClass('d-none');
    $('#panelAnalisis').removeClass('d-none');
}

// ══════════════════════════════════════════════════════════
//  KPIs
// ══════════════════════════════════════════════════════════
function renderizarKPIs() {
    var solicitudes = _datosBajas.length;
    var unidades    = _datosBajas.reduce(function(s,b){ return s + (b.Cantidad||0); }, 0);
    var productos   = new Set(_datosBajas.map(function(b){ return b.CodigoProducto; })).size;
    var costo       = _datosBajas.reduce(function(s,b){ return s + (b.Cantidad||0) * (b.CostoPromedio||0); }, 0);

    $('#kpiSolicitudes').text(solicitudes);
    $('#kpiUnidades').text(unidades);
    $('#kpiProductos').text(productos);
    $('#kpiCosto').text('Gs. ' + fmtGS(costo));
}

// ══════════════════════════════════════════════════════════
//  ESTADO DE SOLICITUDES
// ══════════════════════════════════════════════════════════
function renderizarEstado() {
    var total    = _datosBajas.length;
    var aprobadas  = _datosBajas.filter(function(b){ return b.EstadoAprobacion === 'Aprobada'; }).length;
    var pendientes = _datosBajas.filter(function(b){ return b.EstadoAprobacion === 'Pendiente'; }).length;
    var rechazadas = _datosBajas.filter(function(b){ return b.EstadoAprobacion === 'Rechazada'; }).length;

    function fila(label, n, cls) {
        var pct  = total > 0 ? (n / total * 100).toFixed(1) : '0.0';
        var bars = Math.round(n / total * 20);
        var barHtml = bars > 0 ? '<span class="text-' + cls + '">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + label + '</td>' +
               '<td class="text-center font-weight-bold">' + n + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Estado</th><th class="text-center">Cantidad</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>' +
        fila('Aprobadas',  aprobadas,  'success') +
        fila('Pendientes', pendientes, 'warning') +
        fila('Rechazadas', rechazadas, 'danger') +
        '</tbody></table>';

    $('#tablaEstado').html(html);
}

// ══════════════════════════════════════════════════════════
//  MOTIVOS DE BAJA
// ══════════════════════════════════════════════════════════
function renderizarMotivos() {
    var mapaMotivos = {};
    _datosBajas.forEach(function(b) {
        var motivo = b.MotivoBaja || 'Sin motivo';
        mapaMotivos[motivo] = (mapaMotivos[motivo] || 0) + (b.Cantidad || 0);
    });

    var sorted = Object.keys(mapaMotivos).map(function(m){ return { motivo: m, cantidad: mapaMotivos[m] }; });
    sorted.sort(function(a,b){ return b.cantidad - a.cantidad; });

    var total  = sorted.reduce(function(s,m){ return s + m.cantidad; }, 0);
    var maxVal = sorted.length > 0 ? sorted[0].cantidad : 1;

    var filas = sorted.map(function(m) {
        var pct  = total > 0 ? (m.cantidad / total * 100).toFixed(1) : '0.0';
        var bars = Math.round(m.cantidad / maxVal * 15);
        var barHtml = bars > 0 ? '<span class="text-danger">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + m.motivo + '</td>' +
               '<td class="text-center font-weight-bold">' + m.cantidad + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Motivo</th><th class="text-center">Unidades</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaMotivos').html(html);
}

// ══════════════════════════════════════════════════════════
//  TOP 5 PRODUCTOS
// ══════════════════════════════════════════════════════════
function renderizarTopProductos() {
    var mapaProds = {};
    _datosBajas.forEach(function(b) {
        var key = b.CodigoProducto || '—';
        if (!mapaProds[key]) mapaProds[key] = { nombre: b.NombreProducto || key, cantidad: 0 };
        mapaProds[key].cantidad += (b.Cantidad || 0);
    });

    var sorted = Object.keys(mapaProds).map(function(k){ return mapaProds[k]; });
    sorted.sort(function(a,b){ return b.cantidad - a.cantidad; });
    var top5   = sorted.slice(0, 5);
    var total  = _datosBajas.reduce(function(s,b){ return s + (b.Cantidad||0); }, 0);
    var maxVal = top5.length > 0 ? top5[0].cantidad : 1;

    var filas = top5.map(function(p, i) {
        var pct  = total > 0 ? (p.cantidad / total * 100).toFixed(1) : '0.0';
        var bars = Math.round(p.cantidad / maxVal * 20);
        var barHtml = bars > 0 ? '<span class="text-warning">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr>' +
            '<td class="text-center font-weight-bold">' + (i+1) + '</td>' +
            '<td>' + p.nombre + '</td>' +
            '<td class="text-center font-weight-bold">' + p.cantidad + '</td>' +
            '<td class="text-center">' + pct + '%</td>' +
            '<td>' + barHtml + '</td>' +
            '</tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered table-hover" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th class="text-center">#</th><th>Producto</th>' +
        '<th class="text-center">Unidades</th><th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaTopProductos').html(html);
}

// ══════════════════════════════════════════════════════════
//  TABLA DETALLE
// ══════════════════════════════════════════════════════════
function renderizarTabla() {
    var mostrarTienda = !$('#cboTienda').val() || $('#cboTienda').val() === '0';

    var filas = '';
    _datosBajas.forEach(function (b) {
        var estado   = b.EstadoAprobacion || 'Pendiente';
        var badgeCls = estado === 'Aprobada' ? 'success' : estado === 'Rechazada' ? 'danger' : 'warning';
        var rowClass = estado === 'Pendiente' ? 'table-warning' : estado === 'Rechazada' ? 'table-danger' : '';

        filas += '<tr class="' + rowClass + '">';
        if (mostrarTienda) filas += '<td class="small">' + (b.NombreTienda || '—') + '</td>';
        filas +=
            '<td>' + (b.Numero || '') + '</td>' +
            '<td>' + (b.FechaMovimiento || '') + '</td>' +
            '<td>' + (b.CodigoProducto || '') + '</td>' +
            '<td>' + (b.NombreProducto || '') + '</td>' +
            '<td class="text-center">' + (b.Cantidad || 0) + '</td>' +
            '<td>' + (b.MotivoBaja || '') + '</td>' +
            '<td class="text-center"><span class="badge badge-' + badgeCls + '">' + estado + '</span></td>' +
            '<td class="small">' + (b.UsuarioRegistro || '') + '</td>' +
            '<td class="small">' + (b.UsuarioAprueba || '') + '</td>' +
            '</tr>';

        if (estado === 'Rechazada' && b.MotivoRechazo) {
            var cols = mostrarTienda ? 10 : 9;
            filas += '<tr class="table-danger"><td colspan="' + cols + '" class="py-1 pl-4 text-muted small">' +
                '<i class="fas fa-exclamation-circle text-danger mr-1"></i>' +
                '<strong>Motivo:</strong> ' + $('<span>').text(b.MotivoRechazo).html() + '</td></tr>';
        }
    });

    var thTienda = mostrarTienda ? '<th>Sucursal</th>' : '';
    var cols = mostrarTienda ? 10 : 9;

    var html = '<h6 class="font-weight-bold text-danger border-bottom pb-1 mt-2">' +
        '<i class="fas fa-list mr-1"></i> Detalle Completo</h6>' +
        '<div style="overflow-x:auto;">' +
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark"><tr>' +
        thTienda +
        '<th>Nro</th><th>Fecha</th><th>Código</th><th>Producto</th>' +
        '<th class="text-center">Cant.</th><th>Motivo</th>' +
        '<th class="text-center">Estado</th><th>Registró</th><th>Aprobó</th>' +
        '</tr></thead><tbody>' + filas + '</tbody></table></div>';

    $('#contenedorBajas').html(html);
}

// ── Helpers ───────────────────────────────────────────────
function fmtGS(n) {
    return Number(n || 0).toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

// ── Exportar PDF ──────────────────────────────────────────
function exportarPDF() {
    if (_datosBajas.length === 0) {
        Swal.fire('Sin datos', 'No hay datos para exportar.', 'warning');
        return;
    }
    $('#hBajasFechaInicio').val($('#txtFechaInicio').val());
    $('#hBajasFechaFin').val($('#txtFechaFin').val());
    $('#hBajasIdTienda').val($('#cboTienda').val() || 0);
    $('#hBajasEstado').val($('#cboEstado').val() || '');
    $('#frmPDFBajas').submit();
}
