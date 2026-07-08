// ═══════════════════════════════════════════════════════════
//  REPORTE — TRASLADOS DE PRODUCTOS
// ═══════════════════════════════════════════════════════════

$(document).ready(function () {
    activarMenu("Reportes");

    // Fecha de hoy por defecto
    var hoy = new Date().toISOString().split('T')[0];
    $("#txtFechaInicio").val(hoy);
    $("#txtFechaFin").val(hoy);

    // Cargar tiendas (solo SuperAdmin verá el select real)
    if ($("#cboTienda").is("select")) {
        $.ajax({
            url: $.MisUrls.url._ObtenerTiendas,
            type: "GET",
            dataType: "json",
            success: function (data) {
                var $cbo = $("#cboTienda");
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
    var fechaInicio = $("#txtFechaInicio").val();
    var fechaFin    = $("#txtFechaFin").val();

    if (!fechaInicio || !fechaFin) {
        Swal.fire("Atención", "Debe seleccionar un rango de fechas.", "warning");
        return;
    }
    if (fechaInicio > fechaFin) {
        Swal.fire("Atención", "La fecha inicio no puede ser mayor a la fecha fin.", "warning");
        return;
    }

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteTraslados,
        type: "GET",
        data: {
            fechainicio:    fechaInicio,
            fechafin:       fechaFin,
            idtienda:       $("#cboTienda").val(),
            estadotraslado: $("#cboEstado").val()
        },
        dataType: "json",
        beforeSend: function () {
            $("#tbReporte tbody").html(
                '<tr><td colspan="10" class="text-center">' +
                '<i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>'
            );
            $("#btnBuscar").prop("disabled", true);
            $("#btnExportarPDF").prop("disabled", true);
        },
        success: function (data) {
            var $tbody = $("#tbReporte tbody");
            $tbody.empty();

            if (!data || data.length === 0) {
                $tbody.html(
                    '<tr><td colspan="10" class="text-center text-muted py-3">' +
                    'No se encontraron traslados en el período seleccionado.</td></tr>'
                );
                return;
            }

            $.each(data, function (i, row) {
                var estado   = row.EstadoAprobacion || 'Pendiente';
                var badgeCls = estado === 'Aprobada'  ? 'success'
                             : estado === 'Rechazada' ? 'danger'
                             : 'warning';
                var $badge   = $('<span class="badge badge-' + badgeCls + ' badge-estado">')
                                 .text(estado);
                var rowClass = estado === 'Pendiente'  ? 'table-warning'
                             : estado === 'Rechazada'  ? 'table-danger'
                             : '';

                var $tr = $('<tr>').addClass(rowClass).append(
                    $('<td>').text(row.Numero          || ''),
                    $('<td>').text(row.FechaTraslado   || ''),
                    $('<td>').text(row.CodigoProducto  || ''),
                    $('<td>').text(row.NombreProducto  || ''),
                    $('<td class="text-center">').text(row.Cantidad || 0),
                    $('<td>').text(row.TiendaOrigen    || ''),
                    $('<td>').text(row.TiendaDestino   || ''),
                    $('<td class="text-center">').append($badge),
                    $('<td>').text(row.Usuario         || ''),
                    $('<td>').text(row.UsuarioAprueba  || '')
                );

                // Fila extra para motivo de rechazo
                if (estado === 'Rechazada' && row.MotivoRechazo) {
                    var $trDetalle = $('<tr class="table-danger">').append(
                        $('<td colspan="10" class="py-1 pl-4 text-muted" style="font-size:0.82em;">')
                          .html('<i class="fas fa-exclamation-circle text-danger mr-1"></i>' +
                                '<strong>Motivo de rechazo:</strong> ' +
                                $('<span>').text(row.MotivoRechazo).html())
                    );
                    $tbody.append($tr).append($trDetalle);
                } else {
                    $tbody.append($tr);
                }
            });

            $("#btnExportarPDF").prop("disabled", false);
        },
        error: function () {
            $("#tbReporte tbody").html(
                '<tr><td colspan="10" class="text-center text-danger">' +
                'Error al cargar los datos.</td></tr>'
            );
            Swal.fire("Error", "No se pudo obtener el reporte.", "error");
        },
        complete: function () {
            $("#btnBuscar").prop("disabled", false);
        }
    });
});

// ── Exportar PDF (via server — Python + membrete) ─────────
function exportarPDF() {
    if ($('#tbReporte tbody tr td[colspan]').length > 0 ||
        $('#tbReporte tbody tr').length === 0) {
        Swal.fire('Atención', 'No hay datos para exportar.', 'warning');
        return;
    }
    $('#hTrasladoFechaInicio').val($('#txtFechaInicio').val());
    $('#hTrasladoFechaFin').val($('#txtFechaFin').val());
    $('#hTrasladoIdTienda').val($('#cboTienda').val() || 0);
    $('#hTrasladoEstado').val($('#cboEstado').val() || '');
    $('#frmPDFTraslados').submit();
}
