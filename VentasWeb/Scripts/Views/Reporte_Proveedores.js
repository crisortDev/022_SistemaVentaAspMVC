// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — PROVEEDORES
// ═══════════════════════════════════════════════════════════

var _datosProv = [];

$(document).ready(function () {
    activarMenu("Reporte Proveedores");
    cargarTiendas();

    // Defaults: primer día del mes → hoy
    var hoy = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    $('#txtFechaInicio').val(primerDia.toISOString().slice(0, 10));
    $('#txtFechaFin').val(hoy.toISOString().slice(0, 10));
});

// ── Cargar combo Tiendas ──────────────────────────────────
function cargarTiendas() {
    $.get($.MisUrls.url._Inv_ObtenerTiendas, function (res) {
        var opts = '<option value="0">-- Todas las sucursales --</option>';
        (res.data || []).forEach(function (t) {
            if (t.Activo) opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $('#cboTienda').html(opts);
    });
}

// ── Buscar ────────────────────────────────────────────────
function buscarProveedores() {
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
        idtienda:    parseInt($('#cboTienda').val()) || 0,
        solodeuda:   $('#cboFiltro').val() === '1'
    };

    $('body').LoadingOverlay('show');

    $.get($.MisUrls.url._Reporte_ObtenerProveedores, params, function (res) {
        _datosProv = res.data || [];
        renderizarTodo();
        $('#btnExportarPDF').prop('disabled', _datosProv.length === 0);
    }).fail(function () {
        $('#contenedorProveedores').html('<p class="text-danger">Error al cargar el reporte.</p>');
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Dispatcher ────────────────────────────────────────────
function renderizarTodo() {
    if (_datosProv.length === 0) {
        $('#panelKPI').addClass('d-none');
        $('#panelAnalisis').addClass('d-none');
        $('#contenedorProveedores').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        return;
    }
    renderizarKPIs();
    renderizarEstadoFinanciero();
    renderizarTopProveedores();
    renderizarDistribucionNC();
    renderizarAnalisis();
    renderizarTabla();
    $('#panelKPI').removeClass('d-none');
    $('#panelAnalisis').removeClass('d-none');
}

// ══════════════════════════════════════════════════════════
//  KPIs
// ══════════════════════════════════════════════════════════
function renderizarKPIs() {
    var totalProveedores = _datosProv.length;
    var totalCompras     = _datosProv.reduce(function(s,p){ return s + (p.CantidadCompras || 0); }, 0);
    var montoComprado    = _datosProv.reduce(function(s,p){ return s + (p.TotalCompras    || 0); }, 0);
    var totalNC          = _datosProv.reduce(function(s,p){ return s + (p.CantidadNC      || 0); }, 0);
    var montoNC          = _datosProv.reduce(function(s,p){ return s + (p.TotalMontoNC    || 0); }, 0);
    var saldoNeto        = _datosProv.reduce(function(s,p){ return s + (p.MontoNeto       || 0); }, 0);

    $('#kpiProveedores').text(totalProveedores);
    $('#kpiCompras').text(totalCompras);
    $('#kpiMontoComprado').text('Gs. ' + fmtGS(montoComprado));
    $('#kpiNC').text(totalNC);
    $('#kpiMontoNC').text('Gs. ' + fmtGS(montoNC));
    $('#kpiSaldoNeto').text('Gs. ' + fmtGS(saldoNeto));
}

// ══════════════════════════════════════════════════════════
//  ESTADO FINANCIERO
// ══════════════════════════════════════════════════════════
function renderizarEstadoFinanciero() {
    var total       = _datosProv.length;
    var sinMora     = _datosProv.filter(function(p){ return !p.TieneMorosa; }).length;
    var conMora     = total - sinMora;
    var saldoPos    = _datosProv.filter(function(p){ return (p.MontoNeto || 0) >= 0; }).length;
    var saldoNeg    = total - saldoPos;

    function fila(label, n, cls) {
        var pct = total > 0 ? (n / total * 100).toFixed(1) : '0.0';
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
        fila('Sin mora',        sinMora, 'success') +
        fila('Con NC vencida',  conMora, 'danger') +
        fila('Saldo positivo',  saldoPos,'info') +
        fila('Saldo negativo',  saldoNeg,'warning') +
        '</tbody></table>';

    $('#tablaEstadoFinanciero').html(html);
}

// ══════════════════════════════════════════════════════════
//  TOP PROVEEDORES
// ══════════════════════════════════════════════════════════
function renderizarTopProveedores() {
    var sorted = _datosProv.slice().sort(function(a,b){ return (b.TotalCompras||0) - (a.TotalCompras||0); });
    var total  = sorted.reduce(function(s,p){ return s + (p.TotalCompras||0); }, 0);
    var maxVal = sorted.length > 0 ? (sorted[0].TotalCompras || 0) : 1;

    var filas = sorted.map(function(p) {
        var pct  = total > 0 ? (p.TotalCompras / total * 100).toFixed(1) : '0.0';
        var bars = Math.round((p.TotalCompras || 0) / maxVal * 20);
        var barHtml = bars > 0 ? '<span class="text-info">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr>' +
            '<td>' + p.Proveedor + '</td>' +
            '<td class="text-right font-weight-bold">Gs. ' + fmtGS(p.TotalCompras) + '</td>' +
            '<td class="text-center">' + pct + '%</td>' +
            '<td>' + barHtml + '</td>' +
            '</tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered table-hover" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Proveedor</th><th class="text-right">Compras</th>' +
        '<th class="text-center">% Total</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaTopProveedores').html(html);
}

// ══════════════════════════════════════════════════════════
//  DISTRIBUCIÓN NC
// ══════════════════════════════════════════════════════════
function renderizarDistribucionNC() {
    var conNC = _datosProv.filter(function(p){ return (p.CantidadNC || 0) > 0; });
    conNC.sort(function(a,b){ return (b.TotalMontoNC||0) - (a.TotalMontoNC||0); });

    if (conNC.length === 0) {
        $('#tablaDistribucionNC').html('<p class="text-muted small">Sin notas de crédito en el período.</p>');
        return;
    }

    var totalNC  = conNC.reduce(function(s,p){ return s + (p.TotalMontoNC||0); }, 0);
    var maxMonto = conNC[0].TotalMontoNC || 1;

    var filas = conNC.map(function(p) {
        var pct  = totalNC > 0 ? (p.TotalMontoNC / totalNC * 100).toFixed(1) : '0.0';
        var bars = Math.round((p.TotalMontoNC||0) / maxMonto * 15);
        var barHtml = bars > 0 ? '<span class="text-warning">' + '█'.repeat(bars) + '</span>' : '';
        return '<tr>' +
            '<td>' + p.Proveedor + '</td>' +
            '<td class="text-center">' + (p.CantidadNC||0) + '</td>' +
            '<td class="text-right">Gs. ' + fmtGS(p.TotalMontoNC) + '</td>' +
            '<td class="text-center">' + pct + '%</td>' +
            '<td>' + barHtml + '</td>' +
            '</tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Proveedor</th><th class="text-center">NC</th>' +
        '<th class="text-right">Monto NC</th><th class="text-center">%</th><th>Gráfico</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaDistribucionNC').html(html);
}

// ══════════════════════════════════════════════════════════
//  ANÁLISIS GERENCIAL
// ══════════════════════════════════════════════════════════
function renderizarAnalisis() {
    var sorted       = _datosProv.slice().sort(function(a,b){ return (b.TotalCompras||0)-(a.TotalCompras||0); });
    var top1         = sorted.length > 0 ? sorted[0].Proveedor : '—';
    var top2         = sorted.length > 1 ? sorted[1].Proveedor : '—';
    var pctTop2      = 0;

    var totalMonto = _datosProv.reduce(function(s,p){ return s + (p.TotalCompras||0); }, 0);
    if (sorted.length >= 2 && totalMonto > 0) {
        pctTop2 = ((sorted[0].TotalCompras + sorted[1].TotalCompras) / totalMonto * 100).toFixed(1);
    }

    var maxNC = _datosProv.slice().sort(function(a,b){ return (b.CantidadNC||0)-(a.CantidadNC||0); });
    var topNC = maxNC.length > 0 ? maxNC[0].Proveedor : '—';

    var conMora   = _datosProv.filter(function(p){ return p.TieneMorosa; }).length;
    var saldoNeg  = _datosProv.filter(function(p){ return (p.MontoNeto||0) < 0; }).length;
    var riesgo    = (conMora === 0 && saldoNeg === 0)
                    ? 'No se detectan proveedores con saldo negativo ni NC vencidas.'
                    : conMora + ' prov. con NC vencida' + (saldoNeg > 0 ? ', ' + saldoNeg + ' con saldo negativo.' : '.');

    var concent   = pctTop2 > 0
                    ? 'Las compras se concentran en dos proveedores (' + pctTop2 + '% del total).'
                    : 'Sin datos suficientes.';

    var filas = [
        ['Proveedor con mayor volumen de compras', top1],
        ['Segundo proveedor más importante',        top2],
        ['Proveedor con mayor cantidad de NC',      topNC],
        ['Riesgo financiero detectado',             riesgo],
        ['Nivel de concentración',                  concent]
    ].map(function(r) {
        return '<tr><td class="font-weight-bold">' + r[0] + '</td><td>' + r[1] + '</td></tr>';
    }).join('');

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">' +
        '<thead class="thead-dark"><tr><th>Aspecto Analizado</th><th>Resultado</th></tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#tablaAnalisis').html(html);
}

// ══════════════════════════════════════════════════════════
//  TABLA DETALLE
// ══════════════════════════════════════════════════════════
function renderizarTabla() {
    var filas = '';
    _datosProv.forEach(function (p) {
        var rowClass  = p.TieneMorosa ? 'table-warning' : ((p.MontoNeto || 0) < 0 ? 'table-danger' : '');
        var moraIcon  = p.TieneMorosa ? ' <i class="fas fa-exclamation-triangle text-danger" title="Tiene NC morosa"></i>' : '';

        // Estado
        var estado, estadoCls;
        if (p.TieneMorosa)            { estado = 'Con mora';     estadoCls = 'badge-warning text-dark'; }
        else if ((p.MontoNeto||0) < 0){ estado = 'Saldo neg.';   estadoCls = 'badge-danger'; }
        else                          { estado = 'Normal';        estadoCls = 'badge-success'; }

        filas +=
            '<tr class="' + rowClass + '">' +
            '<td>' + p.Proveedor + moraIcon + '<br><small class="text-muted">' + (p.RucProveedor||'') + '</small></td>' +
            '<td class="text-muted small">' + (p.Telefono || '—') + '</td>' +
            '<td class="text-center">' + (p.CantidadCompras||0) + '</td>' +
            '<td class="text-right font-weight-bold">Gs. ' + fmtGS(p.TotalCompras) + '</td>' +
            '<td class="text-center">' + (p.CantidadNC||0) + '</td>' +
            '<td class="text-right">Gs. ' + fmtGS(p.TotalMontoNC) + '</td>' +
            '<td class="text-center ' + ((p.NCPendientes||0) > 0 ? 'text-danger font-weight-bold' : '') + '">' +
                (p.NCPendientes||0) +
                ((p.NCPendientes||0) > 0 ? '<br><small>Gs. ' + fmtGS(p.MontoNCPendiente) + '</small>' : '') +
            '</td>' +
            '<td class="text-right ' + ((p.MontoNeto||0) < 0 ? 'text-danger' : '') + ' font-weight-bold">Gs. ' + fmtGS(p.MontoNeto) + '</td>' +
            '<td class="text-center"><span class="badge ' + estadoCls + '">' + estado + '</span></td>' +
            '</tr>';
    });

    var html =
        '<h6 class="font-weight-bold text-info border-bottom pb-1 mt-2">' +
        '<i class="fas fa-list mr-1"></i> Detalle de Proveedores</h6>' +
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Proveedor / RUC</th>' +
        '<th>Teléfono</th>' +
        '<th class="text-center">Compras</th>' +
        '<th class="text-right">Total Compras</th>' +
        '<th class="text-center">NC Total</th>' +
        '<th class="text-right">Monto NC Total</th>' +
        '<th class="text-center">NC Pend.</th>' +
        '<th class="text-right">Saldo Neto</th>' +
        '<th class="text-center">Estado</th>' +
        '</tr></thead>' +
        '<tbody>' + filas + '</tbody></table>';

    $('#contenedorProveedores').html(html);
}

// ── Helpers ───────────────────────────────────────────────
function fmtGS(n) {
    return Number(n || 0).toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

// ══════════════════════════════════════════════════════════
//  EXPORTAR PDF (via server — Python + membrete)
// ══════════════════════════════════════════════════════════
function exportarPDF() {
    if (_datosProv.length === 0) {
        Swal.fire({ title: 'Sin datos', text: 'No hay datos para exportar.', icon: 'warning' });
        return;
    }

    $('#hProvFechaInicio').val($('#txtFechaInicio').val());
    $('#hProvFechaFin').val($('#txtFechaFin').val());
    $('#hProvIdTienda').val(parseInt($('#cboTienda').val()) || 0);
    $('#hProvSoloDeuda').val($('#cboFiltro').val() === '1');
    $('#frmPDFProv').submit();
}
