// ═══════════════════════════════════════════════════════
//  ORDEN PAGO — CONSULTAR
// ═══════════════════════════════════════════════════════

$(function () {
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $('.datepicker').datepicker({ dateFormat: 'dd/mm/yy', changeYear: true, changeMonth: true });

    var hoy    = new Date();
    var hace30 = new Date();
    hace30.setDate(hace30.getDate() - 30);

    $('#txtFechaInicio').datepicker('setDate', hace30);
    $('#txtFechaFin').datepicker('setDate', hoy);

    $('#btnBuscar').on('click', cargarOP);
    cargarOP();
});

function cargarOP() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    if (!fi || !ff) { Swal.fire({ title: 'Atención', text: 'Ingrese el rango de fechas.', icon: 'warning' }); return; }

    $.getJSON($.MisUrls.url._OP_Obtener, {
        fechainicio: fi,
        fechafin:    ff,
        idtienda:    0,
        estado:      $('#cboEstado').val()
    }).done(function (res) {
        var tbody = $('#tbodyOP').empty();
        if (!res.data || res.data.length === 0) {
            tbody.append('<tr><td colspan="7" class="text-center text-muted">Sin resultados.</td></tr>');
            return;
        }
        $.each(res.data, function (i, op) {
            var badge = op.Estado === 'Pagada'  ? 'success' :
                        op.Estado === 'Anulada' ? 'danger'  : 'warning';
            tbody.append(
                '<tr>' +
                '<td>' + op.NumeroOP + '</td>' +
                '<td>' + (op.oProveedor ? op.oProveedor.RazonSocial : '') + '</td>' +
                '<td>' + (op.oTienda   ? op.oTienda.Nombre : '') + '</td>' +
                '<td class="text-right">Gs. ' + Math.round(op.Monto).toLocaleString('es-PY') + '</td>' +
                '<td class="text-center"><span class="badge badge-' + badge + '">' + op.Estado + '</span></td>' +
                '<td class="text-center">' + op.FechaEmisionTexto + '</td>' +
                '<td class="text-center">' +
                  '<a href="' + $.MisUrls.url._OP_Documento + '?idordenpago=' + op.IdOrdenPago +
                  '" target="_blank" class="btn btn-xs btn-outline-secondary" title="Ver PDF">' +
                  '<i class="fas fa-print"></i></a>' +
                '</td>' +
                '</tr>'
            );
        });
    }).fail(function () { Swal.fire({ title: 'Error', text: 'Error al cargar órdenes de pago.', icon: 'error' }); });
}
