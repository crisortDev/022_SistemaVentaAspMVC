// ═══════════════════════════════════════════════════════════
//  INVENTARIO — STOCK POR TIENDA (agrupado por tienda/categoría)
// ═══════════════════════════════════════════════════════════

var _datosStock = [];   // cache de datos cargados

$(document).ready(function () {
    activarMenu("Stock por Tienda");
    cargarTiendas();
    buscarStock();
});

// ── Cargar combo Tiendas ──────────────────────────────────
function cargarTiendas() {
    $.get('/Inventario/ObtenerTiendas', function (data) {
        var opts = '<option value="0">-- Todas las tiendas --</option>';
        (data.data || []).forEach(function (t) {
            if (t.Activo) opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $('#cboTienda').html(opts);
    });
}

// ── Llenar combo Categorías desde los datos cargados ─────
function actualizarComboCategorias(datos) {
    var cats = [];
    datos.forEach(function (r) {
        if (r.Categoria && cats.indexOf(r.Categoria) === -1) cats.push(r.Categoria);
    });
    cats.sort();
    var opts = '<option value="">-- Todas las categorías --</option>';
    cats.forEach(function (c) { opts += '<option value="' + c + '">' + c + '</option>'; });
    $('#cboCategoria').html(opts);
}

// ── Buscar / recargar datos ───────────────────────────────
function buscarStock() {
    var idtienda = parseInt($('#cboTienda').val()) || 0;
    $('body').LoadingOverlay('show');

    $.get('/Inventario/ObtenerStock', { idtienda: idtienda, idproducto: 0 }, function (res) {
        _datosStock = res.data || [];
        actualizarComboCategorias(_datosStock);
        renderizarTabla();
        $('#btnExportarPDF').prop('disabled', _datosStock.length === 0);
    }).fail(function () {
        $('#contenedorStock').html('<p class="text-danger">Error al cargar el stock.</p>');
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Aplicar filtros de categoría y estado ─────────────────
function filtrarDatos() {
    var cat    = $('#cboCategoria').val();
    var estado = $('#cboEstado').val();
    return _datosStock.filter(function (r) {
        if (cat    && r.Categoria   !== cat)    return false;
        if (estado && r.EstadoStock !== estado) return false;
        return true;
    });
}

// ── Renderizar tabla agrupada por Tienda → Categoría ─────
function renderizarTabla() {
    var datos = filtrarDatos();

    if (datos.length === 0) {
        $('#contenedorStock').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        $('#panelTotales').addClass('d-none');
        return;
    }

    // Agrupar: tienda → categoría → productos
    var grupos = {};
    datos.forEach(function (r) {
        if (!grupos[r.NombreTienda]) grupos[r.NombreTienda] = {};
        if (!grupos[r.NombreTienda][r.Categoria]) grupos[r.NombreTienda][r.Categoria] = [];
        grupos[r.NombreTienda][r.Categoria].push(r);
    });

    var totalGeneral = 0, totalCritico = 0, totalBajo = 0;
    var html = '';

    Object.keys(grupos).sort().forEach(function (tienda) {
        var totalTienda = 0;
        var htmlCats = '';

        Object.keys(grupos[tienda]).sort().forEach(function (cat) {
            var prods = grupos[tienda][cat];
            var totalCat = 0, criticoCat = 0, bajoCat = 0;
            var htmlProds = '';

            prods.forEach(function (p) {
                var badgeColor = p.EstadoStock === 'CRITICO' ? 'danger'
                               : p.EstadoStock === 'BAJO'    ? 'warning' : 'success';
                totalCat += p.Stock;
                if (p.EstadoStock === 'CRITICO') criticoCat++;
                else if (p.EstadoStock === 'BAJO') bajoCat++;

                htmlProds +=
                    '<tr>' +
                    '<td class="pl-4"><small class="text-muted">' + (p.Codigo || '') + '</small></td>' +
                    '<td>' + p.NombreProducto + '</td>' +
                    '<td class="text-center font-weight-bold">' + p.Stock + '</td>' +
                    '<td class="text-center text-muted">' + p.StockMinimo + '</td>' +
                    '<td class="text-center text-muted">' + p.StockMaximo + '</td>' +
                    '<td class="text-center"><span class="badge badge-' + badgeColor + '">' + p.EstadoStock + '</span></td>' +
                    '</tr>';
            });

            totalCat && (totalTienda += totalCat);
            totalCritico += criticoCat;
            totalBajo    += bajoCat;

            // Fila subtotal categoría
            var alertCat = criticoCat > 0 ? ' <span class="badge badge-danger ml-2">' + criticoCat + ' crítico(s)</span>' : '';
            alertCat    += bajoCat    > 0 ? ' <span class="badge badge-warning ml-1">' + bajoCat    + ' bajo(s)</span>'    : '';

            htmlCats +=
                '<tr class="table-secondary">' +
                '<td colspan="6" class="pl-3"><i class="fas fa-tag mr-1"></i><strong>' + cat + '</strong>' + alertCat + '</td>' +
                '</tr>' +
                htmlProds +
                '<tr class="table-light">' +
                '<td colspan="5" class="text-right text-muted"><small>Subtotal ' + cat + ':</small></td>' +
                '<td class="text-center font-weight-bold"><small>' + totalCat + ' u.</small></td>' +
                '</tr>';
        });

        totalGeneral += totalTienda;

        html +=
            '<table class="table table-sm table-bordered mb-4">' +
            '<thead>' +
            '<tr class="bg-success text-white">' +
            '<th colspan="6"><i class="fas fa-store mr-1"></i>' + tienda +
            '  <span class="float-right">Total: ' + totalTienda + ' unidades</span></th>' +
            '</tr>' +
            '<tr class="thead-dark">' +
            '<th>Código</th><th>Producto</th>' +
            '<th class="text-center">Stock</th>' +
            '<th class="text-center">Mín.</th>' +
            '<th class="text-center">Máx.</th>' +
            '<th class="text-center">Estado</th>' +
            '</tr>' +
            '</thead>' +
            '<tbody>' + htmlCats + '</tbody>' +
            '</table>';
    });

    $('#contenedorStock').html(html);

    // Panel totales generales
    $('#tdTotalGeneral').text(totalGeneral + ' unidades');
    $('#tdTotalCritico').text(totalCritico + ' producto(s)');
    $('#tdTotalBajo').text(totalBajo + ' producto(s)');
    $('#panelTotales').removeClass('d-none');
}

// Actualizar al cambiar filtros sin recargar del servidor
$('#cboCategoria, #cboEstado').on('change', function () { renderizarTabla(); });

// ══════════════════════════════════════════════════════════
//  EXPORTAR PDF (jsPDF + autoTable)
// ══════════════════════════════════════════════════════════

function exportarPDF() {
    var datos = filtrarDatos();
    if (datos.length === 0) {
        Swal.fire({ title: 'Sin datos', text: 'No hay datos para exportar.', icon: 'warning' });
        return;
    }

    var { jsPDF } = window.jspdf;
    var doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });

    var tiendaFiltro = $('#cboTienda option:selected').text();
    var catFiltro    = $('#cboCategoria').val() || 'Todas';
    var estadoFiltro = $('#cboEstado').val()    || 'Todos';
    var fecha        = new Date().toLocaleDateString('es-PY');

    // Título
    doc.setFontSize(14);
    doc.setFont('helvetica', 'bold');
    doc.text('Reporte de Stock por Tienda y Categoría', 14, 15);

    doc.setFontSize(9);
    doc.setFont('helvetica', 'normal');
    doc.text('Tienda: ' + tiendaFiltro + '   |   Categoría: ' + catFiltro + '   |   Estado: ' + estadoFiltro + '   |   Fecha: ' + fecha, 14, 22);

    // Agrupar
    var grupos = {};
    datos.forEach(function (r) {
        if (!grupos[r.NombreTienda]) grupos[r.NombreTienda] = {};
        if (!grupos[r.NombreTienda][r.Categoria]) grupos[r.NombreTienda][r.Categoria] = [];
        grupos[r.NombreTienda][r.Categoria].push(r);
    });

    var body = [];
    var totalGeneral = 0;

    Object.keys(grupos).sort().forEach(function (tienda) {
        var totalTienda = 0;

        // Fila encabezado tienda
        body.push([{ content: 'TIENDA: ' + tienda, colSpan: 6, styles: { fillColor: [40, 167, 69], textColor: 255, fontStyle: 'bold', fontSize: 10 } }]);

        Object.keys(grupos[tienda]).sort().forEach(function (cat) {
            var prods = grupos[tienda][cat];
            var totalCat = 0;

            // Fila encabezado categoría
            body.push([{ content: 'Categoría: ' + cat, colSpan: 6, styles: { fillColor: [220, 220, 220], fontStyle: 'bold', fontSize: 9 } }]);

            prods.forEach(function (p) {
                var color = p.EstadoStock === 'CRITICO' ? [220, 53, 69]
                          : p.EstadoStock === 'BAJO'    ? [255, 193, 7] : [40, 167, 69];
                totalCat += p.Stock;
                body.push([
                    p.Codigo || '',
                    p.NombreProducto,
                    { content: String(p.Stock),    styles: { halign: 'center', fontStyle: 'bold' } },
                    { content: String(p.StockMinimo), styles: { halign: 'center' } },
                    { content: String(p.StockMaximo), styles: { halign: 'center' } },
                    { content: p.EstadoStock, styles: { halign: 'center', textColor: color, fontStyle: 'bold' } }
                ]);
            });

            totalTienda  += totalCat;

            // Subtotal categoría
            body.push([{ content: 'Subtotal ' + cat + ': ' + totalCat + ' unidades', colSpan: 6, styles: { fillColor: [248, 249, 250], fontStyle: 'italic', fontSize: 8, halign: 'right' } }]);
        });

        totalGeneral += totalTienda;

        // Total tienda
        body.push([{ content: 'TOTAL ' + tienda.toUpperCase() + ': ' + totalTienda + ' unidades', colSpan: 6, styles: { fillColor: [23, 162, 184], textColor: 255, fontStyle: 'bold', halign: 'right' } }]);
        body.push([{ content: '', colSpan: 6, styles: { fillColor: 255 } }]); // espacio
    });

    // Total general
    body.push([{ content: 'TOTAL GENERAL: ' + totalGeneral + ' unidades', colSpan: 6, styles: { fillColor: [52, 58, 64], textColor: 255, fontStyle: 'bold', fontSize: 11, halign: 'right' } }]);

    doc.autoTable({
        startY: 28,
        head: [[
            { content: 'Código',  styles: { halign: 'left'   } },
            { content: 'Producto', styles: { halign: 'left'  } },
            { content: 'Stock',   styles: { halign: 'center' } },
            { content: 'Mín.',    styles: { halign: 'center' } },
            { content: 'Máx.',    styles: { halign: 'center' } },
            { content: 'Estado',  styles: { halign: 'center' } }
        ]],
        body: body,
        headStyles: { fillColor: [33, 37, 41], textColor: 255, fontStyle: 'bold' },
        columnStyles: {
            0: { cellWidth: 25 },
            1: { cellWidth: 80 },
            2: { cellWidth: 20 },
            3: { cellWidth: 20 },
            4: { cellWidth: 20 },
            5: { cellWidth: 30 }
        },
        styles: { fontSize: 8, cellPadding: 2 },
        margin: { left: 14, right: 14 },
        didDrawPage: function (d) {
            // Pie de página
            var pgTotal = doc.internal.getNumberOfPages();
            doc.setFontSize(7);
            doc.setTextColor(150);
            doc.text('Página ' + d.pageNumber + ' de ' + pgTotal + '   —   Compu Space', 14, doc.internal.pageSize.height - 8);
        }
    });

    doc.save('Stock_' + fecha.replace(/\//g, '-') + '.pdf');
}
