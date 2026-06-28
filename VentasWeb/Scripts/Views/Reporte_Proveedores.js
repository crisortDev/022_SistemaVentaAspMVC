// ═══════════════════════════════════════════════════════════
//  REPORTE — PROVEEDORES
// ═══════════════════════════════════════════════════════════

var _datosProv = [];

$(document).ready(function () {
    activarMenu("Reporte Proveedores");
    cargarTiendas();

    // Defaults: primer día del mes → hoy
    var hoy = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    $('#txtFechaInicio').val(primerDia.toISOString().slice(0, 10));
    $('#txtFechaFin').val(hoy.toISOString().slice(0, 10));
});

// ── Cargar combo Tiendas ──────────────────────────────────
function cargarTiendas() {
    $.get($.MisUrls.url._Inv_ObtenerTiendas, function (res) {
        var opts = '<option value="0">-- Todas las sucursales --</option>';
        (res.data || []).forEach(function (t) {
            if (t.Activo) opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $('#cboTienda').html(opts);
    });
}

// ── Buscar ────────────────────────────────────────────────
function buscarProveedores() {
    var fi = $('#txtFechaInicio').val();
    var ff = $('#txtFechaFin').val();

    if (!fi || !ff) {
        Swal.fire('Atención', 'Debe seleccionar un rango de fechas.', 'warning');
        return;
    }
    if (fi > ff) {
        Swal.fire('Atención', 'La fecha inicio no puede ser mayor a la fecha fin.', 'warning');
        return;
    }

    var params = {
        fechainicio: fi,
        fechafin:    ff,
        idtienda:    parseInt($('#cboTienda').val()) || 0,
        solodeuda:   $('#cboFiltro').val() === '1'
    };

    $('body').LoadingOverlay('show');

    $.get($.MisUrls.url._Reporte_ObtenerProveedores, params, function (res) {
        _datosProv = res.data || [];
        renderizarTabla();
        $('#btnExportarPDF').prop('disabled', _datosProv.length === 0);
    }).fail(function () {
        $('#contenedorProveedores').html('<p class="text-danger">Error al cargar el reporte.</p>');
    }).always(function () {
        $('body').LoadingOverlay('hide');
    });
}

// ── Renderizar tabla ──────────────────────────────────────
function renderizarTabla() {
    if (_datosProv.length === 0) {
        $('#contenedorProveedores').html('<p class="text-muted text-center mt-3">Sin resultados para los filtros seleccionados.</p>');
        $('#panelTotalesProv').addClass('d-none');
        return;
    }

    var sumCompras = 0, sumNCPend = 0, conMora = 0;

    var filas = '';
    _datosProv.forEach(function (p) {
        var rowClass  = p.TieneMorosa ? 'table-warning' : '';
        var moraIcon  = p.TieneMorosa ? ' <i class="fas fa-exclamation-triangle text-danger" title="Tiene NC morosa"></i>' : '';

        sumCompras += p.TotalCompras;
        sumNCPend  += p.MontoNCPendiente;
        if (p.TieneMorosa) conMora++;

        filas +=
            '<tr class="' + rowClass + '">' +
            '<td>' + p.Proveedor + moraIcon + '<br><small class="text-muted">' + p.RucProveedor + '</small></td>' +
            '<td class="text-muted small">' + (p.Telefono || '—') + '</td>' +
            '<td class="text-center">' + p.CantidadCompras + '</td>' +
            '<td class="text-right font-weight-bold">Gs. ' + formatGS(p.TotalCompras) + '</td>' +
            '<td class="text-center">' + p.CantidadNC + '</td>' +
            '<td class="text-right">Gs. ' + formatGS(p.TotalMontoNC) + '</td>' +
            '<td class="text-center ' + (p.NCPendientes > 0 ? 'text-danger font-weight-bold' : '') + '">' +
                p.NCPendientes +
                (p.NCPendientes > 0 ? '<br><small>Gs. ' + formatGS(p.MontoNCPendiente) + '</small>' : '') +
            '</td>' +
            '<td class="text-right ' + (p.MontoNeto < 0 ? 'text-danger' : '') + ' font-weight-bold">Gs. ' + formatGS(p.MontoNeto) + '</td>' +
            '</tr>';
    });

    var html =
        '<table class="table table-sm table-bordered table-hover">' +
        '<thead class="thead-dark">' +
        '<tr>' +
        '<th>Proveedor / RUC</th>' +
        '<th>Teléfono</th>' +
        '<th class="text-center">Compras</th>' +
        '<th class="text-right">Total Compras</th>' +
        '<th class="text-center">NC Total</th>' +
        '<th class="text-right">Monto NC Total</th>' +
        '<th class="text-center">NC Pendientes</th>' +
        '<th class="text-right">Monto Neto</th>' +
        '</tr>' +
        '</thead>' +
        '<tbody>' + filas + '</tbody>' +
        '</table>';

    $('#contenedorProveedores').html(html);

    // Panel totales
    $('#tdTotalProveedores').text(_datosProv.length);
    $('#tdTotalCompras').text('Gs. ' + formatGS(sumCompras));
    $('#tdTotalNCPendiente').text('Gs. ' + formatGS(sumNCPend));
    $('#tdConMora').text(conMora + ' proveedor(es)');
    $('#panelTotalesProv').removeClass('d-none');
}

// ── Formatear números estilo PY ───────────────────────────
function formatGS(n) {
    return Number(n).toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

// ══════════════════════════════════════════════════════════
//  EXPORTAR PDF
// ══════════════════════════════════════════════════════════
function exportarPDF() {
    if (_datosProv.length === 0) {
        Swal.fire({ title: 'Sin datos', text: 'No hay datos para exportar.', icon: 'warning' });
        return;
    }

    var { jsPDF } = window.jspdf;
    var doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });

    var fecha = new Date().toLocaleDateString('es-PY');
    doc.setFontSize(14);
    doc.setFont('helvetica', 'bold');
    doc.text('Reporte de Proveedores', 14, 15);

    doc.setFontSize(9);
    doc.setFont('helvetica', 'normal');
    var fi = $('#txtFechaInicio').val() || 'Todo';
    var ff = $('#txtFechaFin').val()    || 'Todo';
    var tienda = $('#cboTienda option:selected').text();
    doc.text('Período: ' + fi + ' — ' + ff + '   |   Tienda: ' + tienda + '   |   Fecha: ' + fecha, 14, 22);

    var body = [];
    var sumCompras = 0, sumNCPend = 0;

    _datosProv.forEach(function (p) {
        var moraFlag = p.TieneMorosa ? ' ⚠' : '';
        var ncPendStr = p.NCPendientes > 0
            ? String(p.NCPendientes) + '\nGs. ' + formatGS(p.MontoNCPendiente)
            : '0';

        sumCompras += p.TotalCompras;
        sumNCPend  += p.MontoNCPendiente;

        body.push([
            p.Proveedor + moraFlag + '\n' + p.RucProveedor,
            p.Telefono || '—',
            { content: String(p.CantidadCompras), styles: { halign: 'center' } },
            { content: 'Gs. ' + formatGS(p.TotalCompras), styles: { halign: 'right', fontStyle: 'bold' } },
            { content: String(p.CantidadNC), styles: { halign: 'center' } },
            { content: 'Gs. ' + formatGS(p.TotalMontoNC), styles: { halign: 'right' } },
            { content: ncPendStr,
              styles: { halign: 'center', textColor: p.NCPendientes > 0 ? [220, 53, 69] : [0, 0, 0], fontStyle: p.NCPendientes > 0 ? 'bold' : 'normal' } },
            { content: 'Gs. ' + formatGS(p.MontoNeto),
              styles: { halign: 'right', fontStyle: 'bold', textColor: p.MontoNeto < 0 ? [220, 53, 69] : [0, 0, 0] } }
        ]);
    });

    // Fila totales
    body.push([
        { content: 'TOTAL (' + _datosProv.length + ' proveedores)', colSpan: 3,
          styles: { fillColor: [33, 37, 41], textColor: 255, fontStyle: 'bold', halign: 'right' } },
        { content: 'Gs. ' + formatGS(sumCompras),
          styles: { fillColor: [33, 37, 41], textColor: 255, fontStyle: 'bold', halign: 'right' } },
        { content: '', colSpan: 2, styles: { fillColor: [33, 37, 41] } },
        { content: 'Gs. ' + formatGS(sumNCPend),
          styles: { fillColor: [33, 37, 41], textColor: [255, 193, 7], fontStyle: 'bold', halign: 'center' } },
        { content: '', styles: { fillColor: [33, 37, 41] } }
    ]);

    doc.autoTable({
        startY: 27,
        head: [[
            'Proveedor / RUC', 'Teléfono', 'Compras',
            'Total Compras', 'NC Total', 'Monto NC Total',
            'NC Pend.', 'Monto Neto'
        ]],
        body: body,
        headStyles: { fillColor: [0, 123, 255], textColor: 255, fontStyle: 'bold' },
        columnStyles: {
            0: { cellWidth: 55 },
            1: { cellWidth: 28 },
            2: { cellWidth: 18 },
            3: { cellWidth: 35 },
            4: { cellWidth: 18 },
            5: { cellWidth: 35 },
            6: { cellWidth: 28 },
            7: { cellWidth: 35 }
        },
        styles: { fontSize: 7.5, cellPadding: 2 },
        margin: { left: 10, right: 10 },
        didDrawPage: function (d) {
            var pgTotal = doc.internal.getNumberOfPages();
            doc.setFontSize(7);
            doc.setTextColor(150);
            doc.text('Página ' + d.pageNumber + ' de ' + pgTotal + '   —   Compu Space',
                10, doc.internal.pageSize.height - 8);
        }
    });

    doc.save('ReporteProveedores_' + fecha.replace(/\//g, '-') + '.pdf');
}
