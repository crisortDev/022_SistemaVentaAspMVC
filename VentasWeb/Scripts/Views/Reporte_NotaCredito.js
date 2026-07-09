// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — NOTAS DE CRÉDITO
// ═══════════════════════════════════════════════════════════

var _datosNC = [];

$(document).ready(function () {
    activarMenu("Reporte NC");
    cargarCombos();

    var hoy = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    $('#txtFechaInicio').val(primerDia.toISOString().slice(0, 10));
    $('#txtFechaFin').val(hoy.toISOString().slice(0, 10));
});

// ── Cargar combos ──────────────────────────────────────────
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
        if ($('#cboTienda').is('select')) $('#cboTienda').html(opts);
    });
}

// ── Buscar ─────────────────────────────────────────────────
$('#btnBuscar').on('click', function () {
    var fi = $('#txtFechaInicio').val();
    var ff = $('#txtFechaFin').val();

    if (!fi || !ff) { Swal.fire('Atención', 'Debe seleccionar un rango de fechas.', 'warning'); return; }
    if (fi > ff)    { Swal.fire('Atención', 'La fecha inicio no puede ser mayor a la fecha fin.', 'warning'); return; }

    $.ajax({
        url: $.MisUrls.url._Reporte_ObtenerNC,
        type: 'GET',
        data: {
            fechainicio: fi,
            fechafin:    ff,
            idproveedor: parseInt($('#cboProveedor').val()) || 0,
            idtienda:    parseInt($('#cboTienda').val())    || 0,
            estado:      $('#cboEstado').val()
        },
        dataType: 'json',
        beforeSend: function () {
            $('#contenedorNC').html('<p class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</p>');
            $('#btnBuscar').prop('disabled', true);
            $('#btnExportarPDF').prop('disabled', true);
            $('#panelKPI').addClass('d-none');
            $('#panelAnalisis').addClass('d-none');
        },
        success: function (res) {
            _datosNC = res.data || [];
            renderizarTodo();
            $('#btnExportarPDF').prop('disabled', _datosNC.length === 0);
        },
        error: function () {
            $('#contenedorNC').html('<p class="text-danger text-center">Error al cargar el reporte.</p>');
            Swal.fire('Error', 'No se pudo obtener el reporte.', 'error');
        },
        complete: function () { $('#btnBuscar').prop('disabled', false); }
    });
});

// ── Dispatcher ─────────────────────────────────────────────
function renderizarTodo() {
    if (_datosNC.length === 0) {
        $('#contenedorNC').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        return;
    }
    renderizarKPIs();
    renderizarEstado();
    renderizarProveedores();
    renderizarMotivos();
    renderizarImpacto();
    renderizarAnalisis();
    renderizarTabla();
    $('#panelKPI').removeClass('d-none');
    $('#panelAnalisis').removeClass('d-none');
}

// ══════════════════════════════════════════════════════════
//  KPIs
// ══════════════════════════════════════════════════════════
function renderizarKPIs() {
    var total      = _datosNC.length;
    var montoTotal = _datosNC.reduce(function(s, nc){ return s + (nc.MontoNC || 0); }, 0);
    var proveedores= new Set(_datosNC.map(function(nc){ return nc.Proveedor; })).size;
    var promedio   = total > 0 ? montoTotal / total : 0;
    var recibidas  = _datosNC.filter(function(nc){ return nc.Estado === 'Recibida';  }).length;
    var pendientes = _datosNC.filter(function(nc){ return nc.Estado === 'Pendiente'; }).length;

    // Motivo principal
    var mapaMotivos = {};
    _datosNC.forEach(function(nc) {
        var m = nc.MotivoNC || 'Sin motivo';
        mapaMotivos[m] = (mapaMotivos[m] || 0) + 1;
    });
    var motivoKeys = Object.keys(mapaMotivos).sort(function(a, b){ return mapaMotivos[b] - mapaMotivos[a]; });
    var motivoPpal = motivoKeys[0] || '—';
    var pctMotivo  = total > 0 ? (mapaMotivos[motivoPpal] / total * 100).toFixed(1) : '0.0';

    // Mayor proveedor por monto
    var mapaProvs = {};
    _datosNC.forEach(function(nc) {
        var p = nc.Proveedor || '—';
        mapaProvs[p] = (mapaProvs[p] || 0) + (nc.MontoNC || 0);
    });
    var mayorProv = Object.keys(mapaProvs).sort(function(a, b){ return mapaProvs[b] - mapaProvs[a]; })[0] || '—';

    var pctRec  = total > 0 ? (recibidas  / total * 100).toFixed(1) : '0.0';
    var pctPend = total > 0 ? (pendientes / total * 100).toFixed(1) : '0.0';

    $('#kpiTotalNC').text(total);
    $('#kpiMontoTotal').text('Gs. ' + fmtGS(montoTotal));
    $('#kpiProveedores').text(proveedores);
    $('#kpiPromedio').text('Gs. ' + fmtGS(promedio));
    $('#kpiRecibidas').text(recibidas  + ' (' + pctRec  + '%)');
    $('#kpiPendientes').text(pendientes + ' (' + pctPend + '%)');
    $('#kpiMotivoPrincipal').text(motivoPpal + ' (' + pctMotivo + '%)');
    $('#kpiMayorProveedor').text(mayorProv);
}

// ══════════════════════════════════════════════════════════
//  ESTADO
// ══════════════════════════════════════════════════════════
function renderizarEstado() {
    var total      = _datosNC.length;
    var recibidas  = _datosNC.filter(function(nc){ return nc.Estado === 'Recibida';  }).length;
    var pendientes = _datosNC.filter(function(nc){ return nc.Estado === 'Pendiente'; }).length;
    var rechazadas = _datosNC.filter(function(nc){ return nc.Estado === 'Rechazada'; }).length;

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
        fila('Recibidas',  recibidas,  'success') +
        fila('Pendientes', pendientes, 'secondary') +
        fila('Rechazadas', rechazadas, 'danger') +
        '</tbody></table>';

    $('#tablaEstado').html(html);
}

// ══════════════════════════════════════════════════════════
//  TOP PROVEEDORES POR MONTO
// ══════════════════════════════════════════════════════════
function renderizarProveedores() {
    var mapaProvs = {};
    _datosNC.forEach(function(nc) {
        var p = nc.Proveedor || 'Sin proveedor';
        if (!mapaProvs[p]) mapaProvs[p] = { cantidad: 0, monto: 0 };
        mapaProvs[p].cantidad++;
        mapaProvs[p].monto += (nc.MontoNC || 0);
    });

    var sorted = Object.keys(mapaProvs).map(function(k){
        return { prov: k, cantidad: mapaProvs[k].cantidad, monto: mapaProvs[k].monto };
    });
    sorted.sort(function(a, b){ return b.monto - a.monto; });

    var montoTotal = _datosNC.reduce(function(s, nc){ return s + (nc.MontoNC || 0); }, 0);
    var maxMonto   = sorted.length > 0 ? sorted[0].monto : 1;

    var filas = sorted.map(function(p) {
        var pct  = montoTotal > 0 ? (p.monto / montoTotal * 100).toFixed(1) : '0.0';
        var bars = Math.round(p.monto / maxMonto * 15);
        var barHtml = bars > 0 ? '<span class="text-warning">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + p.prov + '</td>' +
               '<td class="text-center">' + p.cantidad + '</td>' +
               '<td class="text-right font-weight-bold">Gs. ' + fmtGS(p.monto) + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Proveedor</th><th class="text-center">Cant.</th>' +
        '<th class="text-right">Monto</th><th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaProveedores').html(html);
}

// ══════════════════════════════════════════════════════════
//  MOTIVOS
// ══════════════════════════════════════════════════════════
function renderizarMotivos() {
    var mapaMotivos = {};
    _datosNC.forEach(function(nc) {
        var m = nc.MotivoNC || 'Sin motivo';
        mapaMotivos[m] = (mapaMotivos[m] || 0) + 1;
    });

    var sorted = Object.keys(mapaMotivos).map(function(k){
        return { motivo: k, cantidad: mapaMotivos[k] };
    });
    sorted.sort(function(a, b){ return b.cantidad - a.cantidad; });

    var total  = _datosNC.length;
    var maxVal = sorted.length > 0 ? sorted[0].cantidad : 1;

    var filas = sorted.map(function(m) {
        var pct  = total > 0 ? (m.cantidad / total * 100).toFixed(1) : '0.0';
        var bars = Math.round(m.cantidad / maxVal * 15);
        var barHtml = bars > 0 ? '<span class="text-warning">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + m.motivo + '</td>' +
               '<td class="text-center font-weight-bold">' + m.cantidad + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Motivo</th><th class="text-center">Cantidad</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaMotivos').html(html);
}

// ══════════════════════════════════════════════════════════
//  IMPACTO ECONÓMICO
// ══════════════════════════════════════════════════════════
function renderizarImpacto() {
    var total      = _datosNC.length;
    var montoTotal = _datosNC.reduce(function(s, nc){ return s + (nc.MontoNC || 0); }, 0);
    var mayorNC    = total > 0 ? Math.max.apply(null, _datosNC.map(function(nc){ return nc.MontoNC || 0; })) : 0;
    var promedio   = total > 0 ? montoTotal / total : 0;

    function fila(label, valor, cls) {
        var pct  = montoTotal > 0 ? (valor / montoTotal * 100).toFixed(1) : '0.0';
        var bars = montoTotal > 0 ? Math.round(valor / montoTotal * 15) : 0;
        var barHtml = bars > 0 ? '<span class="text-' + cls + '">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr><td>' + label + '</td>' +
               '<td class="text-right font-weight-bold">Gs. ' + fmtGS(valor) + '</td>' +
               '<td class="text-center">' + pct + '%</td>' +
               '<td>' + barHtml + '</td></tr>';
    }

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Concepto</th><th class="text-right">Valor</th>' +
        '<th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>' +
        fila('Monto Total NC',      montoTotal, 'success') +
        fila('Mayor NC Individual', mayorNC,    'warning') +
        fila('Promedio por NC',     promedio,   'info') +
        '</tbody></table>';

    $('#tablaImpacto').html(html);
}

// ══════════════════════════════════════════════════════════
//  ANÁLISIS GERENCIAL
// ══════════════════════════════════════════════════════════
function renderizarAnalisis() {
    var total      = _datosNC.length;
    var montoTotal = _datosNC.reduce(function(s, nc){ return s + (nc.MontoNC || 0); }, 0);
    var recibidas  = _datosNC.filter(function(nc){ return nc.Estado === 'Recibida'; }).length;

    var mapaProvs = {};
    _datosNC.forEach(function(nc) {
        var p = nc.Proveedor || '—';
        mapaProvs[p] = (mapaProvs[p] || 0) + (nc.MontoNC || 0);
    });
    var mayorProv = Object.keys(mapaProvs).sort(function(a, b){ return mapaProvs[b] - mapaProvs[a]; })[0] || '—';

    function fila(aspecto, resultado) {
        return '<tr><td class="font-weight-bold" style="width:50%;">' + aspecto + '</td><td>' + resultado + '</td></tr>';
    }

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Aspecto</th><th>Resultado</th></tr></thead><tbody>' +
        fila('Total de NC recibidas',              recibidas) +
        fila('Monto total recuperado',             'Gs. ' + fmtGS(montoTotal)) +
        fila('Proveedor con mayor monto acumulado', mayorProv) +
        '</tbody></table>';

    $('#tablaAnalisis').html(html);
}

// ══════════════════════════════════════════════════════════
//  TABLA DETALLE
// ══════════════════════════════════════════════════════════
function renderizarTabla() {
    var filas = '';
    _datosNC.forEach(function (nc) {
        var badgeEstado = nc.Estado === 'Recibida'  ? 'success'
                        : nc.Estado === 'Rechazada' ? 'danger'
                        : 'secondary';
        var morosaBadge = nc.EsMorosa
            ? ' <span class="badge badge-warning text-dark ml-1"><i class="fas fa-exclamation-triangle"></i> Morosa</span>'
            : '';

        filas +=
            '<tr class="' + (nc.EsMorosa ? 'table-warning' : '') + '">' +
            '<td>' + (nc.FechaRegistro || '') + '</td>' +
            '<td>' + (nc.Proveedor || '') + '<br><small class="text-muted">' + (nc.RucProveedor || '') + '</small></td>' +
            '<td>' + (nc.Tienda || '') + '</td>' +
            '<td class="text-center">' + (nc.NumeroFactura || '—') + '<br><small class="text-muted">' + (nc.FechaFactura || '') + '</small></td>' +
            '<td class="text-center">' + (nc.NumeroNC || '<em class="text-muted">—</em>') + '</td>' +
            '<td class="text-center">' + (nc.FechaEmision || '—') + '</td>' +
            '<td class="text-right font-weight-bold">Gs. ' + fmtGS(nc.MontoNC) + '</td>' +
            '<td class="text-center"><span class="badge badge-' + badgeEstado + '">' + nc.Estado + '</span>' + morosaBadge + '</td>' +
            '<td class="small">' + (nc.MotivoNC || '—') + '</td>' +
            '</tr>';
    });

    var html = '<h6 class="font-weight-bold text-warning border-bottom pb-1 mt-2">' +
        '<i class="fas fa-list mr-1"></i> Detalle Completo</h6>' +
        '<div style="overflow-x:auto;">' +
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Fecha Reg.</th><th>Proveedor</th><th>Tienda</th>' +
        '<th class="text-center">Factura / Fecha</th>' +
        '<th class="text-center">N° NC</th>' +
        '<th class="text-center">Fecha Emisión</th>' +
        '<th class="text-right">Monto NC</th>' +
        '<th class="text-center">Estado</th>' +
        '<th>Motivo</th>' +
        '</tr></thead><tbody>' + filas + '</tbody></table></div>';

    $('#contenedorNC').html(html);
}

// ── Helpers ───────────────────────────────────────────────
function fmtGS(n) {
    return Number(n || 0).toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

// ── Exportar PDF ──────────────────────────────────────────
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
