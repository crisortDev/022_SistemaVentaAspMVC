$(document).ready(function () {
    activarMenu("Reportes");

    // OBTENER TIENDAS
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        success: function (data) {
            var $cbo = $("#cboTienda");
            $cbo.empty();
            $cbo.append('<option value="0">-- Seleccionar todas --</option>');

            var lista = data.data || data; // soporta { data: [] } o array directo
            if (lista && lista.length > 0) {
                $.each(lista, function (i, item) {
                    if (item.Activo) {
                        $cbo.append($('<option>').val(item.IdTienda).text(item.Nombre));
                    }
                });
            } else {
                console.warn("No se recibieron tiendas activas.");
            }
        },
        error: function (xhr, status, error) {
            console.error("Error al obtener tiendas:", status, error);
            Swal.fire("Error", "No se pudieron cargar las tiendas.", "error");
        }
    });
});

// BUSCAR REPORTE
$('#btnBuscar').on('click', function () {
    var idTienda = $("#cboTienda").val();
    var codigoProducto = $("#txtCodigoProducto").val().trim();

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteProducto,
        type: "GET",
        data: {
            idtienda: idTienda,
            codigoproducto: codigoProducto
        },
        dataType: "json",
        beforeSend: function () {
            $("#tbReporte tbody").html(
                '<tr><td colspan="9" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>'
            );
            $("#btnBuscar").prop("disabled", true);
        },
        success: function (data) {
            var $tbody = $("#tbReporte tbody");
            $tbody.empty();

            if (!data || data.length === 0) {
                $tbody.html('<tr><td colspan="9" class="text-center text-muted">No se encontraron resultados.</td></tr>');
                return;
            }

            $.each(data, function (i, row) {
                $("<tr>").append(
                    $("<td>").text(row.RucTienda || ""),
                    $("<td>").text(row.NombreTienda || ""),
                    $("<td>").text(row.DireccionTienda || ""),
                    $("<td>").text(row.CodigoProducto || ""),
                    $("<td>").text(row.NombreProducto || ""),
                    $("<td>").text(row.DescripcionProducto || ""),
                    $("<td>").text(row.StockenTienda || 0),
                    $("<td>").text(row.PrecioCompra || 0),
                    $("<td>").text(row.PrecioVenta || 0)
                ).appendTo($tbody);
            });
        },
        error: function (xhr, status, error) {
            console.error("Error al obtener reporte:", status, error);
            $("#tbReporte tbody").html(
                '<tr><td colspan="9" class="text-center text-danger">Error al cargar los datos.</td></tr>'
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
        $('#tbReporte tbody tr td').length === 1) {
        Swal.fire("Mensaje", "No existen datos para imprimir", "warning");
        return;
    }

    var divToPrint = document.getElementById("tbReporte");
    var style = "<style>" +
        "table {width:100%; font:17px Calibri;}" +
        "table, th, td {border:solid 1px #DDD; border-collapse:collapse; padding:2px 3px; text-align:center;}" +
        "</style>";

    var newWin = window.open("");
    newWin.document.write(style);
    newWin.document.write("<h3>Reporte de productos por tienda</h3>");
    newWin.document.write(divToPrint.outerHTML);
    newWin.print();
    newWin.close();
}