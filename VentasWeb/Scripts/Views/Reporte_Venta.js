// Reporte_Venta.js — Reporte Operativo de Ventas
'use strict';

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

    // Cargar combo de tiendas
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var sel = $('#cboTienda').empty();
        $('<option>').val(0).text('-- Todas las sucursales --').appendTo(sel);
        if (data.data) {
            $.each(data.data, function (_, t) {
                if (t.Activo)
                    $('<option>').val(t.IdTienda).text(t.Nombre).appendTo(sel);
            });
        }
    });
});

// ── Buscar ────────────────────────────────────────────────────────────────────
function buscarVentas() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    var id = $('#cboTienda').val() || 0;

    if (!fi || !ff) { toastr.warning('Ingrese el rango de fechas.'); return; }

    $('#spinner').show();
    $('#btnPDF').prop('disabled', true);
    $('#divReporte').hide();

    $.get($.MisUrls.url._ObtenerReporteVenta,
        { fechainicio: fi, fechafin: ff, idtienda: id },
        function (data) {
            $('#spinner').hide();

            if (!data || !data.length) {
                toastr.info('Sin ventas en el período seleccionado.');
                $('#divReporte').hide();
                return;
            }

            renderTabla(data);
            renderEncabezado(data[0], fi, ff);

            $('#divReporte').show();
            $('#btnPDF').prop('disabled', false);
        }
    ).fail(function () {
        $('#spinner').hide();
        toastr.error('Error de comunicación con el servidor.');
    });
}

// ── Encabezado (info-bar) ─────────────────────────────────────────────────────
function renderEncabezado(fila, fi, ff) {
    $('#lblTienda').text(fila.NombreTienda || '—');
    $('#lblRuc').text(fila.RucTienda || '—');
    $('#lblPeriodo').text('Período: ' + fi + ' al ' + ff);
}

// ── Tabla ─────────────────────────────────────────────────────────────────────
function renderTabla(data) {
    var tb = $('#tbodyVentas').empty();
    var totalMonto = 0, totalUnid = 0, efectivas = 0, anuladas = 0;

    data.forEach(function (v) {
        var estado = (v.Estado || 'Efectiva').trim();
        var esAnul = /^(anulad|cancelad)/i.test(estado);
        if (esAnul) anuladas++; else efectivas++;

        var monto = parseFloat((v.TotalVenta || '0').toString().replace(/,/g, '')) || 0;
        var unid  = parseInt(v.CantidadUnidadesVendidas || 0, 10) || 0;
        if (!esAnul) { totalMonto += monto; totalUnid += unid; }

        var badgeCls = esAnul ? 'badge-anulada'
            : /^pendiente/i.test(estado) ? 'badge-pendiente'
            : 'badge-efectiva';

        var tr = $('<tr>');
        if (esAnul) tr.addClass('text-muted');
        tr.append(
            $('<td>').text(v.FechaVenta),
            $('<td>').text(v.NumeroDocumento),
            $('<td class="text-center">').text(v.TipoDocumento),
            $('<td class="text-center">').html(
                '<span class="badge-estado ' + badgeCls + '">' + esc(estado) + '</span>'),
            $('<td>').text(v.Cliente || 'Consumidor Final'),
            $('<td>').text(v.FormaCobro || '—'),
            $('<td>').text(v.NombreEmpleado),
            $('<td class="text-right">').text(unid),
            $('<td class="text-right">').text(gs(monto))
        );
        tb.append(tr);
    });

    $('#tfTotal').text(gs(totalMonto));
    $('#tfUnidades').text(totalUnid);
    $('#cntEfectivas').text(efectivas);
    $('#cntAnuladas').text(anuladas);
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

// ── Utilidades ────────────────────────────────────────────────────────────────
function gs(v) {
    return 'Gs. ' + (parseFloat(v) || 0).toLocaleString('es-PY', { maximumFractionDigits: 0 });
}
function esc(s) {
    return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
