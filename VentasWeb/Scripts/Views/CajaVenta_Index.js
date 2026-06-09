// CajaVenta_Index.js
'use strict';

$(function () {
    cargarHistorial();
    // Si hay caja abierta, cargar operaciones
    if ($('#hdnIdCaja').length) {
        recargarOperaciones();
    }
    // Si está el panel de apertura, cargar las cajas disponibles
    if ($('#ddlPuntoCaja').length) {
        cargarCajasDisponibles();
        // Si el SuperAdmin cambia de tienda, recargar las cajas de esa tienda
        $('#ddlTiendaApertura').on('change', cargarCajasDisponibles);
    }
});

// ─── Cargar cajas disponibles (sin sesión abierta) ─────────
function cargarCajasDisponibles() {
    var idTienda = parseInt($('#ddlTiendaApertura').val()) || 0;
    var $cbo = $('#ddlPuntoCaja');
    $cbo.html('<option value="0">-- Seleccioná una caja --</option>');

    $.get($.MisUrls.url._CajaVenta_CajasDisponibles, { idTienda: idTienda }, function (r) {
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            $cbo.append('<option value="0" disabled>No hay cajas disponibles</option>');
            return;
        }
        $.each(lista, function (i, c) {
            $cbo.append('<option value="' + c.IdPuntoCaja + '">' +
                c.Nombre + ' (Pto. Exp. ' + c.PuntoExpedicion + ')</option>');
        });
    });
}

// ─── APERTURA ──────────────────────────────────────────────
function abrirCaja() {
    var monto       = parseFloat($('#txtMontoApertura').val()) || 0;
    var idTienda    = parseInt($('#ddlTiendaApertura').val()) || 0;
    var idPuntoCaja = parseInt($('#ddlPuntoCaja').val()) || 0;

    if (monto < 0) { toastr.warning('El monto no puede ser negativo.'); return; }

    // Validar tienda solo si el selector está presente (SuperAdmin)
    if ($('#ddlTiendaApertura').length && idTienda === 0) {
        toastr.warning('Seleccioná una tienda antes de abrir la caja.');
        return;
    }

    if (idPuntoCaja === 0) {
        toastr.warning('Seleccioná una caja disponible.');
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

        var datos = { montoApertura: monto, idPuntoCaja: idPuntoCaja };
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
            var totalContado = 0, totalCredito = 0, totalCXC = 0;
            r.operaciones.forEach(function (op) {
                var esCredito = (op.Condicion === 'Crédito');
                var esCXC     = (op.Condicion === 'CobroCXC');

                var badgeEstado, badgeCond, trClass;

                if (esCXC) {
                    // Cobro de deuda CXC — fondo verde claro
                    badgeEstado = '<span class="badge badge-info">Cobro CXC</span>';
                    badgeCond   = '';
                    trClass     = 'class="table-success"';
                } else if (esCredito) {
                    badgeEstado = '<span class="badge badge-warning">Pendiente</span>';
                    badgeCond   = '<span class="badge badge-secondary ml-1">Crédito</span>';
                    trClass     = 'class="table-secondary"';
                } else {
                    badgeEstado = op.Estado === 'Activa'
                        ? '<span class="badge badge-success">Activa</span>'
                        : '<span class="badge badge-danger">Anulada</span>';
                    badgeCond = '';
                    trClass   = '';
                }

                var monto = esCXC ? op.MontoRecibido : (op.Estado === 'Activa' ? op.Monto : 0);
                if (esCXC) {
                    totalCXC += monto;
                } else if (op.Estado === 'Activa') {
                    if (esCredito) totalCredito += op.Monto;
                    else           totalContado += monto;
                }
                total += monto;

                var btnReimprimir = op.IdVenta
                    ? '<a href="' + $.MisUrls.url._Venta_Documento + '?idVenta=' + op.IdVenta + '" target="_blank" class="btn btn-xs btn-outline-primary btn-sm" title="Reimprimir factura"><i class="fas fa-print"></i></a>'
                    : '';

                // Columnas según tipo de operación
                var colFormaCobro = esCXC   ? op.FormaCobro
                                  : esCredito ? '<em class="text-muted">Crédito</em>'
                                  : op.FormaCobro;
                var colRecibido   = esCXC   ? 'Gs. ' + formatGs(op.MontoRecibido)
                                  : esCredito ? '<em class="text-muted">Pend.</em>'
                                  : 'Gs. ' + formatGs(op.MontoRecibido);
                var colCambio     = (esCXC || !esCredito) ? 'Gs. ' + formatGs(op.MontoCambio) : '—';
                var colMonto      = esCXC ? 'Gs. ' + formatGs(op.MontoRecibido)
                                          : 'Gs. ' + formatGs(op.Monto);

                tbody.append(
                    '<tr ' + trClass + '>' +
                    '<td>' + fila++ + '</td>' +
                    '<td>' + formatHora(op.FechaRegistro) + '</td>' +
                    '<td><code>' + op.NumeroFactura + '</code> ' + btnReimprimir + '</td>' +
                    '<td>' + op.NombreCliente + '</td>' +
                    '<td>' + colFormaCobro + '</td>' +
                    '<td class="text-right">' + colMonto + '</td>' +
                    '<td class="text-right">' + colRecibido + '</td>' +
                    '<td class="text-right">' + colCambio + '</td>' +
                    '<td>' + badgeEstado + badgeCond + '</td>' +
                    '</tr>'
                );
            });
            // Actualizar tarjetas de contado/crédito/CXC
            $('#lblTotalContado').text('Gs. ' + formatGs(totalContado));
            $('#lblTotalCredito').text('Gs. ' + formatGs(totalCredito));
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
    // Saldo esperado = apertura + ventas contado + cobros CXC (coincide con la fórmula del SP)
    var rawText  = $('#lblSaldoEsperadoCierre').text().replace(/[^0-9]/g, '');
    var sistema  = parseFloat(rawText) || 0;
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
                    // Volver a la pantalla de apertura (recarga forzada, sin caché)
                    // para que el cajero pueda seleccionar otra caja.
                    setTimeout(function () {
                        window.location.href = $.MisUrls.url._CajaVenta_Index + '?t=' + Date.now();
                    }, 1200);
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
// Convierte fechas .NET "/Date(ms)/" o ISO a objeto Date
function _parseFecha(dt) {
    if (!dt) return null;
    var ms = /\/Date\((\d+)/.exec(dt);
    var f = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt);
    return isNaN(f.getTime()) ? null : f;
}
function _pad(n) { return ('0' + n).slice(-2); }

function formatHora(dt) {
    var f = _parseFecha(dt);
    if (!f) return '—';
    return _pad(f.getHours()) + ':' + _pad(f.getMinutes());
}
function formatFechaHora(dt) {
    var f = _parseFecha(dt);
    if (!f) return '—';
    return _pad(f.getDate()) + '/' + _pad(f.getMonth() + 1) + '/' + f.getFullYear() +
           ' ' + _pad(f.getHours()) + ':' + _pad(f.getMinutes());
}
