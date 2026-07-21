// ═══════════════════════════════════════════════════════════
//  INVENTARIO — REPORTE GERENCIAL DE PRODUCTOS POR TIENDA
// ═══════════════════════════════════════════════════════════

var _datosStock = [];

$(document).ready(function () {
    activarMenu("Stock por Tienda");
    cargarTiendas();
    buscarStock();
});

// ── Cargar combo Tiendas ──────────────────────────────────
function cargarTiendas() {
    var tiendaActiva  = parseInt($('#hdnTiendaActiva').val())  || 0;
    var esAdminGlobal = $('#hdnEsAdminGlobal').val() === '1';

    $.get($.MisUrls.url._Inv_ObtenerTiendas, function (data) {
        var tiendas = (data.data || []).filter(function (t) { return t.Activo; });

        if (esAdminGlobal) {
            // Admin global: ver todas, seleccionar "Todas" por defecto
            var opts = '<option value="0">-- Todas las tiendas --</option>';
            tiendas.forEach(function (t) {
                opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            });
            $('#cboTienda').html(opts);
        } else {
            // Usuario de sucursal: bloquear en su propia tienda
            var tiendaUser = tiendas.find(function (t) { return t.IdTienda === tiendaActiva; });
            var nombre = tiendaUser ? tiendaUser.Nombre : ('Tienda #' + tiendaActiva);
            $('#cboTienda').html('<option value="' + tiendaActiva + '" selected>' + nombre + '</option>');
            // El select ya viene disabled desde Razor, pero por si acaso:
            $('#cboTienda').prop('disabled', true);
        }
    });
}

// ── Llenar combo Categorías desde los datos ───────────────
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

// ── Buscar ────────────────────────────────────────────────
function buscarStock() {
    var idtienda = parseInt($('#cboTienda').val()) || 0;
    $('body').LoadingOverlay('show');

    $.get($.MisUrls.url._ObtenerStock, { idtienda: idtienda, idproducto: 0 }, function (res) {
        _datosStock = res.data || [];
        actualizarComboCategorias(_datosStock);
        renderizarTodo();
        $('#btnExportarPDF').prop('disabled', _datosStock.length === 0);
    }).fail(function () {
        $('#contenedorStock').html('<p class="text-danger">Error al cargar el stock.</p>');
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Aplicar filtros cliente ───────────────────────────────
function filtrarDatos() {
    var cat    = $('#cboCategoria').val();
    var estado = $('#cboEstado').val();
    return _datosStock.filter(function (r) {
        if (cat    && r.Categoria   !== cat)    return false;
        if (estado && r.EstadoStock !== estado) return false;
        return true;
    });
}

// ── Formato Guaraníes ─────────────────────────────────────
function fmtGS(n) {
    var v = parseFloat(n) || 0;
    return 'Gs. ' + v.toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function fmtPct(n) {
    return (parseFloat(n) || 0).toFixed(1) + ' %';
}

// ── Renderizar todo ───────────────────────────────────────
function renderizarTodo() {
    var datos = filtrarDatos();

    if (datos.length === 0) {
        $('#contenedorStock').html(
            '<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>'
        );
        $('#panelKPI, #panelResumenSucursal, #panelInferior').addClass('d-none');
        return;
    }

    renderizarKPIs(datos);
    renderizarResumenSucursal(datos);
    renderizarTabla(datos);
    renderizarSinStock(datos);
    renderizarTopInmovilizado(datos);
    renderizarDistribucion(datos);
    renderizarEstadoStock(datos);

    $('#panelKPI, #panelResumenSucursal, #panelInferior').removeClass('d-none');
}

// ── KPI Cards ─────────────────────────────────────────────
function renderizarKPIs(datos) {
    var ids = {}, tiendas = {};
    var totalUnid = 0, inversion = 0, valorVenta = 0;
    var sinStockCnt = 0, criticoCnt = 0;

    datos.forEach(function (r) {
        ids[r.IdProducto]       = true;
        tiendas[r.NombreTienda] = true;
        var s  = parseFloat(r.Stock)        || 0;
        var c  = parseFloat(r.CostoUnitario)|| 0;
        var pv = parseFloat(r.PrecioVenta)  || 0;
        totalUnid  += s;
        inversion  += s * c;
        valorVenta += s * pv;
        if (s === 0)                        sinStockCnt++;
        if (r.EstadoStock === 'CRITICO')    criticoCnt++;
    });

    var ganancia = valorVenta - inversion;
    var margen   = inversion > 0 ? (ganancia / inversion * 100) : 0;

    $('#kpiProductos').text(Object.keys(ids).length);
    $('#kpiSucursales').text(Object.keys(tiendas).length);
    $('#kpiUnidades').text(totalUnid.toLocaleString('es-PY'));
    $('#kpiInversion').text(fmtGS(inversion));
    $('#kpiValorVenta').text(fmtGS(valorVenta));
    $('#kpiGanancia').text(fmtGS(ganancia) + ' (' + fmtPct(margen) + ')');
    $('#kpiSinStock').text(sinStockCnt);
    $('#kpiCritico').text(criticoCnt);
}

// ── Resumen por Sucursal ──────────────────────────────────
function renderizarResumenSucursal(datos) {
    var suc = {};
    datos.forEach(function (r) {
        var n = r.NombreTienda;
        if (!suc[n]) suc[n] = { prods: {}, stock: 0, compra: 0, venta: 0 };
        suc[n].prods[r.IdProducto] = true;
        var s = parseFloat(r.Stock)         || 0;
        suc[n].stock  += s;
        suc[n].compra += s * (parseFloat(r.CostoUnitario) || 0);
        suc[n].venta  += s * (parseFloat(r.PrecioVenta)   || 0);
    });

    // Totales generales
    var allIds = {}; var totStock = 0, totCompra = 0, totVenta = 0;
    datos.forEach(function (r) {
        allIds[r.IdProducto] = true;
        var s = parseFloat(r.Stock) || 0;
        totStock  += s;
        totCompra += s * (parseFloat(r.CostoUnitario) || 0);
        totVenta  += s * (parseFloat(r.PrecioVenta)   || 0);
    });

    var html =
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Sucursal</th>' +
        '<th class="text-center">Productos</th>' +
        '<th class="text-center">Stock Total</th>' +
        '<th class="text-right">Valor Compra</th>' +
        '<th class="text-right">Valor Venta</th>' +
        '<th class="text-right">Ganancia Potencial</th>' +
        '</tr></thead><tbody>';

    Object.keys(suc).sort().forEach(function (n) {
        var d = suc[n];
        var gan = d.venta - d.compra;
        html +=
            '<tr>' +
            '<td>' + n + '</td>' +
            '<td class="text-center">' + Object.keys(d.prods).length + '</td>' +
            '<td class="text-center font-weight-bold">' + d.stock.toLocaleString('es-PY') + '</td>' +
            '<td class="text-right">' + fmtGS(d.compra) + '</td>' +
            '<td class="text-right">' + fmtGS(d.venta) + '</td>' +
            '<td class="text-right font-weight-bold text-success">' + fmtGS(gan) + '</td>' +
            '</tr>';
    });

    html +=
        '<tr class="table-dark font-weight-bold">' +
        '<td>TOTAL GENERAL</td>' +
        '<td class="text-center">' + Object.keys(allIds).length + '</td>' +
        '<td class="text-center">' + totStock.toLocaleString('es-PY') + '</td>' +
        '<td class="text-right">' + fmtGS(totCompra) + '</td>' +
        '<td class="text-right">' + fmtGS(totVenta) + '</td>' +
        '<td class="text-right">' + fmtGS(totVenta - totCompra) + '</td>' +
        '</tr>';

    html += '</tbody></table>';
    $('#tablaResumenSucursal').html(html);
}

// ── Tabla detalle agrupada Tienda → Categoría ─────────────
function renderizarTabla(datos) {
    if (datos.length === 0) {
        $('#contenedorStock').html('<p class="text-muted text-center mt-3">Sin resultados.</p>');
        return;
    }

    // Agrupar
    var grupos = {};
    datos.forEach(function (r) {
        if (!grupos[r.NombreTienda])             grupos[r.NombreTienda] = {};
        if (!grupos[r.NombreTienda][r.Categoria]) grupos[r.NombreTienda][r.Categoria] = [];
        grupos[r.NombreTienda][r.Categoria].push(r);
    });

    var html = '';

    Object.keys(grupos).sort().forEach(function (tienda) {
        var totalTienda = 0;
        var htmlCats = '';

        Object.keys(grupos[tienda]).sort().forEach(function (cat) {
            var prods    = grupos[tienda][cat];
            var totalCat = 0, criticoCat = 0, bajoCat = 0;
            var htmlProds = '';

            prods.forEach(function (p) {
                var stock  = parseFloat(p.Stock)         || 0;
                var costo  = parseFloat(p.CostoUnitario) || 0;
                var pv     = parseFloat(p.PrecioVenta)   || 0;
                var valInv = stock * costo;
                var margen = costo > 0 ? ((pv - costo) / costo * 100) : 0;

                totalCat += stock;
                if (p.EstadoStock === 'CRITICO') criticoCat++;
                else if (p.EstadoStock === 'BAJO') bajoCat++;

                var badgeColor  = stock === 0              ? 'secondary'
                                : p.EstadoStock === 'CRITICO' ? 'danger'
                                : p.EstadoStock === 'BAJO'    ? 'warning'
                                : 'success';
                var estadoLabel = stock === 0 ? 'SIN STOCK' : p.EstadoStock;

                var descHtml = p.Descripcion
                    ? '<br><small class="text-muted" style="font-size:.68rem;">' + p.Descripcion + '</small>'
                    : '';

                var margenClass = margen < 0 ? 'text-danger' : (margen > 0 ? 'text-success' : '');

                htmlProds +=
                    '<tr>' +
                    '<td class="pl-4"><small class="text-muted">' + (p.Codigo || '') + '</small></td>' +
                    '<td>' + p.NombreProducto + descHtml + '</td>' +
                    '<td class="text-center font-weight-bold">' + stock + '</td>' +
                    '<td class="text-right"><small>' + fmtGS(costo) + '</small></td>' +
                    '<td class="text-right"><small>' + fmtGS(pv)    + '</small></td>' +
                    '<td class="text-right"><small>' + fmtGS(valInv) + '</small></td>' +
                    '<td class="text-center"><small class="' + margenClass + '">' + fmtPct(margen) + '</small></td>' +
                    '<td class="text-center"><span class="badge badge-' + badgeColor + '">' + estadoLabel + '</span></td>' +
                    '</tr>';
            });

            totalTienda += totalCat;

            var alertCat = '';
            if (criticoCat > 0) alertCat += ' <span class="badge badge-danger ml-1">' + criticoCat + ' crítico(s)</span>';
            if (bajoCat    > 0) alertCat += ' <span class="badge badge-warning ml-1">' + bajoCat    + ' bajo(s)</span>';

            htmlCats +=
                '<tr class="table-secondary">' +
                '<td colspan="8" class="pl-3"><i class="fas fa-tag mr-1"></i><strong>' + cat + '</strong>' + alertCat + '</td>' +
                '</tr>' +
                htmlProds +
                '<tr class="table-light">' +
                '<td colspan="7" class="text-right text-muted small">Subtotal ' + cat + ':</td>' +
                '<td class="text-center font-weight-bold small">' + totalCat + ' u.</td>' +
                '</tr>';
        });

        html +=
            '<table class="table table-sm table-bordered mb-4">' +
            '<thead>' +
            '<tr class="bg-success text-white">' +
            '<th colspan="8"><i class="fas fa-store mr-1"></i>' + tienda +
            ' <span class="float-right">Total: ' + totalTienda.toLocaleString('es-PY') + ' unidades</span></th>' +
            '</tr>' +
            '<tr class="thead-dark">' +
            '<th>Código</th>' +
            '<th>Producto</th>' +
            '<th class="text-center">Stock</th>' +
            '<th class="text-right">Costo Unit.</th>' +
            '<th class="text-right">Venta Unit.</th>' +
            '<th class="text-right">Valor Inv.</th>' +
            '<th class="text-center">Margen</th>' +
            '<th class="text-center">Estado</th>' +
            '</tr>' +
            '</thead>' +
            '<tbody>' + htmlCats + '</tbody>' +
            '</table>';
    });

    $('#contenedorStock').html(html);
}

// ── Productos sin stock ───────────────────────────────────
function renderizarSinStock(datos) {
    var sinStock = datos.filter(function (r) { return (parseFloat(r.Stock) || 0) === 0; });
    if (sinStock.length === 0) {
        $('#tablaSinStock').html('<p class="text-success small"><i class="fas fa-check-circle mr-1"></i>Todos los productos tienen stock.</p>');
        return;
    }
    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr>' +
        '<th>Código</th><th>Producto</th><th>Sucursal</th>' +
        '</tr></thead><tbody>';
    sinStock.forEach(function (p) {
        html +=
            '<tr class="table-danger">' +
            '<td><small>' + (p.Codigo || '') + '</small></td>' +
            '<td>' + p.NombreProducto + '</td>' +
            '<td>' + p.NombreTienda + '</td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaSinStock').html(html);
}

// ── Top 5 mayor valor inmovilizado ────────────────────────
function renderizarTopInmovilizado(datos) {
    var map = {};
    datos.forEach(function (r) {
        var id  = r.IdProducto;
        var s   = parseFloat(r.Stock)         || 0;
        var val = s * (parseFloat(r.CostoUnitario) || 0);
        if (!map[id]) map[id] = { nombre: r.NombreProducto, stock: 0, valor: 0 };
        map[id].stock += s;
        map[id].valor += val;
    });

    var top = Object.values(map)
        .filter(function (v) { return v.valor > 0; })
        .sort(function (a, b) { return b.valor - a.valor; })
        .slice(0, 5);

    if (top.length === 0) {
        $('#tablaTopInmovilizado').html('<p class="text-muted small">Sin datos de costo disponibles.</p>');
        return;
    }
    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr>' +
        '<th>Producto</th><th class="text-center">Stock</th><th class="text-right">Valor Compra</th>' +
        '</tr></thead><tbody>';
    top.forEach(function (v) {
        html +=
            '<tr>' +
            '<td>' + v.nombre + '</td>' +
            '<td class="text-center">' + v.stock + '</td>' +
            '<td class="text-right font-weight-bold">' + fmtGS(v.valor) + '</td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaTopInmovilizado').html(html);
}

// ── Distribución del inventario ───────────────────────────
function renderizarDistribucion(datos) {
    var suc = {}, total = 0;
    datos.forEach(function (r) {
        var n = r.NombreTienda;
        var s = parseFloat(r.Stock) || 0;
        if (!suc[n]) suc[n] = 0;
        suc[n] += s;
        total   += s;
    });

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr>' +
        '<th>Sucursal</th><th class="text-center">%</th><th>Distribución</th>' +
        '</tr></thead><tbody>';

    Object.keys(suc).sort().forEach(function (n) {
        var pct  = total > 0 ? (suc[n] / total * 100) : 0;
        var bars = Math.max(1, Math.round(pct / 5));
        var bar  = '';
        for (var i = 0; i < bars; i++) bar += '█';
        html +=
            '<tr>' +
            '<td>' + n + '</td>' +
            '<td class="text-center">' + pct.toFixed(1) + '%</td>' +
            '<td><span class="text-success" style="font-size:1.1rem;letter-spacing:1px;">' + bar +
            '</span> <small class="text-muted">' + suc[n].toLocaleString('es-PY') + ' u.</small></td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaDistribucion').html(html);
}

// ── Estado del stock ──────────────────────────────────────
function renderizarEstadoStock(datos) {
    var ok = 0, bajo = 0, critico = 0, sinStock = 0;
    datos.forEach(function (r) {
        var s = parseFloat(r.Stock) || 0;
        if (s === 0)                        sinStock++;
        else if (r.EstadoStock === 'CRITICO') critico++;
        else if (r.EstadoStock === 'BAJO')    bajo++;
        else                                  ok++;
    });

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr><th>Estado</th><th class="text-center">Registros</th></tr></thead>' +
        '<tbody>' +
        '<tr class="table-success">' +
        '<td><span class="badge badge-success mr-1">OK</span>Disponible</td>' +
        '<td class="text-center font-weight-bold">' + ok + '</td></tr>' +
        '<tr class="table-warning">' +
        '<td><span class="badge badge-warning mr-1">BAJO</span>Stock bajo</td>' +
        '<td class="text-center font-weight-bold">' + bajo + '</td></tr>' +
        '<tr class="table-danger">' +
        '<td><span class="badge badge-danger mr-1">CRÍTICO</span>Stock crítico</td>' +
        '<td class="text-center font-weight-bold">' + critico + '</td></tr>' +
        '<tr class="bg-secondary text-white">' +
        '<td><span class="badge badge-dark mr-1">—</span>Sin stock</td>' +
        '<td class="text-center font-weight-bold">' + sinStock + '</td></tr>' +
        '</tbody></table>';
    $('#tablaEstadoStock').html(html);
}

// Actualizar al cambiar filtros (sin recargar del servidor)
$('#cboCategoria, #cboEstado').on('change', function () { renderizarTodo(); });

// ══════════════════════════════════════════════════════════
//  EXPORTAR PDF (Python backend — con membrete y logo)
// ══════════════════════════════════════════════════════════
function exportarPDF() {
    var datos = filtrarDatos();
    if (datos.length === 0) {
        Swal.fire({ title: 'Sin datos', text: 'No hay datos para exportar.', icon: 'warning' });
        return;
    }

    var idtienda  = parseInt($('#cboTienda').val())  || 0;
    var categoria = $('#cboCategoria').val()          || '';
    var estado    = $('#cboEstado').val()             || '';

    $('#hStockTienda').val(idtienda);
    $('#hStockCategoria').val(categoria);
    $('#hStockEstado').val(estado);
    $('#frmPDFStock').submit();
}
