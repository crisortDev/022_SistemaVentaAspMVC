// ═══════════════════════════════════════════════════════════════════
//  REPORTE — RENTABILIDAD GERENCIAL POR PRODUCTO (CPP)
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

// ── Combos ───────────────────────────────────────────────────────────
function cargarTiendas() {
    // Solo si es un <select> real (SuperAdmin); para el resto de los roles
    // #cboTienda es un input hidden con su sucursal fija.
    if (!$('#cboTienda').is('select')) return;
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
    }).fail(function () { });
}

// ── Buscar ────────────────────────────────────────────────────────────
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
        renderizarTodo();
        $('#btnExportarPDF').prop('disabled', _datosRent.length === 0);
    }).fail(function () {
        $('#contenedorRentabilidad').html(
            '<p class="text-danger text-center">Error al cargar el reporte.</p>'
        );
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Helpers ────────────────────────────────────────────────────────────
function fmtGS(n) {
    return 'Gs. ' + Math.round(n || 0).toLocaleString('es-PY');
}

function fmtPct(n) {
    return parseFloat(n || 0).toFixed(1) + ' %';
}

function barras(val, maxVal, maxBars) {
    maxBars = maxBars || 20;
    if (!maxVal || maxVal === 0) return '';
    var cnt = Math.max(1, Math.round((val / maxVal) * maxBars));
    var bar = '';
    for (var i = 0; i < cnt; i++) bar += '█';
    return bar;
}

function claseRent(r) {
    if ((r.UnidadesVendidas || 0) === 0) return 'sin_ventas';
    var m = parseFloat(r.MargenBrutoPct) || 0;
    if (m >= 20) return 'alta';
    if (m >= 10) return 'media';
    return 'baja';
}

function interpretarMargen(m) {
    if (m >= 40) return 'Excelente';
    if (m >= 25) return 'Muy buena';
    if (m >= 15) return 'Buena';
    if (m >=  5) return 'Regular';
    if (m >   0) return 'Baja';
    return 'Sin rentabilidad';
}

// ── Renderizar todo ────────────────────────────────────────────────────
function renderizarTodo() {
    if (_datosRent.length === 0) {
        $('#contenedorRentabilidad').html(
            '<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>'
        );
        $('#panelKPI, #panelAnalisis').addClass('d-none');
        return;
    }

    renderizarKPIs();
    renderizarClasificacion();
    renderizarTopUtilidad();
    renderizarTopMargen();
    renderizarBajoDesempeno();
    renderizarIndicadores();
    renderizarAnalisis();
    renderizarTabla();

    $('#panelKPI, #panelAnalisis').removeClass('d-none');
}

// ── 1. KPI Cards ───────────────────────────────────────────────────────
function renderizarKPIs() {
    var d = _datosRent;
    var sumIng = 0, sumCost = 0, sumUtil = 0, sumInv = 0;
    var conVentas = 0, sinVentas = 0;

    d.forEach(function (r) {
        sumIng  += parseFloat(r.IngresosTotales)   || 0;
        sumCost += parseFloat(r.CostoTotalVentas)  || 0;
        sumUtil += parseFloat(r.UtilidadBruta)     || 0;
        sumInv  += parseFloat(r.ValorInventarioCPP)|| 0;
        if ((r.UnidadesVendidas || 0) > 0) conVentas++;
        else sinVentas++;
    });

    var margenProm = sumIng > 0 ? (sumUtil / sumIng * 100) : 0;

    $('#kpiAnalizados').text(d.length);
    $('#kpiConVentas').text(conVentas);
    $('#kpiIngresos').text(fmtGS(sumIng));
    $('#kpiCosto').text(fmtGS(sumCost));
    $('#kpiUtilidad').text(fmtGS(sumUtil));
    $('#kpiMargen').text(fmtPct(margenProm));
    $('#kpiInventario').text(fmtGS(sumInv));
    $('#kpiSinVentas').text(sinVentas);
}

// ── 2. Clasificación de rentabilidad ───────────────────────────────────
function renderizarClasificacion() {
    var total = _datosRent.length;
    var cnt = { alta: 0, media: 0, baja: 0, sin_ventas: 0 };
    _datosRent.forEach(function (r) { cnt[claseRent(r)]++; });

    var maxBars = 15;
    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Nivel</th><th class="text-center">Cant.</th><th class="text-center">%</th><th>Gráfico</th>' +
        '</tr></thead><tbody>';

    function fila(label, clase, badgeClass, key) {
        var n   = cnt[key];
        var pct = total > 0 ? (n / total * 100) : 0;
        var bar = barras(n, total, maxBars);
        return '<tr class="' + clase + '">' +
            '<td><span class="badge ' + badgeClass + '">' + label + '</span></td>' +
            '<td class="text-center font-weight-bold">' + n + '</td>' +
            '<td class="text-center">' + fmtPct(pct) + '</td>' +
            '<td class="text-success" style="font-size:.9rem;letter-spacing:1px;">' + bar + '</td>' +
            '</tr>';
    }

    html += fila('Alta (≥20%)',   'table-success', 'badge-success', 'alta');
    html += fila('Media (10–19%)','table-warning', 'badge-warning', 'media');
    html += fila('Baja (0–9%)',   '',              'badge-secondary','baja');
    html += fila('Sin ventas',    'table-light',   'badge-dark',    'sin_ventas');
    html += '</tbody></table>';

    $('#tablaClasificacion').html(html);
}

// ── 3. Top 5 mayor utilidad ────────────────────────────────────────────
function renderizarTopUtilidad() {
    var conVentas = _datosRent.filter(function (r) {
        return (r.UnidadesVendidas || 0) > 0;
    });
    var top = conVentas.slice().sort(function (a, b) {
        return (parseFloat(b.UtilidadBruta) || 0) - (parseFloat(a.UtilidadBruta) || 0);
    }).slice(0, 5);

    var sumUtil = conVentas.reduce(function (acc, r) {
        return acc + (parseFloat(r.UtilidadBruta) || 0);
    }, 0);

    var maxUtil = top.length > 0 ? (parseFloat(top[0].UtilidadBruta) || 0) : 1;

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Producto</th><th class="text-right">Utilidad</th><th class="text-center">% Total</th>' +
        '</tr></thead><tbody>';

    top.forEach(function (r, i) {
        var util = parseFloat(r.UtilidadBruta) || 0;
        var pct  = sumUtil > 0 ? (util / sumUtil * 100) : 0;
        var bar  = barras(util, maxUtil, 15);
        html +=
            '<tr>' +
            '<td><small>' + r.Producto + '</small>' +
            '<br><span class="text-success" style="font-size:.75rem;letter-spacing:1px;">' + bar + '</span></td>' +
            '<td class="text-right font-weight-bold">' + fmtGS(util) + '</td>' +
            '<td class="text-center">' + fmtPct(pct) + '</td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaTopUtilidad').html(html);
}

// ── 4. Top 5 mayor margen ──────────────────────────────────────────────
function renderizarTopMargen() {
    var conVentas = _datosRent.filter(function (r) {
        return (r.UnidadesVendidas || 0) > 0 && (parseFloat(r.MargenBrutoPct) || 0) > 0;
    });
    var top = conVentas.slice().sort(function (a, b) {
        return (parseFloat(b.MargenBrutoPct) || 0) - (parseFloat(a.MargenBrutoPct) || 0);
    }).slice(0, 5);

    var maxMg = top.length > 0 ? (parseFloat(top[0].MargenBrutoPct) || 0) : 1;

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Producto</th><th class="text-center">Margen</th><th>Clasif.</th>' +
        '</tr></thead><tbody>';

    top.forEach(function (r) {
        var mg  = parseFloat(r.MargenBrutoPct) || 0;
        var bar = barras(mg, maxMg, 15);
        var cls = mg >= 40 ? 'Excelente' : mg >= 25 ? 'Muy buena' : mg >= 15 ? 'Buena' : 'Regular';
        var bdg = mg >= 40 ? 'badge-success' : mg >= 25 ? 'badge-info' : 'badge-secondary';
        html +=
            '<tr>' +
            '<td><small>' + r.Producto + '</small>' +
            '<br><span class="text-primary" style="font-size:.75rem;letter-spacing:1px;">' + bar + '</span></td>' +
            '<td class="text-center font-weight-bold">' + fmtPct(mg) + '</td>' +
            '<td><span class="badge ' + bdg + '">' + cls + '</span></td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaTopMargen').html(html);
}

// ── 5. Bajo desempeño ─────────────────────────────────────────────────
function renderizarBajoDesempeno() {
    var bajos = _datosRent.filter(function (r) {
        return (r.UnidadesVendidas || 0) === 0 || (parseFloat(r.MargenBrutoPct) || 0) < 20;
    }).sort(function (a, b) {
        return (parseFloat(a.MargenBrutoPct) || 0) - (parseFloat(b.MargenBrutoPct) || 0);
    });

    if (bajos.length === 0) {
        $('#tablaBajoDesempeno').html('<p class="text-success small"><i class="fas fa-check-circle mr-1"></i>Todos los productos tienen alta rentabilidad.</p>');
        return;
    }

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr>' +
        '<th>Producto</th><th class="text-center">Margen</th><th>Estado</th>' +
        '</tr></thead><tbody>';

    bajos.forEach(function (r) {
        var mg  = parseFloat(r.MargenBrutoPct) || 0;
        var uds = r.UnidadesVendidas || 0;
        var estado, rowClass, badgeClass;

        if (uds === 0) {
            estado = 'Sin ventas'; rowClass = 'table-secondary'; badgeClass = 'badge-dark';
        } else if (mg >= 10) {
            estado = 'Rentabilidad media'; rowClass = 'table-warning'; badgeClass = 'badge-warning';
        } else if (mg >= 0) {
            estado = 'Rentabilidad baja'; rowClass = 'table-danger'; badgeClass = 'badge-danger';
        } else {
            estado = 'Margen negativo'; rowClass = 'table-danger'; badgeClass = 'badge-danger';
        }

        html +=
            '<tr class="' + rowClass + '">' +
            '<td><small>' + r.Producto + '</small></td>' +
            '<td class="text-center">' + fmtPct(mg) + '</td>' +
            '<td><span class="badge ' + badgeClass + '">' + estado + '</span></td>' +
            '</tr>';
    });
    html += '</tbody></table>';
    $('#tablaBajoDesempeno').html(html);
}

// ── 6. Indicadores estratégicos ────────────────────────────────────────
function renderizarIndicadores() {
    var d = _datosRent;
    var total = d.length;
    var sumIng = 0, sumUtil = 0, sumInv = 0;
    var alta = 0, sinVentas = 0;

    d.forEach(function (r) {
        sumIng  += parseFloat(r.IngresosTotales)   || 0;
        sumUtil += parseFloat(r.UtilidadBruta)     || 0;
        sumInv  += parseFloat(r.ValorInventarioCPP)|| 0;
        var clase = claseRent(r);
        if (clase === 'alta') alta++;
        if (clase === 'sin_ventas') sinVentas++;
    });

    var margenProm   = sumIng > 0 ? (sumUtil / sumIng * 100) : 0;
    var pctAlta      = total > 0 ? (alta / total * 100) : 0;
    var pctSinVentas = total > 0 ? (sinVentas / total * 100) : 0;

    function interp(label, val, sufijo) {
        return '<tr><td><small>' + label + '</small></td>' +
               '<td class="text-center font-weight-bold"><small>' + val + '</small></td>' +
               '<td><small class="text-muted">' + sufijo + '</small></td></tr>';
    }

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr>' +
        '<th>Indicador</th><th class="text-center">Resultado</th><th>Interpretación</th>' +
        '</tr></thead><tbody>';

    html += interp('Margen promedio',               fmtPct(margenProm), interpretarMargen(margenProm));
    html += interp('Productos altamente rentables', fmtPct(pctAlta),    pctAlta > 50 ? 'Favorable' : 'Mejorar');
    html += interp('Productos sin movimiento',      fmtPct(pctSinVentas), pctSinVentas > 20 ? 'Requiere análisis' : 'Aceptable');
    html += interp('Utilidad sobre ingresos',       fmtPct(margenProm), interpretarMargen(margenProm));
    html += interp('Valor del inventario',          fmtGS(sumInv),      'Capital inmovilizado');

    html += '</tbody></table>';
    $('#tablaIndicadores').html(html);
}

// ── 7. Análisis gerencial ──────────────────────────────────────────────
function renderizarAnalisis() {
    var d = _datosRent;

    // Producto con mayor utilidad
    var maxUtil = d.reduce(function (best, r) {
        return (parseFloat(r.UtilidadBruta) || 0) > (parseFloat(best.UtilidadBruta) || 0) ? r : best;
    }, d[0]);

    // Producto con mayor margen (solo con ventas)
    var conVentas = d.filter(function (r) { return (r.UnidadesVendidas || 0) > 0; });
    var maxMargen = conVentas.length > 0
        ? conVentas.reduce(function (best, r) {
            return (parseFloat(r.MargenBrutoPct) || 0) > (parseFloat(best.MargenBrutoPct) || 0) ? r : best;
          }, conVentas[0])
        : null;

    // Categoría más rentable
    var catMap = {};
    d.forEach(function (r) {
        var c = r.Categoria || '(Sin categoría)';
        if (!catMap[c]) catMap[c] = 0;
        catMap[c] += parseFloat(r.UtilidadBruta) || 0;
    });
    var catMejor = Object.keys(catMap).reduce(function (best, k) {
        return catMap[k] > (catMap[best] || -Infinity) ? k : best;
    }, Object.keys(catMap)[0]);

    var sinVentas = d.filter(function (r) { return (r.UnidadesVendidas || 0) === 0; }).length;
    var sumInv    = d.reduce(function (acc, r) { return acc + (parseFloat(r.ValorInventarioCPP) || 0); }, 0);

    function fila(aspecto, resultado) {
        return '<tr><td><small class="font-weight-bold">' + aspecto + '</small></td>' +
               '<td><small>' + resultado + '</small></td></tr>';
    }

    var html =
        '<table class="table table-sm table-bordered">' +
        '<thead class="thead-light"><tr><th>Aspecto</th><th>Resultado</th></tr></thead>' +
        '<tbody>' +
        fila('Producto con mayor utilidad', maxUtil ? maxUtil.Producto : '—') +
        fila('Producto con mayor margen',   maxMargen ? maxMargen.Producto + ' (' + fmtPct(parseFloat(maxMargen.MargenBrutoPct)) + ')' : '—') +
        fila('Categoría más rentable',      catMejor || '—') +
        fila('Productos sin ventas',        sinVentas + ' (' + fmtPct(d.length > 0 ? sinVentas / d.length * 100 : 0) + ')') +
        fila('Capital inmovilizado',        fmtGS(sumInv) + ' en inventario') +
        '</tbody></table>';

    $('#tablaAnalisis').html(html);
}

// ── 8. Tabla de detalle (DataTable) ───────────────────────────────────
function renderizarTabla() {
    var cont = $('#contenedorRentabilidad');

    if (_datosRent.length === 0) {
        cont.html('<p class="text-muted text-center mt-3">Sin resultados.</p>');
        return;
    }

    var filas = '';
    _datosRent.forEach(function (r) {
        var mg  = parseFloat(r.MargenBrutoPct) || 0;
        var util = parseFloat(r.UtilidadBruta) || 0;
        var clase = claseRent(r);

        var margenClass = mg >= 20 ? 'text-success font-weight-bold'
                        : mg >= 10 ? 'text-warning font-weight-bold'
                        : mg >   0 ? 'text-secondary'
                        : 'text-danger font-weight-bold';

        var rowBg = clase === 'alta'      ? ''
                  : clase === 'media'     ? 'table-warning'
                  : clase === 'sin_ventas'? 'table-light'
                  : '';

        filas +=
            '<tr class="' + rowBg + '">' +
            '<td><code>' + (r.Codigo || '—') + '</code></td>' +
            '<td>' + r.Producto + '<br><small class="text-muted">' + (r.Categoria || '—') + '</small></td>' +
            '<td class="text-center">' + (r.StockActual || 0) + '</td>' +
            '<td class="text-right text-muted">' + fmtGS(r.CostoPromedio) + '</td>' +
            '<td class="text-right">' + fmtGS(r.PrecioVentaVigente) + '</td>' +
            '<td class="text-center">' + (r.UnidadesVendidas || 0) + '</td>' +
            '<td class="text-right">' + fmtGS(r.IngresosTotales) + '</td>' +
            '<td class="text-right">' + fmtGS(r.CostoTotalVentas) + '</td>' +
            '<td class="text-right ' + (util >= 0 ? 'text-success' : 'text-danger') + '">' + fmtGS(util) + '</td>' +
            '<td class="text-center ' + margenClass + '">' + mg.toFixed(1) + '%</td>' +
            '<td class="text-right text-info">' + fmtGS(r.ValorInventarioCPP) + '</td>' +
            '</tr>';
    });

    var html =
        '<h6 class="font-weight-bold text-success border-bottom pb-1 mb-2">' +
        '<i class="fas fa-table mr-1"></i> Detalle de Productos</h6>' +
        '<table class="table table-bordered table-sm" id="tblRentabilidad" style="width:100%;font-size:12px;">' +
        '<thead class="thead-dark"><tr>' +
        '<th>Código</th>' +
        '<th>Producto / Categoría</th>' +
        '<th class="text-center">Stock</th>' +
        '<th class="text-right">CPP (Gs.)</th>' +
        '<th class="text-right">P. Venta</th>' +
        '<th class="text-center">Uds. Vendidas</th>' +
        '<th class="text-right">Ingresos</th>' +
        '<th class="text-right">Costo CPP</th>' +
        '<th class="text-right">Utilidad Bruta</th>' +
        '<th class="text-center">Margen %</th>' +
        '<th class="text-right">Valor Inv.</th>' +
        '</tr></thead>' +
        '<tbody>' + filas + '</tbody>' +
        '</table>';

    cont.html(html);

    if ($.fn.DataTable.isDataTable('#tblRentabilidad')) {
        $('#tblRentabilidad').DataTable().destroy();
    }
    $('#tblRentabilidad').DataTable({
        paging:    true,
        pageLength: 25,
        order:     [[9, 'desc']],
        language:  { url: $.MisUrls.url.Url_datatable_spanish }
    });
}

// ── Exportar PDF ──────────────────────────────────────────────────────
function exportarPDF() {
    if (_datosRent.length === 0) { toastr.warning('Sin datos para exportar.'); return; }

    $('#hRentFechaInicio').val($('#txtFechaInicio').val());
    $('#hRentFechaFin').val($('#txtFechaFin').val());
    $('#hRentIdTienda').val(parseInt($('#cboTienda').val()) || 0);
    $('#hRentIdCategoria').val(parseInt($('#cboCategoria').val()) || 0);
    $('#frmPDFRent').submit();
}
