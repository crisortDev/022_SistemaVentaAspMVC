// CajaVenta_Reporte.js
'use strict';

$(function () {
    var idCaja = parseInt($('#hdnIdCajaReporte').val()) || 0;
    if (idCaja) cargarReporte(idCaja);
});

function cargarReporte(idCaja) {
    $.get($.MisUrls.url._CajaVenta_Operaciones, { idCaja: idCaja }, function (r) {
        // ── Resumen por forma de cobro ──
        var resumenDiv = $('#resumenFormas');
        resumenDiv.empty();
        var totalSistema = 0;

        if (r.resumen && r.resumen.length > 0) {
            r.resumen.forEach(function (rs) {
                totalSistema += rs.TotalMonto;
                resumenDiv.append(
                    '<div class="col-sm-3 mb-2">' +
                    '<div class="card border-primary text-center">' +
                    '<div class="card-body py-2">' +
                    '<div class="text-muted small">' + rs.FormaCobro.toUpperCase() + '</div>' +
                    '<div class="font-weight-bold text-primary">Gs. ' + formatGs(rs.TotalMonto) + '</div>' +
                    '<div class="text-muted" style="font-size:11px;">' + rs.Cantidad + ' operación(es)</div>' +
                    '</div></div></div>'
                );
            });
        } else {
            resumenDiv.append('<div class="col-12"><p class="text-muted">Sin ventas en este turno.</p></div>');
        }

        $('#lblTotalReporte').text('Gs. ' + formatGs(totalSistema));
        $('#tfTotalReporte').text('Gs. ' + formatGs(totalSistema));

        // ── Detalle operación por operación ──
        var tbody = $('#tbodyReporte');
        tbody.empty();
        var fila = 1;
        var totalMonto = 0;

        if (!r.operaciones || r.operaciones.length === 0) {
            tbody.append('<tr><td colspan="10" class="text-center text-muted">Sin operaciones registradas.</td></tr>');
            return;
        }

        r.operaciones.forEach(function (op) {
            var esAnulada = op.Estado !== 'Activa';
            var badge = esAnulada
                ? '<span class="badge badge-danger">Anulada</span>'
                : '<span class="badge badge-success">Activa</span>';
            if (!esAnulada) totalMonto += op.Monto;

            tbody.append(
                '<tr' + (esAnulada ? ' class="table-danger"' : '') + '>' +
                '<td>' + fila++ + '</td>' +
                '<td>' + formatFechaHora(op.FechaRegistro) + '</td>' +
                '<td><code>' + op.NumeroFactura + '</code></td>' +
                '<td>' + op.NombreCliente + '</td>' +
                '<td>' + op.FormaCobro + '</td>' +
                '<td class="text-right">' + (esAnulada ? '<s>' : '') + 'Gs. ' + formatGs(op.Monto) + (esAnulada ? '</s>' : '') + '</td>' +
                '<td class="text-right">Gs. ' + formatGs(op.MontoRecibido) + '</td>' +
                '<td class="text-right">Gs. ' + formatGs(op.MontoCambio) + '</td>' +
                '<td>' + op.NombreCajero + '</td>' +
                '<td>' + badge + '</td>' +
                '</tr>'
            );
        });

        $('#tfTotalReporte').text('Gs. ' + formatGs(totalMonto));
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFechaHora(dt) {
    if (!dt) return '—';
    var m = dt.match(/(\d+)/g);
    if (!m) return dt;
    return ('0' + m[2]).slice(-2) + '/' + ('0' + m[1]).slice(-2) + '/' + m[0] +
           ' ' + ('0' + m[3]).slice(-2) + ':' + ('0' + m[4]).slice(-2);
}
