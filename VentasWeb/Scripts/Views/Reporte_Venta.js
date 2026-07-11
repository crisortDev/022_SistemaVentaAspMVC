// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — VENTAS
// ═══════════════════════════════════════════════════════════
'use strict';

var _datosVenta    = [];   // datos crudos del servidor
var _datosVisibles = [];   // después de filtro de estado/forma cobro

$(function () {
    activarMenu('Reportes');

    // Fechas por defecto: mes actual
    var hoy = new Date();
    var dd  = ('0' + hoy.getDate()).slice(-2);
    var mm  = ('0' + (hoy.getMonth() + 1)).slice(-2);
    var aa  = hoy.getFullYear();
    $('#txtFechaInicio').val('01/' + mm + '/' + aa);
    $('#txtFechaFin').val(dd + '/' + mm + '/' + aa);

    if ($.fn.datepicker) {
        $('[id^="txtFecha"]').datepicker({
            format: 'dd/mm/yyyy', autoclose: true, language: 'es',
            todayHighlight: true, endDate: '0d'
        });
    }

    // Cargar combo tiendas — solo si es un <select> real (SuperAdmin); para el
    // resto de los roles #cboTienda es un input hidden con su sucursal fija.
    if ($('#cboTienda').is('select')) {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var sel = $('#cboTienda').empty();
        $('<option>').val(0).text('-- Todas las sucursales --').appendTo(sel);
        var lista = data.data || data;
        $.each(lista, function (_, t) {
            if (t.Activo)
                $('<option>').val(t.IdTienda).text(t.Nombre).appendTo(sel);
        });
    });
    }

    // Filtro de forma de cobro (cliente) — re-renderiza al cambiar
    $('#cboFormaCobro').on('change', function () {
        if (_datosVenta.length === 0) return;
        _datosVisibles = aplicarFiltros(_datosVenta);
        renderizarTodo(_datosVisibles);
    });
});

// ── Helpers de estado ──────────────────────────────────────
function normalizarEstado(est) {
    est = (est || '').trim();
    if (!est || /^activ/i.test(est)) return 'Efectiva';
    return est;
}
function esAnulada(est) {
    return /^(anulad|cancelad)/i.test(est);
}

// ── Aplicar filtros cliente ────────────────────────────────
function aplicarFiltros(data) {
    var filtroEstado = $('#cboEstado').val();
    var filtroCobro  = $('#cboFormaCobro').val();

    return data.filter(function (v) {
        var estado = normalizarEstado(v.Estado);
        if (filtroEstado === 'Efectiva' && esAnulada(estado)) return false;
        if (filtroEstado === 'Anulada'  && !esAnulada(estado)) return false;
        if (filtroCobro && (v.FormaCobro || '') !== filtroCobro) return false;
        return true;
    });
}

// ── Buscar ─────────────────────────────────────────────────
function buscarVentas() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    var id = $('#cboTienda').val() || 0;

    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }

    $('#spinner').removeClass('d-none');
    $('#btnBuscar').prop('disabled', true);
    $('#btnPDF').prop('disabled', true);
    $('#panelKPI, #panelAnalisis').addClass('d-none');
    $('#contenedorVentas').html(
        '<p class="text-center text-muted"><i class="fas fa-spinner fa-spin"></i> Cargando...</p>'
    );

    $.get($.MisUrls.url._ObtenerReporteVenta,
        { fechainicio: fi, fechafin: ff, idtienda: id },
        function (data) {
            $('#spinner').addClass('d-none');
            $('#btnBuscar').prop('disabled', false);

            _datosVenta = data || [];

            if (_datosVenta.length === 0) {
                toastr.info('Sin ventas en el período seleccionado.');
                $('#contenedorVentas').html(
                    '<p class="text-center text-muted py-3">Sin ventas para los filtros seleccionados.</p>'
                );
                return;
            }

            // Poblar combo forma de cobro (único por búsqueda)
            poblarFormaCobro(_datosVenta);

            _datosVisibles = aplicarFiltros(_datosVenta);

            if (_datosVisibles.length === 0) {
                toastr.info('Sin ventas para el filtro seleccionado.');
                $('#contenedorVentas').html(
                    '<p class="text-center text-muted py-3">Sin ventas para los filtros seleccionados.</p>'
                );
                return;
            }

            renderizarTodo(_datosVisibles);
            $('#btnPDF').prop('disabled', false);
        }
    ).fail(function () {
        $('#spinner').addClass('d-none');
        $('#btnBuscar').prop('disabled', false);
        toastr.error('Error de comunicación con el servidor.');
    });
}

// ── Poblar combo Forma de Cobro ────────────────────────────
function poblarFormaCobro(data) {
    var formas = [];
    data.forEach(function (v) {
        var f = (v.FormaCobro || '').trim();
        if (f && formas.indexOf(f) === -1) formas.push(f);
    });
    formas.sort();
    var $cbo = $('#cboFormaCobro').empty();
    $('<option>').val('').text('-- Todas --').appendTo($cbo);
    formas.forEach(function (f) {
        $('<option>').val(f).text(f).appendTo($cbo);
    });
}

// ── Orquestador ────────────────────────────────────────────
function renderizarTodo(datos) {
    renderizarKPIs(datos);
    renderizarEstado(datos);
    renderizarEmpleados(datos);
    renderizarFormaCobro(datos);
    renderizarClientes(datos);
    renderizarAnalisis(datos);
    renderizarTabla(datos);
    $('#panelKPI, #panelAnalisis').removeClass('d-none');
}

// ── Helpers ────────────────────────────────────────────────
function fmtGS(v) {
    var n = parseFloat(String(v).replace(/,/g, ''));
    if (isNaN(n)) return 'Gs. 0';
    return 'Gs. ' + Math.round(n).toLocaleString('es-PY');
}
function parseNum(v) {
    var n = parseFloat(String(v).replace(/,/g, ''));
    return isNaN(n) ? 0 : n;
}
function barra(n, max, largo) {
    largo = largo || 18;
    if (max <= 0) return '';
    var b = n > 0 ? Math.max(1, Math.round(n / max * largo)) : 0;
    return '█'.repeat(b);
}

// ── KPIs ───────────────────────────────────────────────────
function renderizarKPIs(datos) {
    var total     = datos.length;
    var monto     = 0, unidades = 0, efectivas = 0, anuladas = 0;
    var montos    = [];
    var empMap    = {};

    datos.forEach(function (v) {
        var estado = normalizarEstado(v.Estado);
        var m      = parseNum(v.TotalVenta);
        var u      = parseInt(v.CantidadUnidadesVendidas) || 0;

        if (esAnulada(estado)) {
            anuladas++;
        } else {
            efectivas++;
            monto    += m;
            unidades += u;
            montos.push(m);
        }

        var emp = (v.NombreEmpleado || '').trim();
        if (emp) empMap[emp] = (empMap[emp] || 0) + m;
    });

    var promedio   = efectivas > 0 ? monto / efectivas : 0;
    var mayorVenta = montos.length > 0 ? Math.max.apply(null, montos) : 0;
    var empTop     = Object.keys(empMap).sort(function (a, b) { return empMap[b] - empMap[a]; })[0] || '—';

    $('#kpiTotalVentas').text(total);
    $('#kpiMontoTotal').text(fmtGS(monto));
    $('#kpiEfectivas').text(efectivas);
    $('#kpiAnuladas').text(anuladas);
    $('#kpiPromedio').text(fmtGS(promedio));
    $('#kpiUnidades').text(unidades.toLocaleString('es-PY'));
    $('#kpiMayorVenta').text(fmtGS(mayorVenta));
    $('#kpiEmpleadoTop').text(empTop);
}

// ── Estado ─────────────────────────────────────────────────
function renderizarEstado(datos) {
    var total     = datos.length || 1;
    var efectivas = 0, anuladas = 0;
    var mEfect = 0, mAnul = 0;

    datos.forEach(function (v) {
        var m = parseNum(v.TotalVenta);
        if (esAnulada(normalizarEstado(v.Estado))) { anuladas++; mAnul += m; }
        else { efectivas++; mEfect += m; }
    });

    var maxCant = Math.max(efectivas, anuladas, 1);

    function fila(label, n, monto, cls) {
        var pct  = (n / total * 100).toFixed(1) + '%';
        var bars = barra(n, maxCant, 16);
        return '<tr class="' + cls + '">'
            + '<td>' + label + '</td>'
            + '<td class="text-center font-weight-bold">' + n + '</td>'
            + '<td class="text-right">' + fmtGS(monto) + '</td>'
            + '<td class="text-center">' + pct + '</td>'
            + '<td class="text-success">' + bars + '</td>'
            + '</tr>';
    }

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Estado</th><th class="text-center">Cant.</th>'
        + '<th class="text-right">Monto</th><th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>'
        + fila('Efectivas', efectivas, mEfect, 'table-success')
        + fila('Anuladas',  anuladas,  mAnul,  'table-danger')
        + '</tbody></table>';

    $('#tablaEstado').html(html);
}

// ── Top Empleados ──────────────────────────────────────────
function renderizarEmpleados(datos) {
    var mapa = {};
    datos.forEach(function (v) {
        if (esAnulada(normalizarEstado(v.Estado))) return;
        var emp  = (v.NombreEmpleado || 'Sin nombre').trim();
        var m    = parseNum(v.TotalVenta);
        var cant = 1;
        if (!mapa[emp]) mapa[emp] = { monto: 0, cant: 0 };
        mapa[emp].monto += m;
        mapa[emp].cant  += 1;
    });

    var sorted   = Object.keys(mapa).map(function (k) {
        return { nombre: k, monto: mapa[k].monto, cant: mapa[k].cant };
    }).sort(function (a, b) { return b.monto - a.monto; }).slice(0, 10);

    var montoTotal = sorted.reduce(function (s, e) { return s + e.monto; }, 0) || 1;
    var maxMonto   = sorted.length > 0 ? sorted[0].monto : 1;

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Empleado</th><th class="text-center">Ventas</th>'
        + '<th class="text-right">Monto</th><th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>';

    sorted.forEach(function (e, i) {
        var pct  = (e.monto / montoTotal * 100).toFixed(1) + '%';
        var bars = barra(e.monto, maxMonto, 16);
        html += '<tr class="' + (i % 2 === 0 ? '' : 'table-light') + '">'
            + '<td>' + e.nombre + '</td>'
            + '<td class="text-center">' + e.cant + '</td>'
            + '<td class="text-right font-weight-bold">' + fmtGS(e.monto) + '</td>'
            + '<td class="text-center">' + pct + '</td>'
            + '<td><span class="text-primary">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaEmpleados').html(html);
}

// ── Forma de Cobro ─────────────────────────────────────────
function renderizarFormaCobro(datos) {
    var mapa = {};
    datos.forEach(function (v) {
        if (esAnulada(normalizarEstado(v.Estado))) return;
        var f = (v.FormaCobro || 'Sin especificar').trim();
        var m = parseNum(v.TotalVenta);
        if (!mapa[f]) mapa[f] = { monto: 0, cant: 0 };
        mapa[f].monto += m;
        mapa[f].cant  += 1;
    });

    var sorted     = Object.keys(mapa).map(function (k) {
        return { forma: k, monto: mapa[k].monto, cant: mapa[k].cant };
    }).sort(function (a, b) { return b.monto - a.monto; });

    var montoTotal = sorted.reduce(function (s, e) { return s + e.monto; }, 0) || 1;
    var maxMonto   = sorted.length > 0 ? sorted[0].monto : 1;

    var colors = ['text-success', 'text-primary', 'text-info', 'text-warning', 'text-secondary'];

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Forma de Cobro</th><th class="text-center">Ventas</th>'
        + '<th class="text-right">Monto</th><th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>';

    sorted.forEach(function (e, i) {
        var pct   = (e.monto / montoTotal * 100).toFixed(1) + '%';
        var bars  = barra(e.monto, maxMonto, 16);
        var color = colors[i % colors.length];
        html += '<tr>'
            + '<td>' + e.forma + '</td>'
            + '<td class="text-center">' + e.cant + '</td>'
            + '<td class="text-right font-weight-bold">' + fmtGS(e.monto) + '</td>'
            + '<td class="text-center">' + pct + '</td>'
            + '<td><span class="' + color + '">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaFormaCobro').html(html);
}

// ── Top Clientes ───────────────────────────────────────────
function renderizarClientes(datos) {
    var mapa = {};
    datos.forEach(function (v) {
        if (esAnulada(normalizarEstado(v.Estado))) return;
        var cli = (v.Cliente || 'Consumidor Final').trim();
        var m   = parseNum(v.TotalVenta);
        if (!mapa[cli]) mapa[cli] = { monto: 0, cant: 0 };
        mapa[cli].monto += m;
        mapa[cli].cant  += 1;
    });

    var sorted     = Object.keys(mapa).map(function (k) {
        return { cliente: k, monto: mapa[k].monto, cant: mapa[k].cant };
    }).sort(function (a, b) { return b.monto - a.monto; }).slice(0, 10);

    var montoTotal = sorted.reduce(function (s, e) { return s + e.monto; }, 0) || 1;
    var maxMonto   = sorted.length > 0 ? sorted[0].monto : 1;

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Cliente</th><th class="text-center">Compras</th>'
        + '<th class="text-right">Monto</th><th class="text-center">%</th><th>Gráfico</th></tr></thead><tbody>';

    sorted.forEach(function (e, i) {
        var pct  = (e.monto / montoTotal * 100).toFixed(1) + '%';
        var bars = barra(e.monto, maxMonto, 16);
        html += '<tr class="' + (i % 2 === 0 ? '' : 'table-light') + '">'
            + '<td>' + e.cliente + '</td>'
            + '<td class="text-center">' + e.cant + '</td>'
            + '<td class="text-right font-weight-bold">' + fmtGS(e.monto) + '</td>'
            + '<td class="text-center">' + pct + '</td>'
            + '<td><span class="text-warning">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaClientes').html(html);
}

// ── Análisis Gerencial ─────────────────────────────────────
function renderizarAnalisis(datos) {
    var total     = datos.length;
    var monto     = 0, unidades = 0, efectivas = 0, anuladas = 0;
    var empMap    = {}, cliMap = {}, cobMap = {};
    var montos    = [];

    datos.forEach(function (v) {
        var estado = normalizarEstado(v.Estado);
        var m      = parseNum(v.TotalVenta);
        var u      = parseInt(v.CantidadUnidadesVendidas) || 0;

        if (esAnulada(estado)) {
            anuladas++;
        } else {
            efectivas++;
            monto    += m;
            unidades += u;
            montos.push(m);
            var emp = (v.NombreEmpleado || 'Sin nombre').trim();
            empMap[emp] = (empMap[emp] || 0) + m;
            var cli = (v.Cliente || 'Consumidor Final').trim();
            cliMap[cli] = (cliMap[cli] || 0) + m;
            var cob = (v.FormaCobro || 'Sin especificar').trim();
            cobMap[cob] = (cobMap[cob] || 0) + 1;
        }
    });

    var promedio   = efectivas > 0 ? monto / efectivas : 0;
    var mayorVenta = montos.length > 0 ? Math.max.apply(null, montos) : 0;
    var empTop  = Object.keys(empMap).sort(function (a, b) { return empMap[b] - empMap[a]; })[0] || '—';
    var cliTop  = Object.keys(cliMap).sort(function (a, b) { return cliMap[b] - cliMap[a]; })[0] || '—';
    var cobTop  = Object.keys(cobMap).sort(function (a, b) { return cobMap[b] - cobMap[a]; })[0] || '—';
    var pctAnul = total > 0 ? (anuladas / total * 100).toFixed(1) + '%' : '0%';

    var filas = [
        ['Total de ventas registradas',           total],
        ['Ventas efectivas',                      efectivas + ' (' + (efectivas/total*100).toFixed(1) + '%)'],
        ['Ventas anuladas',                       anuladas  + ' (' + pctAnul + ')'],
        ['Monto total del período',               fmtGS(monto)],
        ['Promedio por venta',                    fmtGS(promedio)],
        ['Mayor venta individual',                fmtGS(mayorVenta)],
        ['Total unidades vendidas',               unidades.toLocaleString('es-PY')],
        ['Empleado con mayor facturación',        empTop],
        ['Cliente con mayor compra acumulada',    cliTop + ' — ' + fmtGS(cliMap[cliTop] || 0)],
        ['Forma de cobro más utilizada',          cobTop],
    ];

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th style="width:55%">Aspecto</th><th>Resultado</th></tr></thead><tbody>';

    filas.forEach(function (f, i) {
        html += '<tr class="' + (i % 2 === 0 ? '' : 'table-light') + '">'
            + '<td class="font-weight-bold">' + f[0] + '</td>'
            + '<td>' + f[1] + '</td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaAnalisis').html(html);
}

// ── Tabla Detalle (DataTable) ──────────────────────────────
function renderizarTabla(datos) {
    // Destruir DataTable previo si existe
    if ($.fn.DataTable.isDataTable('#tbReporte')) {
        $('#tbReporte').DataTable().destroy();
        $('#contenedorVentas').empty();
    }

    var html = '<div class="table-responsive">'
        + '<table id="tbReporte" class="table table-sm table-bordered table-hover" style="width:100%; font-size:12px;">'
        + '<thead class="thead-dark"><tr>'
        + '<th>Fecha</th><th>Nro Documento</th><th class="text-center">Tipo</th>'
        + '<th class="text-center">Estado</th><th>Cliente</th><th>Forma Cobro</th>'
        + '<th>Empleado</th><th class="text-center">Unid.</th><th class="text-right">Total</th>'
        + '</tr></thead><tbody>';

    var totalMonto = 0, totalUnid = 0;

    datos.forEach(function (v) {
        var estado = normalizarEstado(v.Estado);
        var esAnul = esAnulada(estado);
        var monto  = parseNum(v.TotalVenta);
        var unid   = parseInt(v.CantidadUnidadesVendidas) || 0;
        if (!esAnul) { totalMonto += monto; totalUnid += unid; }

        var badgeCls = esAnul
            ? 'badge badge-danger'
            : 'badge badge-success';
        var trCls = esAnul ? 'class="text-muted"' : '';

        html += '<tr ' + trCls + '>'
            + '<td>' + (v.FechaVenta || '') + '</td>'
            + '<td>' + (v.NumeroDocumento || '') + '</td>'
            + '<td class="text-center">' + (v.TipoDocumento || '') + '</td>'
            + '<td class="text-center"><span class="' + badgeCls + '">' + estado + '</span></td>'
            + '<td>' + (v.Cliente || 'Consumidor Final') + '</td>'
            + '<td>' + (v.FormaCobro || '—') + '</td>'
            + '<td>' + (v.NombreEmpleado || '') + '</td>'
            + '<td class="text-center">' + unid + '</td>'
            + '<td class="text-right">' + fmtGS(monto) + '</td>'
            + '</tr>';
    });

    html += '</tbody>'
        + '<tfoot><tr class="font-weight-bold bg-dark text-white">'
        + '<td colspan="7" class="text-right">TOTAL DEL PERÍODO:</td>'
        + '<td class="text-center">' + totalUnid.toLocaleString('es-PY') + '</td>'
        + '<td class="text-right">' + fmtGS(totalMonto) + '</td>'
        + '</tr></tfoot>'
        + '</table></div>';

    $('#contenedorVentas').html(html);

    $('#tbReporte').DataTable({
        language:   $.fn.dataTable.defaults.oLanguage,
        pageLength: 25,
        order:      [[0, 'desc']],
        columnDefs: [{ orderable: false, targets: [3] }]
    });
}

// ── Descargar PDF ──────────────────────────────────────────
function descargarPDF() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }
    $('#hFechaInicio').val(fi);
    $('#hFechaFin').val(ff);
    $('#hIdTienda').val($('#cboTienda').val() || 0);
    $('#hEstado').val($('#cboEstado').val());
    $('#frmPDF').submit();
}
