// ReporteGerencia_Index.js — Reporte de Compras Alta Gerencia
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

// ── Generar ───────────────────────────────────────────────────────────────────
function generarReporte() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    var id = $('#cboTienda').val() || 0;

    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }

    $('#spinner').show();
    $('#btnPDF').prop('disabled', true);
    $('#divReporte').hide();

    $.get($.MisUrls.url._RG_ObtenerDatos,
        { fechainicio: fi, fechafin: ff, idtienda: id },
        function (r) {
            $('#spinner').hide();
            if (!r.resultado) { toastr.error(r.mensaje || 'Error al obtener datos.'); return; }

            var d = r.data;
            renderKPIs(d.KPIs);
            renderMes(d.ComprasMensuales);
            renderProveedores(d.TopProveedores);
            renderProductos(d.TopProductos);
            renderEstadoOC(d.OrdenesPorEstado);
            renderTiendas(d.ComprasPorTienda);
            renderRelacion(d.RelacionCV);
            renderNC(d.NotasCredito);

            $('#divReporte').show();
            $('#btnPDF').prop('disabled', false);
        }
    ).fail(function () {
        $('#spinner').hide();
        toastr.error('Error de comunicación con el servidor.');
    });
}

// ── Descargar PDF ─────────────────────────────────────────────────────────────
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
    $('#kpiMonto').text(gs(k.MontoTotalCompras));
    $('#kpiTotalOC').text(fmt(k.TotalOC));
    $('#kpiRecepcionadas').text(fmt(k.Recepcionadas));
    $('#kpiPendientes').text(fmt(k.OCPendientes));
    $('#kpiGastoPromedio').text(gs(k.GastoPromedio));
    $('#kpiProveedores').text(fmt(k.ProveedoresActivos));
    $('#kpiProductos').text(fmt(k.ProductosComprados));
    $('#kpiAnuladas').text(fmt(k.Anuladas));
}

// ── Compras por mes ───────────────────────────────────────────────────────────
function renderMes(data) {
    var tb = $('#tbodyMes').empty();
    if (!data || !data.length) { tb.append(sinDatos(4)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + r.Anio + '</td><td>' + esc(r.MesNombre) + '</td>' +
            '<td class="text-right">' + fmt(r.Cantidad) + '</td>' +
            '<td class="text-right">' + gs(r.Monto) + '</td></tr>');
    });
}

// ── Top proveedores ───────────────────────────────────────────────────────────
function renderProveedores(data) {
    var tb = $('#tbodyProveedores').empty();
    if (!data || !data.length) { tb.append(sinDatos(5)); return; }
    data.forEach(function (r) {
        tb.append('<tr>' +
            '<td class="text-center font-weight-bold">' + r.Ranking + '</td>' +
            '<td>' + esc(r.Proveedor) + '</td>' +
            '<td class="text-right">' + fmt(r.TotalCompras) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td>' +
            '<td class="text-center">' + r.CantidadNC + '</td></tr>');
    });
}

// ── Productos más comprados ───────────────────────────────────────────────────
function renderProductos(data) {
    var tb = $('#tbodyProductos').empty();
    if (!data || !data.length) { tb.append(sinDatos(6)); return; }
    data.forEach(function (r) {
        tb.append('<tr>' +
            '<td class="text-center font-weight-bold">' + r.Ranking + '</td>' +
            '<td>' + esc(r.Codigo) + '</td>' +
            '<td>' + esc(r.Producto) + '</td>' +
            '<td><small class="text-muted">' + esc(r.Categoria) + '</small></td>' +
            '<td class="text-right">' + fmt(r.CantidadTotal) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td></tr>');
    });
}

// ── Estado OC ─────────────────────────────────────────────────────────────────
function renderEstadoOC(data) {
    var tb = $('#tbodyEstadoOC').empty();
    if (!data || !data.length) { tb.append(sinDatos(3)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + esc(r.Estado) + '</td>' +
            '<td class="text-right">' + fmt(r.Cantidad) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td></tr>');
    });
}

// ── Compras por tienda ────────────────────────────────────────────────────────
function renderTiendas(data) {
    var tb = $('#tbodyTiendas').empty();
    if (!data || !data.length) { tb.append(sinDatos(4)); return; }
    data.forEach(function (r) {
        tb.append('<tr><td>' + esc(r.Tienda) + '</td>' +
            '<td class="text-right">' + fmt(r.CantidadCompras) + '</td>' +
            '<td class="text-right">' + gs(r.MontoTotal) + '</td>' +
            '<td class="text-center">' + (parseFloat(r.PorcentajePct)||0).toFixed(1) + '%</td></tr>');
    });
}

// ── Relación Compras vs Ventas ────────────────────────────────────────────────
function renderRelacion(r) {
    var tb = $('#tbodyRelacion').empty();
    if (!r) { tb.append(sinDatos(3)); return; }
    var compras = parseFloat(r.TotalCompras) || 0;
    var ventas  = parseFloat(r.TotalVentas)  || 0;
    var relPct  = ventas > 0 ? (compras / ventas * 100).toFixed(1) + '%' : '—';
    tb.append('<tr><td>Compras</td><td class="text-right">' + gs(compras) +
        '</td><td class="text-right" rowspan="2" style="vertical-align:middle;">' +
        '<span class="badge badge-info p-2" style="font-size:.9rem;">Compras / Ventas = ' + relPct + '</span>' +
        '</td></tr>');
    tb.append('<tr><td>Ventas</td><td class="text-right">' + gs(ventas) + '</td></tr>');
}

// ── NC resumen ────────────────────────────────────────────────────────────────
function renderNC(nc) {
    var tb = $('#tbodyNC').empty();
    if (!nc) { tb.append(sinDatos(2)); return; }
    [
        ['Total NC',           fmt(nc.TotalNC)],
        ['Pendientes',         fmt(nc.Pendientes)],
        ['Recibidas',          fmt(nc.Recibidas)],
        ['Rechazadas',         fmt(nc.Rechazadas)],
        ['Morosas (+30 días)', fmt(nc.Morosas)],
        ['Monto Total NC',     gs(nc.MontoTotal)]
    ].forEach(function (row) {
        tb.append('<tr><td>' + row[0] + '</td><td class="text-right">' + row[1] + '</td></tr>');
    });
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function gs(v) {
    return 'Gs. ' + (parseFloat(v)||0).toLocaleString('es-PY', { maximumFractionDigits: 0 });
}
function fmt(v) {
    return (parseFloat(v)||0).toLocaleString('es-PY', { maximumFractionDigits: 0 });
}
function esc(s) {
    return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
function sinDatos(cols) {
    return '<tr><td colspan="' + cols + '" class="text-center text-muted">Sin datos en el período</td></tr>';
}
