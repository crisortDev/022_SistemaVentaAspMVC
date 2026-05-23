// CajaVenta_Index.js
'use strict';

$(function () {
    cargarHistorial();
    // Si hay caja abierta, cargar operaciones
    if ($('#hdnIdCaja').length) {
        recargarOperaciones();
    }
});

// ─── APERTURA ──────────────────────────────────────────────
function abrirCaja() {
    var monto    = parseFloat($('#txtMontoApertura').val()) || 0;
    var idTienda = parseInt($('#ddlTiendaApertura').val()) || 0;

    if (monto < 0) { toastr.warning('El monto no puede ser negativo.'); return; }

    // Validar tienda solo si el selector está presente (SuperAdmin)
    if ($('#ddlTiendaApertura').length && idTienda === 0) {
        toastr.warning('Seleccioná una tienda antes de abrir la caja.');
        return;
    }

    Swal.fire({
        title: '¿Confirmar apertura?',
        html: 'Monto inicial: <strong>Gs. ' + formatGs(monto) + '</strong>',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Abrir Caja',
        confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;

        var datos = { montoApertura: monto };
        if (idTienda > 0) datos.idTienda = idTienda;

        $.ajax({
            url:  $.MisUrls.url._CajaVenta_Abrir,
            method: 'POST',
            data: datos,
            success: function (res) {
                if (res.resultado) {
                    toastr.success(res.mensaje);
                    // Abrir comprobante de apertura en nueva pestaña y recargar ésta
                    if (res.idCaja) {
                        window.open($.MisUrls.url._CajaVenta_ComprobanteApertura + '?idCaja=' + res.idCaja, '_blank');
                    }
                    setTimeout(function () { location.reload(); }, 800);
                } else {
                    toastr.error(res.mensaje);
                }
            },
            error: function () { toastr.error('Error de conexión.'); }
        });
    });
}

// ─── OPERACIONES DEL TURNO ─────────────────────────────────
function recargarOperaciones() {
    var idCaja = parseInt($('#hdnIdCaja').val()) || 0;
    if (!idCaja) return;

    $.get($.MisUrls.url._CajaVenta_Operaciones, { idCaja: idCaja }, function (r) {
        var tbody = $('#tbodyOperaciones');
        tbody.empty();
        var total = 0;
        var fila  = 1;

        if (!r.operaciones || r.operaciones.length === 0) {
            tbody.append('<tr><td colspan="9" class="text-center text-muted">Sin operaciones en este turno.</td></tr>');
        } else {
            r.operaciones.forEach(function (op) {
                var badgeEstado = op.Estado === 'Activa'
                    ? '<span class="badge badge-success">Activa</span>'
                    : '<span class="badge badge-danger">Anulada</span>';
                var monto = op.Estado === 'Activa' ? op.Monto : 0;
                total += monto;
                var btnReimprimir = op.IdVenta
                    ? '<a href="' + $.MisUrls.url._Venta_Documento + '?idVenta=' + op.IdVenta + '" target="_blank" class="btn btn-xs btn-outline-primary btn-sm" title="Reimprimir factura"><i class="fas fa-print"></i></a>'
                    : '';
                tbody.append(
                    '<tr>' +
                    '<td>' + fila++ + '</td>' +
                    '<td>' + formatHora(op.FechaRegistro) + '</td>' +
                    '<td><code>' + op.NumeroFactura + '</code> ' + btnReimprimir + '</td>' +
                    '<td>' + op.NombreCliente + '</td>' +
                    '<td>' + op.FormaCobro + '</td>' +
                    '<td class="text-right">Gs. ' + formatGs(op.Monto) + '</td>' +
                    '<td class="text-right">Gs. ' + formatGs(op.MontoRecibido) + '</td>' +
                    '<td class="text-right">Gs. ' + formatGs(op.MontoCambio) + '</td>' +
                    '<td>' + badgeEstado + '</td>' +
                    '</tr>'
                );
            });
        }

        $('#tfMonto').text('Gs. ' + formatGs(total));
        $('#lblTotalVentas').text('Gs. ' + formatGs(total));
    });
}

// ─── CIERRE ────────────────────────────────────────────────
function abrirModalCierre() {
    $('#txtMontoContado').val(0);
    $('#txtObservacionCierre').val('');
    $('#alertDiferencia').hide();
    $('#modalCierre').modal('show');
}

function calcularDiferencia() {
    var contado  = parseFloat($('#txtMontoContado').val()) || 0;
    var sistema  = parseFloat($('#lblSistemaCierre').text().replace(/\D/g, '')) || 0;
    var diff     = contado - sistema;
    var alert    = $('#alertDiferencia');
    alert.show();
    $('#lblDiferencia').text('Gs. ' + formatGs(Math.abs(diff)));
    if (diff === 0) {
        alert.removeClass('alert-danger alert-warning').addClass('alert-success');
        $('#lblDiferencia').text('Gs. 0 — Sin diferencia ✓');
    } else if (diff > 0) {
        alert.removeClass('alert-danger alert-success').addClass('alert-warning');
        $('#lblDiferencia').text('+ Gs. ' + formatGs(diff) + ' (sobrante)');
    } else {
        alert.removeClass('alert-warning alert-success').addClass('alert-danger');
        $('#lblDiferencia').text('- Gs. ' + formatGs(Math.abs(diff)) + ' (faltante)');
    }
}

function cerrarCaja() {
    var idCaja   = parseInt($('#hdnIdCaja').val()) || 0;
    var contado  = parseFloat($('#txtMontoContado').val()) || 0;
    var obs      = $('#txtObservacionCierre').val();

    Swal.fire({
        title: '¿Cerrar caja?',
        text:  'Esta acción cierra el turno actual. No se podrá reabrir.',
        icon:  'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, cerrar',
        confirmButtonColor: '#dc3545',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:    $.MisUrls.url._CajaVenta_Cerrar,
            method: 'POST',
            data:   { idCaja: idCaja, montoContado: contado, observacion: obs },
            success: function (res) {
                if (res.resultado) {
                    $('#modalCierre').modal('hide');
                    toastr.success(res.mensaje);
                    // Abrir arqueo de cierre en nueva pestaña
                    window.open($.MisUrls.url._CajaVenta_Arqueo + '?idCaja=' + idCaja, '_blank');
                    setTimeout(function () { location.reload(); }, 1200);
                } else {
                    toastr.error(res.mensaje);
                }
            },
            error: function () { toastr.error('Error de conexión.'); }
        });
    });
}

// ─── HISTORIAL ─────────────────────────────────────────────
function cargarHistorial() {
    $.get($.MisUrls.url._CajaVenta_Historial, function (r) {
        var tbody = $('#tbodyHistorial');
        tbody.empty();
        if (!r.data || r.data.length === 0) {
            tbody.append('<tr><td colspan="11" class="text-center text-muted">Sin registros.</td></tr>');
            return;
        }
        r.data.forEach(function (c, i) {
            var estado = c.Estado === 'Abierta'
                ? '<span class="badge badge-success">Abierta</span>'
                : '<span class="badge badge-secondary">Cerrada</span>';
            var diff = c.Diferencia != null
                ? (c.Diferencia >= 0
                    ? '<span class="text-success">+Gs. ' + formatGs(c.Diferencia) + '</span>'
                    : '<span class="text-danger">-Gs. ' + formatGs(Math.abs(c.Diferencia)) + '</span>')
                : '—';
            tbody.append(
                '<tr>' +
                '<td>' + (i + 1) + '</td>' +
                '<td>' + c.NombreTienda + '</td>' +
                '<td>' + c.NombreUsuario + '</td>' +
                '<td>' + formatFechaHora(c.FechaApertura) + '</td>' +
                '<td class="text-right">Gs. ' + formatGs(c.MontoApertura) + '</td>' +
                '<td>' + (c.FechaCierre ? formatFechaHora(c.FechaCierre) : '—') + '</td>' +
                '<td class="text-right">' + (c.MontoSistema != null ? 'Gs. ' + formatGs(c.MontoSistema) : '—') + '</td>' +
                '<td class="text-right">' + (c.MontoContado != null ? 'Gs. ' + formatGs(c.MontoContado) : '—') + '</td>' +
                '<td class="text-right">' + diff + '</td>' +
                '<td>' + estado + '</td>' +
                '<td>' +
                '<a href="' + $.MisUrls.url._CajaVenta_Reporte + '?idCaja=' + c.IdCaja + '" class="btn btn-xs btn-outline-primary btn-sm mr-1" title="Ver detalle"><i class="fas fa-eye"></i></a>' +
                '<a href="' + $.MisUrls.url._CajaVenta_Arqueo  + '?idCaja=' + c.IdCaja + '" target="_blank" class="btn btn-xs btn-outline-secondary btn-sm" title="Arqueo de cierre"><i class="fas fa-print"></i></a>' +
                '</td>' +
                '</tr>'
            );
        });
    });
}

// ─── HELPERS ───────────────────────────────────────────────
function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatHora(dt) {
    if (!dt) return '—';
    var m = dt.match(/(\d+)/g);
    if (!m) return dt;
    return ('0' + m[3]).slice(-2) + ':' + ('0' + m[4]).slice(-2);
}
function formatFechaHora(dt) {
    if (!dt) return '—';
    var m = dt.match(/(\d+)/g);
    if (!m) return dt;
    return ('0' + m[2]).slice(-2) + '/' + ('0' + m[1]).slice(-2) + '/' + m[0] +
           ' ' + ('0' + m[3]).slice(-2) + ':' + ('0' + m[4]).slice(-2);
}
