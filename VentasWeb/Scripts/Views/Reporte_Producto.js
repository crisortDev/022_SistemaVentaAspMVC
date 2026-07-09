// ═══════════════════════════════════════════════════════════
//  REPORTE GERENCIAL — PRODUCTOS POR TIENDA
// ═══════════════════════════════════════════════════════════

var _datosProducto = [];

$(document).ready(function () {
    activarMenu('Reportes');

    // Cargar combo tiendas (solo SuperAdmin)
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: 'GET',
        dataType: 'json',
        success: function (data) {
            var $cbo = $('#cboTienda');
            if ($cbo.is('select')) {
                $cbo.empty().append('<option value="0">-- Todas las sucursales --</option>');
                var lista = data.data || data;
                $.each(lista, function (i, item) {
                    if (item.Activo) {
                        $cbo.append($('<option>').val(item.IdTienda).text(item.Nombre));
                    }
                });
            }
        }
    });
});

// ── Buscar ─────────────────────────────────────────────────
$('#btnBuscar').on('click', function () {
    var idTienda   = $('#cboTienda').val()              || 0;
    var codigo     = $('#txtCodigoProducto').val().trim();
    var filtroStock= $('#cboFiltroStock').val()         || '';

    $.ajax({
        url: $.MisUrls.url._ObtenerReporteProducto,
        type: 'GET',
        data: { idtienda: idTienda, codigoproducto: codigo },
        dataType: 'json',
        beforeSend: function () {
            $('#contenedorProductos').html(
                '<p class="text-center text-muted"><i class="fas fa-spinner fa-spin"></i> Cargando...</p>'
            );
            $('#panelKPI, #panelAnalisis').addClass('d-none');
            $('#btnBuscar').prop('disabled', true);
            $('#btnExportarPDF').prop('disabled', true);
        },
        success: function (data) {
            if (!data || data.length === 0) {
                _datosProducto = [];
                $('#contenedorProductos').html(
                    '<p class="text-center text-muted py-3">No se encontraron productos para los filtros seleccionados.</p>'
                );
                return;
            }

            // Aplicar filtro de stock del lado cliente
            _datosProducto = data;
            var filtrados = aplicarFiltroStock(data, filtroStock);

            renderizarTodo(filtrados);
            $('#btnExportarPDF').prop('disabled', false);
        },
        error: function () {
            _datosProducto = [];
            $('#contenedorProductos').html(
                '<p class="text-center text-danger">Error al cargar los datos.</p>'
            );
            Swal.fire('Error', 'No se pudo obtener el reporte.', 'error');
        },
        complete: function () {
            $('#btnBuscar').prop('disabled', false);
        }
    });
});

// ── Filtro de stock (cliente) ───────────────────────────────
function aplicarFiltroStock(data, filtro) {
    if (!filtro) return data;
    return data.filter(function (p) {
        var stock = parseInt(p.StockenTienda) || 0;
        if (filtro === 'con')     return stock > 0;
        if (filtro === 'sin')     return stock === 0;
        if (filtro === 'critico') return stock > 0 && stock <= 5;
        return true;
    });
}

// ── Orquestador ────────────────────────────────────────────
function renderizarTodo(datos) {
    renderizarKPIs(datos);
    renderizarTopStock(datos);
    renderizarSinStock(datos);
    renderizarRangoPrecios(datos);
    renderizarMargen(datos);
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

function parseStock(v) {
    var n = parseInt(String(v).replace(/,/g, ''), 10);
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
    var total      = datos.length;
    var stockTotal = 0, valorCosto = 0, potVenta = 0;
    var sinStock = 0, critico = 0;
    var margenes = [];

    datos.forEach(function (p) {
        var stock  = parseStock(p.StockenTienda);
        var compra = parseNum(p.PrecioCompra);
        var venta  = parseNum(p.PrecioVenta);

        stockTotal += stock;
        valorCosto += stock * compra;
        potVenta   += stock * venta;

        if (stock === 0)          sinStock++;
        else if (stock <= 5)      critico++;

        if (compra > 0) margenes.push((venta - compra) / compra * 100);
    });

    var margenProm = margenes.length > 0
        ? (margenes.reduce(function (a, b) { return a + b; }, 0) / margenes.length)
        : 0;
    var ganancia = potVenta - valorCosto;

    $('#kpiTotalProductos').text(total);
    $('#kpiStockTotal').text(stockTotal.toLocaleString('es-PY'));
    $('#kpiValorCosto').text(fmtGS(valorCosto));
    $('#kpiPotencialVenta').text(fmtGS(potVenta));
    $('#kpiSinStock').text(sinStock);
    $('#kpiStockCritico').text(critico);
    $('#kpiMargenPromedio').text(margenProm.toFixed(1) + '%');
    $('#kpiGanancia').text(fmtGS(ganancia));
}

// ── Top 10 por Stock ───────────────────────────────────────
function renderizarTopStock(datos) {
    var sorted = datos.slice().sort(function (a, b) {
        return parseStock(b.StockenTienda) - parseStock(a.StockenTienda);
    }).slice(0, 10);

    var maxStock = sorted.length > 0 ? parseStock(sorted[0].StockenTienda) : 1;

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Código</th><th>Producto</th>'
        + '<th class="text-center">Stock</th><th>Gráfico</th></tr></thead><tbody>';

    sorted.forEach(function (p) {
        var stock = parseStock(p.StockenTienda);
        var bars  = barra(stock, maxStock, 16);
        html += '<tr>'
            + '<td>' + (p.CodigoProducto || '') + '</td>'
            + '<td>' + (p.NombreProducto || '') + '</td>'
            + '<td class="text-center font-weight-bold">' + stock + '</td>'
            + '<td><span class="text-info">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaTopStock').html(html);
}

// ── Sin Stock ──────────────────────────────────────────────
function renderizarSinStock(datos) {
    var sinStock = datos.filter(function (p) { return parseStock(p.StockenTienda) === 0; });

    if (sinStock.length === 0) {
        $('#tablaSinStock').html(
            '<div class="alert alert-success py-2" style="font-size:12px;">'
            + '<i class="fas fa-check-circle mr-1"></i> Todos los productos tienen stock disponible.'
            + '</div>'
        );
        return;
    }

    var html = '<div class="alert alert-danger py-1 mb-1" style="font-size:11px;">'
        + '<i class="fas fa-exclamation-circle mr-1"></i> <strong>' + sinStock.length + '</strong> producto(s) sin stock'
        + '</div>'
        + '<div style="max-height:200px; overflow-y:auto;">'
        + '<table class="table table-sm table-bordered" style="font-size:11px;">'
        + '<thead class="thead-danger"><tr><th>Código</th><th>Producto</th><th class="text-right">P. Venta</th></tr></thead><tbody>';

    sinStock.forEach(function (p) {
        html += '<tr class="table-danger">'
            + '<td>' + (p.CodigoProducto || '') + '</td>'
            + '<td>' + (p.NombreProducto || '') + '</td>'
            + '<td class="text-right">' + fmtGS(p.PrecioVenta) + '</td>'
            + '</tr>';
    });

    html += '</tbody></table></div>';
    $('#tablaSinStock').html(html);
}

// ── Distribución por Rango de Precio ──────────────────────
function renderizarRangoPrecios(datos) {
    var rangos = [
        { label: 'Económico (< Gs. 100.000)',           min: 0,       max: 100000 },
        { label: 'Intermedio (Gs. 100.000 – 500.000)',  min: 100000,  max: 500000 },
        { label: 'Superior (Gs. 500.000 – 2.000.000)',  min: 500000,  max: 2000000 },
        { label: 'Premium (> Gs. 2.000.000)',           min: 2000000, max: Infinity }
    ];

    rangos.forEach(function (r) { r.cantidad = 0; r.stockTotal = 0; r.valorCosto = 0; });

    datos.forEach(function (p) {
        var venta = parseNum(p.PrecioVenta);
        var stock = parseStock(p.StockenTienda);
        var compra= parseNum(p.PrecioCompra);
        for (var i = 0; i < rangos.length; i++) {
            if (venta >= rangos[i].min && venta < rangos[i].max) {
                rangos[i].cantidad++;
                rangos[i].stockTotal  += stock;
                rangos[i].valorCosto  += stock * compra;
                break;
            }
        }
    });

    var maxCant = Math.max.apply(null, rangos.map(function (r) { return r.cantidad; })) || 1;

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Rango</th><th class="text-center">Cant.</th>'
        + '<th class="text-center">Stock</th><th>Gráfico</th></tr></thead><tbody>';

    var rowClasses = ['', 'table-success', 'table-info', 'table-warning'];
    rangos.forEach(function (r, i) {
        var bars = barra(r.cantidad, maxCant, 16);
        html += '<tr class="' + rowClasses[i] + '">'
            + '<td>' + r.label + '</td>'
            + '<td class="text-center font-weight-bold">' + r.cantidad + '</td>'
            + '<td class="text-center">' + r.stockTotal + '</td>'
            + '<td><span class="text-info">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaRangoPrecios').html(html);
}

// ── Top 10 por Margen % ────────────────────────────────────
function renderizarMargen(datos) {
    var conMargen = datos
        .filter(function (p) { return parseNum(p.PrecioCompra) > 0; })
        .map(function (p) {
            var compra = parseNum(p.PrecioCompra);
            var venta  = parseNum(p.PrecioVenta);
            return {
                codigo:  p.CodigoProducto,
                nombre:  p.NombreProducto,
                compra:  compra,
                venta:   venta,
                margen:  (venta - compra) / compra * 100
            };
        })
        .sort(function (a, b) { return b.margen - a.margen; })
        .slice(0, 10);

    var maxMargen = conMargen.length > 0 ? conMargen[0].margen : 1;

    var html = '<table class="table table-sm table-bordered" style="font-size:12px;">'
        + '<thead class="thead-dark"><tr><th>Código</th><th>Producto</th>'
        + '<th class="text-right">P. Venta</th><th class="text-center">Margen</th><th>Gráfico</th></tr></thead><tbody>';

    conMargen.forEach(function (p, i) {
        var bars  = barra(p.margen, maxMargen, 14);
        var clase = p.margen >= 50 ? 'text-success' : p.margen >= 20 ? 'text-info' : 'text-warning';
        html += '<tr>'
            + '<td>' + (p.codigo || '') + '</td>'
            + '<td>' + (p.nombre || '') + '</td>'
            + '<td class="text-right">' + fmtGS(p.venta) + '</td>'
            + '<td class="text-center font-weight-bold ' + clase + '">' + p.margen.toFixed(1) + '%</td>'
            + '<td><span class="' + clase + '">' + bars + '</span></td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#tablaMargen').html(html);
}

// ── Análisis Gerencial ──────────────────────────────────────
function renderizarAnalisis(datos) {
    var total      = datos.length;
    var stockTotal = 0, valorCosto = 0, potVenta = 0;
    var sinStock   = 0, critico = 0;
    var margenes   = [];
    var prodMaxStock = null, maxStock = -1;
    var prodMaxMargen= null, maxMargen = -Infinity;

    datos.forEach(function (p) {
        var stock  = parseStock(p.StockenTienda);
        var compra = parseNum(p.PrecioCompra);
        var venta  = parseNum(p.PrecioVenta);
        var margen = compra > 0 ? (venta - compra) / compra * 100 : 0;

        stockTotal += stock;
        valorCosto += stock * compra;
        potVenta   += stock * venta;
        if (stock === 0) sinStock++;
        else if (stock <= 5) critico++;
        if (compra > 0) margenes.push(margen);

        if (stock > maxStock) { maxStock = stock; prodMaxStock = p; }
        if (compra > 0 && margen > maxMargen) { maxMargen = margen; prodMaxMargen = p; }
    });

    var margenProm = margenes.length > 0
        ? (margenes.reduce(function (a, b) { return a + b; }, 0) / margenes.length)
        : 0;

    var filas = [
        ['Total de productos relevados',          total],
        ['Stock total disponible',                stockTotal.toLocaleString('es-PY') + ' unidades'],
        ['Valor del inventario a costo',           fmtGS(valorCosto)],
        ['Potencial de venta (stock × P.Venta)',   fmtGS(potVenta)],
        ['Ganancia potencial',                     fmtGS(potVenta - valorCosto)],
        ['Margen promedio',                        margenProm.toFixed(1) + '%'],
        ['Productos sin stock',                    sinStock + ' (' + (total > 0 ? (sinStock/total*100).toFixed(1) : 0) + '%)'],
        ['Productos en stock crítico (≤ 5)',       critico],
        ['Producto con mayor stock',               prodMaxStock ? (prodMaxStock.NombreProducto + ' — ' + maxStock + ' u.') : '—'],
        ['Producto con mayor margen',              prodMaxMargen ? (prodMaxMargen.NombreProducto + ' — ' + maxMargen.toFixed(1) + '%') : '—'],
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
    var mostrarTienda = parseInt($('#cboTienda').val()) === 0;

    // Header
    var hdrTienda = mostrarTienda
        ? '<th>Sucursal</th>'
        : '';

    var html = '<table id="tbReporte" class="table table-sm table-bordered table-hover" style="width:100%; font-size:12px;">'
        + '<thead class="thead-dark"><tr>'
        + hdrTienda
        + '<th>Código</th><th>Producto</th><th>Descripción</th>'
        + '<th class="text-center">Stock</th>'
        + '<th class="text-right">P. Compra</th>'
        + '<th class="text-right">P. Venta</th>'
        + '<th class="text-center">Margen</th>'
        + '<th class="text-right">Valor Inv.</th>'
        + '</tr></thead><tbody>';

    datos.forEach(function (p) {
        var stock  = parseStock(p.StockenTienda);
        var compra = parseNum(p.PrecioCompra);
        var venta  = parseNum(p.PrecioVenta);
        var margen = compra > 0 ? (venta - compra) / compra * 100 : 0;
        var valorInv = stock * compra;

        var stockBadge;
        if (stock === 0)         stockBadge = '<span class="badge badge-danger">0</span>';
        else if (stock <= 5)     stockBadge = '<span class="badge badge-warning">' + stock + '</span>';
        else                     stockBadge = '<span class="badge badge-success">' + stock + '</span>';

        var margenClass = margen >= 50 ? 'text-success' : margen >= 20 ? 'text-info' : margen > 0 ? 'text-warning' : 'text-muted';

        html += '<tr>'
            + (mostrarTienda ? '<td>' + (p.NombreTienda || '') + '</td>' : '')
            + '<td>' + (p.CodigoProducto || '') + '</td>'
            + '<td>' + (p.NombreProducto || '') + '</td>'
            + '<td style="max-width:150px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;" title="' + (p.DescripcionProducto || '') + '">'
                + (p.DescripcionProducto || '—') + '</td>'
            + '<td class="text-center">' + stockBadge + '</td>'
            + '<td class="text-right">' + fmtGS(compra) + '</td>'
            + '<td class="text-right">' + fmtGS(venta) + '</td>'
            + '<td class="text-center ' + margenClass + ' font-weight-bold">' + (compra > 0 ? margen.toFixed(1) + '%' : '—') + '</td>'
            + '<td class="text-right">' + fmtGS(valorInv) + '</td>'
            + '</tr>';
    });

    html += '</tbody></table>';
    $('#contenedorProductos').html(html);

    $('#tbReporte').DataTable({
        language:   $.fn.dataTable.defaults.oLanguage,
        pageLength: 25,
        order:      [[mostrarTienda ? 4 : 3, 'desc']],   // ordenar por Stock desc
        columnDefs: [
            { orderable: false, targets: mostrarTienda ? 3 : 2 }  // Descripción no ordenable
        ]
    });
}

// ── Exportar PDF ────────────────────────────────────────────
function exportarPDF() {
    if (_datosProducto.length === 0) {
        Swal.fire('Atención', 'No hay datos para exportar.', 'warning');
        return;
    }
    $('#hProdIdTienda').val($('#cboTienda').val() || 0);
    $('#hProdCodigo').val($('#txtCodigoProducto').val().trim());
    $('#frmPDFProd').submit();
}
