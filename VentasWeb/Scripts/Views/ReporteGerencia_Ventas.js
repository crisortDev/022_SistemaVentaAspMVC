// ReporteGerencia_Ventas.js
'use strict';

$(function () {
    activarMenu('ReporteGerencia');

    var hoy  = new Date();
    var anio = hoy.getFullYear();
    var dd   = ('0' + hoy.getDate()).slice(-2);
    var mm   = ('0' + (hoy.getMonth() + 1)).slice(-2);
    $('#txtFechaInicio').val('01/01/' + anio);
    $('#txtFechaFin').val(dd + '/' + mm + '/' + anio);

    if ($.fn.datepicker) {
        $('[id^="txtFecha"]').datepicker({
            format: 'dd/mm/yyyy', autoclose: true, language: 'es', todayHighlight: true
        });
    }
});

// ── Generar reporte en pantalla ───────────────────────────────────────────────
function generarReporte() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    var id = $('#cboTienda').val() || 0;

    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }

    $('#spinner').show();
    $('#btnPDF').prop('disabled', true);
    $('#divReporte').hide();

    $.get($.MisUrls.url._RptVtaGer_ObtenerDatos,
        { fechainicio: fi, fechafin: ff, idtienda: id },
        function (r) {
            $('#spinner').hide();
            if (!r.resultado) { toastr.error(r.mensaje || 'Error al obtener datos.'); return; }

            var d = r.data;
            renderKPIs(d.KPIs);
            renderComparativo(d.KPIs);
            renderMes(d.VentasPorMes);
            renderTiendas(d.VentasPorTienda);
            renderVendedores(d.VentasPorVendedor);
            renderTopProductos(d.TopProductos);
            renderUtilidad(d.ProductosUtilidad);
            renderClientes(d.TopClientes);
            renderInventario(d.Inventario);

            $('#divReporte').show();
            $('#btnPDF').prop('disabled', false);
        }
    ).fail(function () {
        $('#spinner').hide();
        toastr.error('Error de comunicación con el servidor.');
    });
}

// ── Descargar PDF (POST con los mismos filtros) ───────────────────────────────
function descargarPDF() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    var id = $('#cboTienda').val() || 0;

    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }

    $('#hFechaInicio').val(fi);
    $('#hFechaFin').val(ff);
    $('#hIdTienda').val(id);
    $('#frmPDF').submit();
}

// ── KPIs ──────────────────────────────────────────────────────────────────────
function renderKPIs(k) {
    if (!k) return;
    $('#kpiVentas').text(fmt(k.VentasEfectivas));
    $('#kpiMonto').text(gs(k.MontoNeto));
    $('#kpiTicket').text(gs(k.TicketPromedio));
    $('#kpiNC').text(fmt(k.TotalNC));
    $('#kpiNCMonto').text(gs(k.MontoNC));
    $('#kpiClientes').text(fmt(k.CantidadClientes));
    $('#kpiUnidades').text(fmt(k.TotalUnidades));

    setVar('#kpiVentasVar', k.VariacionVentasPct);
    setVar('#kpiMontoVar',  k.VariacionMontoPct);
}

function setVar(sel, val) {
    if (val === null || val === undefined) { $(sel).text(''); return; }
    var f = parseFloat(val);
    var sign = f > 0 ? '▲ +' : f < 0 ? '▼ ' : '';
    $(sel).text(sign + f.toFixed(1) + '% vs. período anterior');
}

// ── Comparativo ───────────────────────────────────────────────────────────────
function renderComparativo(k) {
    if (!k) return;
    var vVar = k.VariacionVentasPct, mVar = k.VariacionMontoPct;
    var tb = $('#tbodyComparativo').empty();
    tb.append(fila4('Ventas (cantidad)', fmt(k.VentasEfectivas), fmt(k.VentasAnterior), fmtVar(vVar)));
    tb.append(fila4('Monto Neto',        gs(k.MontoNeto),        gs(k.MontoAnterior),   fmtVar(mVar)));
}

function fmtVar(v) {
    if (v === null || v === undefined) return '<span class="text-muted">—</span>';
    var f = parseFloat(v);
    var cls = f > 0 ? 'text-success' : f < 0 ? 'text-danger' : 'text-muted';
    var sign = f > 0 ? '▲ +' : f < 0 ? '▼ ' : '';
    return '<span class="' + cls + ' font-weight-bold">' + sign + f.toFixed(1) + '%</span>';
}

function fila4(label, actual, anterior, variacion) {
    return '<tr><td>' + esc(label) + '</td>' +
        '<td class="text-right">' + actual + '</td>' +
        '<td class="text-right">' + anterior + '</td>' +
        '<td class="text-center">' + variacion + '</td></tr>';
}

// ── Evolución por mes ─────────────────────────────────────────────────────────
function renderMes(data) {
    var tb = $('#tbodyMes').empty();
    if (!data || !data.length) { tb.append(sinDatos(4)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + r.Anio + '</td><td>' + esc(r.MesNombre) + '</td>' +
            '<td class="text-right">' + fmt(r.Cantidad) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td></tr>');
    });
}

// ── Tiendas ───────────────────────────────────────────────────────────────────
function renderTiendas(data) {
    var tb = $('#tbodyTiendas').empty();
    if (!data || !data.length) { tb.append(sinDatos(4)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + esc(r.Tienda) + '</td>' +
            '<td class="text-right">' + fmt(r.Cantidad) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td>' +
            '<td class="text-center">' + (parseFloat(r.PorcentajePct)||0).toFixed(1) + '%</td></tr>');
    });
}

// ── Vendedores ────────────────────────────────────────────────────────────────
function renderVendedores(data) {
    var tb = $('#tbodyVendedores').empty();
    if (!data || !data.length) { tb.append(sinDatos(5)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + esc(r.Vendedor) + '</td><td>' + esc(r.Tienda) + '</td>' +
            '<td class="text-right">' + r.Cantidad + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td>' +
            '<td class="text-right">' + gs(r.TicketPromedio) + '</td></tr>');
    });
}

// ── Top Productos ─────────────────────────────────────────────────────────────
function renderTopProductos(data) {
    var tb = $('#tbodyTopProductos').empty();
    if (!data || !data.length) { tb.append(sinDatos(6)); return; }
    data.forEach(function (r) {
        tb.append('<tr>' +
            '<td class="text-center font-weight-bold">' + r.Ranking + '</td>' +
            '<td>' + esc(r.Codigo) + '</td>' +
            '<td>' + esc(r.Producto) + '</td>' +
            '<td><small class="text-muted">' + esc(r.Categoria) + '</small></td>' +
            '<td class="text-right">' + fmt(r.UnidadesVendidas) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td></tr>');
    });
}

// ── Utilidad ──────────────────────────────────────────────────────────────────
function renderUtilidad(data) {
    var tb = $('#tbodyUtilidad').empty();
    if (!data || !data.length) { tb.append(sinDatos(6)); return; }
    data.forEach(function (r) {
        var m = parseFloat(r.MargenPct) || 0;
        var cls = m >= 20 ? 'text-success font-weight-bold' : m < 0 ? 'text-danger' : '';
        tb.append('<tr>' +
            '<td class="text-center font-weight-bold">' + r.Ranking + '</td>' +
            '<td>' + esc(r.Producto) + '</td>' +
            '<td class="text-right">' + gs(r.VentaTotal) + '</td>' +
            '<td class="text-right">' + gs(r.CostoTotal) + '</td>' +
            '<td class="text-right font-weight-bold">' + gs(r.Utilidad) + '</td>' +
            '<td class="text-right ' + cls + '">' + m.toFixed(1) + '%</td></tr>');
    });
}

// ── Top Clientes ──────────────────────────────────────────────────────────────
function renderClientes(data) {
    var tb = $('#tbodyClientes').empty();
    if (!data || !data.length) { tb.append(sinDatos(5)); return; }
    data.forEach(function (r) {
        tb.append('<tr>' +
            '<td class="text-center font-weight-bold">' + r.Ranking + '</td>' +
            '<td>' + esc(r.Cliente) + '</td>' +
            '<td class="text-right">' + r.CantidadFacturas + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td>' +
            '<td class="text-right">' + gs(r.TicketPromedio) + '</td></tr>');
    });
}

// ── Inventario ────────────────────────────────────────────────────────────────
function renderInventario(data) {
    var tb = $('#tbodyInventario').empty();
    if (!data || !data.length) { tb.append(sinDatos(6)); return; }
    data.forEach(function (r) {
        var clsA = r.ProductosAgotados  > 0 ? 'text-danger font-weight-bold' : 'text-success';
        var clsB = r.ProductosBajoStock > 0 ? 'text-warning font-weight-bold' : 'text-success';
        tb.append('<tr><td>' + esc(r.Tienda) + '</td>' +
            '<td class="text-center ' + clsA + '">' + r.ProductosAgotados + '</td>' +
            '<td class="text-center ' + clsB + '">' + r.ProductosBajoStock + '</td>' +
            '<td class="text-center">' + r.TotalProductos + '</td>' +
            '<td class="text-center">' + r.InventariosAprobados + '</td>' +
            '<td class="text-center">' + (parseFloat(r.PctDiferenciaProm)||0).toFixed(2) + '%</td></tr>');
    });
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function gs(v) {
    var n = parseFloat(v) || 0;
    return 'Gs. ' + n.toLocaleString('es-PY', { maximumFractionDigits: 0 });
}
function fmt(v) {
    return (parseFloat(v) || 0).toLocaleString('es-PY', { maximumFractionDigits: 0 });
}
function esc(s) {
    return (s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
function sinDatos(cols) {
    return '<tr><td colspan="' + cols + '" class="text-center text-muted">Sin datos en el período</td></tr>';
}
