// ═══════════════════════════════════════════════════════════════════
//  REPORTE — RENTABILIDAD POR PRODUCTO (CPP)
//  Costo Promedio Ponderado / Inventario Permanente Móvil
// ═══════════════════════════════════════════════════════════════════
'use strict';

var _datosRent = [];

$(document).ready(function () {
    var hoy       = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    $('#txtFechaInicio').val(primerDia.toISOString().slice(0, 10));
    $('#txtFechaFin').val(hoy.toISOString().slice(0, 10));

    cargarTiendas();
    cargarCategorias();
});

// ── Combos auxiliares ────────────────────────────────────────────────
function cargarTiendas() {
    $.get('/Inventario/ObtenerTiendas', function (res) {
        var opts = '<option value="0">-- Todas las tiendas --</option>';
        (res.data || []).forEach(function (t) {
            if (t.Activo) opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $('#cboTienda').html(opts);
    });
}

function cargarCategorias() {
    $.get('/Reporte/ObtenerCategorias', function (res) {
        var datos = res.data || res || [];
        if (!Array.isArray(datos)) return;
        var opts = '<option value="0">-- Todas las categorías --</option>';
        datos.forEach(function (c) {
            opts += '<option value="' + (c.IdCategoria || c.id) + '">' + (c.Nombre || c.nombre) + '</option>';
        });
        $('#cboCategoria').html(opts);
    }).fail(function () { /* si no existe el endpoint, el combo queda con "Todas" */ });
}

// ── Buscar ───────────────────────────────────────────────────────────
function buscarRentabilidad() {
    var params = {
        fechainicio:  $('#txtFechaInicio').val(),
        fechafin:     $('#txtFechaFin').val(),
        idtienda:     parseInt($('#cboTienda').val())    || 0,
        idcategoria:  parseInt($('#cboCategoria').val()) || 0
    };

    if (!params.fechainicio || !params.fechafin) {
        toastr.warning('Seleccioná un rango de fechas.');
        return;
    }

    $('body').LoadingOverlay('show');

    $.get($.MisUrls.url._Reporte_ObtenerRentabilidad, params, function (res) {
        _datosRent = res.data || [];
        renderizarTabla();
        $('#btnExportarPDF').prop('disabled', _datosRent.length === 0);
    }).fail(function () {
        $('#contenedorRentabilidad').html(
            '<p class="text-danger text-center">Error al cargar el reporte. Verificá la conexión.</p>'
        );
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Renderizar tabla ─────────────────────────────────────────────────
function renderizarTabla() {
    var cont = $('#contenedorRentabilidad');

    if (_datosRent.length === 0) {
        cont.html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        $('#panelResumen').addClass('d-none');
        return;
    }

    var sumIngresos = 0, sumCosto = 0, sumUtilidad = 0, sumInventario = 0;

    var filas = '';
    _datosRent.forEach(function (r) {
        sumIngresos   += r.IngresosTotales;
        sumCosto      += r.CostoTotalVentas;
        sumUtilidad   += r.UtilidadBruta;
        sumInventario += r.ValorInventarioCPP;

        var margenClass = r.MargenBrutoPct >= 20 ? 'text-success font-weight-bold'
                        : r.MargenBrutoPct >= 10  ? 'text-warning font-weight-bold'
                        : r.MargenBrutoPct >  0   ? 'text-secondary'
                        : 'text-danger font-weight-bold';

        var utilClass = r.UtilidadBruta >= 0 ? 'text-success' : 'text-danger';

        filas +=
            '<tr>' +
            '<td><code>' + (r.Codigo || '—') + '</code></td>' +
            '<td>' + r.Producto + '<br><small class="text-muted">' + (r.Categoria || '—') + '</small></td>' +
            '<td class="text-center">' + r.StockActual + '</td>' +
            '<td class="text-right text-muted">Gs. ' + formatGS(r.CostoPromedio) + '</td>' +
            '<td class="text-right">Gs. ' + formatGS(r.PrecioVentaVigente) + '</td>' +
            '<td class="text-center">' + r.UnidadesVendidas + '</td>' +
            '<td class="text-right">Gs. ' + formatGS(r.IngresosTotales) + '</td>' +
            '<td class="text-right">Gs. ' + formatGS(r.CostoTotalVentas) + '</td>' +
            '<td class="text-right ' + utilClass + '">Gs. ' + formatGS(r.UtilidadBruta) + '</td>' +
            '<td class="text-center ' + margenClass + '">' + r.MargenBrutoPct.toFixed(1) + '%</td>' +
            '<td class="text-right text-info">Gs. ' + formatGS(r.ValorInventarioCPP) + '</td>' +
            '</tr>';
    });

    var html =
        '<table class="table table-striped table-bordered table-sm" id="tblRentabilidad" style="width:100%;font-size:12px;">' +
        '<thead class="thead-dark">' +
        '<tr>' +
        '<th>Código</th>' +
        '<th>Producto / Categoría</th>' +
        '<th class="text-center">Stock</th>' +
        '<th class="text-right">CPP (Gs.)</th>' +
        '<th class="text-right">P. Venta (Gs.)</th>' +
        '<th class="text-center">Uds. Vendidas</th>' +
        '<th class="text-right">Ingresos (Gs.)</th>' +
        '<th class="text-right">Costo CPP (Gs.)</th>' +
        '<th class="text-right">Utilidad Bruta</th>' +
        '<th class="text-center">Margen %</th>' +
        '<th class="text-right">Valor Inv. (Gs.)</th>' +
        '</tr>' +
        '</thead>' +
        '<tbody>' + filas + '</tbody>' +
        '</table>';

    cont.html(html);

    // Inicializar DataTable para ordenar/buscar
    if ($.fn.DataTable.isDataTable('#tblRentabilidad')) {
        $('#tblRentabilidad').DataTable().destroy();
    }
    $('#tblRentabilidad').DataTable({
        paging:   true,
        pageLength: 25,
        order:    [[9, 'desc']],   // Ordenar por Margen% desc por defecto
        language: { url: $.MisUrls.url.Url_datatable_spanish }
    });

    // Actualizar panel resumen
    var margenGlobal = sumIngresos > 0
        ? ((sumUtilidad / sumIngresos) * 100).toFixed(1) + '%'
        : '0%';

    $('#lblTotalIngresos').text('Gs. ' + formatGS(sumIngresos));
    $('#lblTotalCosto').text('Gs. ' + formatGS(sumCosto));
    $('#lblTotalUtilidad').html(
        'Gs. ' + formatGS(sumUtilidad) +
        ' <small class="text-muted">(' + margenGlobal + ')</small>'
    );
    $('#lblTotalInventario').text('Gs. ' + formatGS(sumInventario));
    $('#panelResumen').removeClass('d-none');
}

// ── Exportar PDF ─────────────────────────────────────────────────────
function exportarPDF() {
    if (_datosRent.length === 0) return;

    var doc = new jsPDF('l', 'mm', 'a4');  // landscape para más columnas
    var fi  = $('#txtFechaInicio').val();
    var ff  = $('#txtFechaFin').val();

    doc.setFontSize(14);
    doc.text('Reporte de Rentabilidad por Producto (CPP)', 14, 15);
    doc.setFontSize(9);
    doc.text('Período: ' + fi + ' al ' + ff, 14, 21);
    doc.text('Método: Costo Promedio Ponderado (Inventario Permanente Móvil)', 14, 26);

    var columnas = [
        'Código', 'Producto', 'Stock', 'CPP (Gs.)', 'P.Venta (Gs.)',
        'Uds.Vend.', 'Ingresos', 'Costo CPP', 'Utilidad', 'Margen%', 'Val.Inv.'
    ];

    var filas = _datosRent.map(function (r) {
        return [
            r.Codigo,
            r.Producto,
            r.StockActual,
            'Gs. ' + formatGS(r.CostoPromedio),
            'Gs. ' + formatGS(r.PrecioVentaVigente),
            r.UnidadesVendidas,
            'Gs. ' + formatGS(r.IngresosTotales),
            'Gs. ' + formatGS(r.CostoTotalVentas),
            'Gs. ' + formatGS(r.UtilidadBruta),
            r.MargenBrutoPct.toFixed(1) + '%',
            'Gs. ' + formatGS(r.ValorInventarioCPP)
        ];
    });

    doc.autoTable({
        head:       [columnas],
        body:       filas,
        startY:     30,
        styles:     { fontSize: 7, cellPadding: 1.5 },
        headStyles: { fillColor: [40, 167, 69], textColor: 255 },
        alternateRowStyles: { fillColor: [240, 255, 240] },
        didParseCell: function (data) {
            // Colorear margen negativo en rojo
            if (data.column.index === 9 && data.section === 'body') {
                var val = parseFloat(data.cell.raw);
                if (!isNaN(val) && val < 0) {
                    data.cell.styles.textColor = [220, 53, 69];
                }
            }
        }
    });

    doc.save('Rentabilidad_CPP_' + fi + '_' + ff + '.pdf');
}

// ── Helpers ──────────────────────────────────────────────────────────
function formatGS(n) {
    return Math.round(n || 0).toLocaleString('es-PY');
}
