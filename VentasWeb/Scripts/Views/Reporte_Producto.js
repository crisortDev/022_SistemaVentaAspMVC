// ═══════════════════════════════════════════════════════════
//  REPORTE — PRODUCTOS POR TIENDA
// ═══════════════════════════════════════════════════════════

$(document).ready(function () {
    activarMenu("Reportes");

    // Cargar combo tiendas (solo para SuperAdmin)
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: 'GET',
        dataType: 'json',
        success: function (data) {
            var $cbo = $('#cboTienda');
            if ($cbo.is('select')) {
                $cbo.empty();
                $cbo.append('<option value="0">-- Todas las sucursales --</option>');
                var lista = data.data || data;
                if (lista && lista.length > 0) {
                    $.each(lista, function (i, item) {
                        if (item.Activo) {
                            $cbo.append($('<option>').val(item.IdTienda).text(item.Nombre));
                        }
                    });
                }
            }
        },
        error: function () {
            console.error('Error al cargar tiendas.');
        }
    });
});

// ── Buscar ────────────────────────────────────────────────
$('#btnBuscar').on('click', function () {
    var idTienda       = $('#cboTienda').val();
    var codigoProducto = $('#txtCodigoProducto').val().trim();

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteProducto,
        type: 'GET',
        data: { idtienda: idTienda, codigoproducto: codigoProducto },
        dataType: 'json',
        beforeSend: function () {
            $('#tbReporte tbody').html(
                '<tr><td colspan="9" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>'
            );
            $('#btnBuscar').prop('disabled', true);
            $('#btnExportarPDF').prop('disabled', true);
        },
        success: function (data) {
            var $tbody = $('#tbReporte tbody');
            $tbody.empty();

            if (!data || data.length === 0) {
                $tbody.html('<tr><td colspan="9" class="text-center text-muted py-3">No se encontraron resultados.</td></tr>');
                return;
            }

            $.each(data, function (i, row) {
                $('<tr>').append(
                    $('<td>').text(row.NombreTienda     || ''),
                    $('<td>').text(row.RucTienda        || ''),
                    $('<td>').text(row.DireccionTienda  || ''),
                    $('<td>').text(row.CodigoProducto   || ''),
                    $('<td>').text(row.NombreProducto   || ''),
                    $('<td>').text(row.DescripcionProducto || ''),
                    $('<td class="text-center">').text(row.StockenTienda || 0),
                    $('<td class="text-right">').text('Gs. ' + formatGS(row.PrecioCompra)),
                    $('<td class="text-right">').text('Gs. ' + formatGS(row.PrecioVenta))
                ).appendTo($tbody);
            });

            $('#btnExportarPDF').prop('disabled', false);
        },
        error: function () {
            $('#tbReporte tbody').html(
                '<tr><td colspan="9" class="text-center text-danger">Error al cargar los datos.</td></tr>'
            );
            Swal.fire('Error', 'No se pudo obtener el reporte.', 'error');
        },
        complete: function () {
            $('#btnBuscar').prop('disabled', false);
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

    $('#hProdIdTienda').val($('#cboTienda').val() || 0);
    $('#hProdCodigo').val($('#txtCodigoProducto').val().trim());
    $('#frmPDFProd').submit();
}

// ── Formato Guaraní ───────────────────────────────────────
function formatGS(v) {
    var n = parseFloat(String(v).replace(/,/g, ''));
    if (isNaN(n)) return '0';
    return Math.round(n).toLocaleString('es-PY');
}
