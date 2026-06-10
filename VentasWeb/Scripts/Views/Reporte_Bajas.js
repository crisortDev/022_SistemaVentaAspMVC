$(document).ready(function () {
    activarMenu("Reportes");

    // Fecha de hoy por defecto en ambos campos
    var hoy = new Date().toISOString().split('T')[0];
    $("#txtFechaInicio").val(hoy);
    $("#txtFechaFin").val(hoy);

    // Cargar tiendas
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        success: function (data) {
            var $cbo = $("#cboTienda");
            $cbo.empty();
            $cbo.append('<option value="0">-- Todas las tiendas --</option>');
            var lista = data.data || data;
            if (lista && lista.length > 0) {
                $.each(lista, function (i, item) {
                    if (item.Activo)
                        $cbo.append($('<option>').val(item.IdTienda).text(item.Nombre));
                });
            }
        },
        error: function () {
            Swal.fire("Error", "No se pudieron cargar las tiendas.", "error");
        }
    });
});

// BUSCAR
$('#btnBuscar').on('click', function () {
    var fechaInicio = $("#txtFechaInicio").val();
    var fechaFin = $("#txtFechaFin").val();

    if (!fechaInicio || !fechaFin) {
        Swal.fire("Atenci�n", "Debe seleccionar un rango de fechas.", "warning");
        return;
    }
    if (fechaInicio > fechaFin) {
        Swal.fire("Atenci�n", "La fecha inicio no puede ser mayor a la fecha fin.", "warning");
        return;
    }

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteBajas,
        type: "GET",
        data: {
            fechainicio: fechaInicio,
            fechafin: fechaFin,
            idtienda: $("#cboTienda").val()
        },
        dataType: "json",
        beforeSend: function () {
            $("#tbReporte tbody").html(
                '<tr><td colspan="7" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>'
            );
            $("#btnBuscar").prop("disabled", true);
        },
        success: function (data) {
            var $tbody = $("#tbReporte tbody");
            $tbody.empty();

            if (!data || data.length === 0) {
                $tbody.html('<tr><td colspan="7" class="text-center text-muted">No se encontraron bajas en el per�odo seleccionado.</td></tr>');
                return;
            }

            $.each(data, function (i, row) {
                $("<tr>").append(
                    $("<td>").text(row.FechaMovimiento || ""),
                    $("<td>").text(row.NombreTienda || ""),
                    $("<td>").text(row.CodigoProducto || ""),
                    $("<td>").text(row.NombreProducto || ""),
                    $("<td>").text(row.Cantidad || 0),
                    $("<td>").text(row.Observaciones || ""),
                    $("<td>").text(row.RucTienda || "")
                ).appendTo($tbody);
            });
        },
        error: function () {
            $("#tbReporte tbody").html(
                '<tr><td colspan="7" class="text-center text-danger">Error al cargar los datos.</td></tr>'
            );
            Swal.fire("Error", "No se pudo obtener el reporte.", "error");
        },
        complete: function () {
            $("#btnBuscar").prop("disabled", false);
        }
    });
});

// IMPRIMIR
function printData() {
    if ($('#tbReporte tbody tr').length === 0 ||
        $('#tbReporte tbody tr:first td').length === 1) {
        Swal.fire("Mensaje", "No existen datos para imprimir.", "warning");
        return;
    }

    var divToPrint = document.getElementById("tbReporte");
    var style = "<style>" +
        "table { width:100%; font:15px Calibri; }" +
        "table, th, td { border:solid 1px #DDD; border-collapse:collapse; padding:3px 6px; }" +
        "th { background:#17a2b8; color:#fff; }" +
        "</style>";

    var newWin = window.open("");
    newWin.document.write(style);
    newWin.document.write("<h3>Reporte de Bajas de Productos</h3>");
    newWin.document.write(divToPrint.outerHTML);
    newWin.print();
    newWin.close();
}