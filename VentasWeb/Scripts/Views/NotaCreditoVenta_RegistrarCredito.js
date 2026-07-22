// NotaCreditoVenta_RegistrarCredito.js
// Selección de productos para NC de venta en cuotas
'use strict';

var infoVenta = null;

$(function () {
    cargarMotivos();
    cargarProductos();
    $('#chkTodos').on('change', function () {
        $('#tbodyProductos .chkProd').prop('checked', $(this).prop('checked'));
        recalcularNC();
    });
});

// ── Cargar motivos NC ──────────────────────────────────────────────────────────
function cargarMotivos() {
    $.get($.MisUrls.url._NCV_Motivos, function (r) {
        if (r && r.data) {
            r.data.forEach(function (m) {
                $('#cboMotivoNC').append($('<option>', { value: m.IdMotivoNotaCredito, text: m.Descripcion }));
            });
        }
    });
}

// ── Cargar productos de la venta ───────────────────────────────────────────────
function cargarProductos() {
    var idVenta = parseInt($('#hdnIdVenta').val()) || 0;
    if (!idVenta) {
        mostrarError('No se indicó una venta válida. Volvé al listado e intentá de nuevo.');
        return;
    }

    $.get($.MisUrls.url._NCV_ObtenerProductos, { idVenta: idVenta }, function (r) {
        $('#divCargando').addClass('d-none');

        if (!r.resultado) {
            mostrarError(r.mensaje || 'Error al cargar los datos de la venta.');
            return;
        }

        infoVenta = r.infoVenta;

        // Info de la venta
        $('#lblFactura').text(infoVenta.NumeroFactura || '—');
        $('#lblCliente').text(infoVenta.NombreCliente || '—');
        $('#lblFechaVenta').text(infoVenta.FechaVenta || '—');
        $('#lblTotalVenta').text('Gs. ' + formatGs(infoVenta.TotalCosto));
        $('#lblRecargo').text((infoVenta.RecargoCredito || 0) + '%');
        $('#lblFinanciado').text('Gs. ' + formatGs(infoVenta.MontoFinanciado));
        $('#lblCuotas').text(infoVenta.NumeroCuotas || '—');

        // Filas de productos
        var tbody = $('#tbodyProductos');
        tbody.empty();
        (r.productos || []).forEach(function (p) {
            tbody.append(
                '<tr>' +
                '<td class="text-center">' +
                    '<input type="checkbox" class="chkProd"' +
                    ' data-idproducto="' + p.IdProducto + '"' +
                    ' onchange="recalcularNC()" />' +
                '</td>' +
                '<td>' + escaparHtml(p.NombreProducto) + '</td>' +
                '<td class="text-center">' + formatCant(p.Cantidad) + '</td>' +
                '<td class="text-center">' +
                    '<input type="number" class="form-control form-control-sm text-center cantDevolver"' +
                    ' data-precio="' + p.PrecioUnitario + '"' +
                    ' data-max="' + p.Cantidad + '"' +
                    ' value="' + formatCant(p.Cantidad) + '"' +
                    ' min="0.01" max="' + p.Cantidad + '" step="0.01"' +
                    ' oninput="recalcularNC()" style="width:90px;margin:auto;" />' +
                '</td>' +
                '<td class="text-right">Gs. ' + formatGs(p.PrecioUnitario) + '</td>' +
                '<td class="text-right subtotal">—</td>' +
                '</tr>'
            );
        });

        $('#divContenido').removeClass('d-none');
        $('#btnRegistrar').removeClass('d-none');
    }).fail(function () {
        $('#divCargando').addClass('d-none');
        mostrarError('Error de conexión al cargar los datos.');
    });
}

// ── Recalcular totales NC ──────────────────────────────────────────────────────
function recalcularNC() {
    if (!infoVenta) return;

    var totalNC    = 0;
    var recargo    = parseFloat(infoVenta.RecargoCredito || 0);
    var nCuotas    = parseInt(infoVenta.NumeroCuotas || 0);
    var totalVenta = parseFloat(infoVenta.TotalCosto || 0);

    $('#tbodyProductos tr').each(function () {
        var chk    = $(this).find('.chkProd');
        var input  = $(this).find('.cantDevolver');
        var precio = parseFloat(input.data('precio') || 0);
        var cant   = parseFloat(input.val()) || 0;
        var sub    = chk.prop('checked') && cant > 0 ? cant * precio : 0;

        if (chk.prop('checked') && cant > 0) totalNC += sub;
        $(this).find('.subtotal').html(
            chk.prop('checked') && cant > 0
            ? '<strong class="text-warning">Gs. ' + formatGs(sub) + '</strong>'
            : '—'
        );
    });

    $('#lblMontoNC').text('Gs. ' + formatGs(totalNC));

    if (totalNC > 0) {
        var nuevoTotal      = Math.max(totalVenta - totalNC, 0);
        var nuevoFinanciado = Math.ceil(nuevoTotal * (1 + recargo / 100) / 50) * 50;

        if (nuevoTotal === 0) {
            $('#lblNuevoTotal').html('<strong class="text-danger">Gs. 0 — Venta se cancelará</strong>');
            $('#lblNuevoFinanciado').text('Gs. 0');
            $('#divNuevaCuota').addClass('d-none');
        } else {
            var nuevaCuota  = Math.floor(nuevoFinanciado / nCuotas / 50) * 50;
            var ultimaCuota = nuevoFinanciado - nuevaCuota * (nCuotas - 1);
            $('#lblNuevoTotal').html('<strong class="text-primary">Gs. ' + formatGs(nuevoTotal) + '</strong>');
            $('#lblNuevoFinanciado').text('Gs. ' + formatGs(nuevoFinanciado));
            var cuotaTexto = 'Gs. ' + formatGs(nuevaCuota) + ' × ' +
                (ultimaCuota !== nuevaCuota ? (nCuotas - 1) + ' + Gs. ' + formatGs(ultimaCuota) + ' (última)' : nCuotas);
            $('#lblNuevaCuota').text(cuotaTexto);
            $('#divNuevaCuota').removeClass('d-none');
        }
    } else {
        $('#lblNuevoTotal').html('—');
        $('#lblNuevoFinanciado').text('—');
        $('#divNuevaCuota').addClass('d-none');
    }
}

// ── Registrar NC ───────────────────────────────────────────────────────────────
function registrarNC() {
    var idVenta = parseInt($('#hdnIdVenta').val()) || 0;
    var motivo  = parseInt($('#cboMotivoNC').val()) || 0;
    var obs     = $('#txtObservacion').val().trim();

    if (!motivo) { toastr.warning('Seleccione el motivo de la nota de crédito.'); return; }
    if (!obs) { toastr.warning('La Observación es obligatoria.'); $('#txtObservacion').focus(); return; }

    var detalle = [];
    var hayError = false;

    $('#tbodyProductos tr').each(function () {
        var chk   = $(this).find('.chkProd');
        if (!chk.prop('checked')) return;

        var input  = $(this).find('.cantDevolver');
        var cant   = parseFloat(input.val()) || 0;
        var precio = parseFloat(input.data('precio') || 0);
        var max    = parseFloat(input.data('max') || 0);
        var idProd = parseInt(chk.data('idproducto') || 0);

        if (cant <= 0) {
            toastr.warning('La cantidad a devolver debe ser mayor a 0.');
            hayError = true; return false;
        }
        if (cant > max) {
            toastr.warning('La cantidad no puede superar la vendida (' + formatCant(max) + ').');
            hayError = true; return false;
        }

        detalle.push({ IdProducto: idProd, Cantidad: cant, PrecioUnitario: precio });
    });

    if (hayError) return;

    if (detalle.length === 0) {
        toastr.warning('Seleccione al menos un producto.');
        return;
    }

    var montoTotal = detalle.reduce(function (acc, d) { return acc + d.Cantidad * d.PrecioUnitario; }, 0);

    Swal.fire({
        title: '¿Confirmar solicitud de NC?',
        html: 'Se registrará una NC por <strong>Gs. ' + formatGs(montoTotal) + '</strong> (' + detalle.length + ' producto(s)).<br>' +
              'Quedará pendiente de aprobación del Encargado.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, registrar',
        confirmButtonColor: '#f0ad4e',
        cancelButtonText: 'Cancelar'
    }).then(function (res) {
        if (!res.isConfirmed) return;

        $('#btnRegistrar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Registrando...');

        $.ajax({
            url:    $.MisUrls.url._NCV_RegistrarCredito,
            method: 'POST',
            data: {
                idVenta:      idVenta,
                idMotivoNC:   motivo,
                observacion:  obs,
                productosJson: JSON.stringify(detalle)
            },
            success: function (r) {
                if (r.resultado) {
                    Swal.fire('Registrado', r.mensaje, 'success').then(function () {
                        window.location.href = $.MisUrls.url._NCV_Index;
                    });
                } else {
                    toastr.error(r.mensaje || 'Error al registrar.');
                    $('#btnRegistrar').prop('disabled', false)
                        .html('<i class="fas fa-save"></i> Registrar Solicitud de NC');
                }
            },
            error: function () {
                toastr.error('Error de conexión.');
                $('#btnRegistrar').prop('disabled', false)
                    .html('<i class="fas fa-save"></i> Registrar Solicitud de NC');
            }
        });
    });
}

// ── Helpers ────────────────────────────────────────────────────────────────────
function mostrarError(msg) {
    $('#divError').removeClass('d-none').html('<i class="fas fa-times-circle mr-1"></i>' + escaparHtml(msg));
    $('#btnRegistrar').addClass('d-none');
}
function formatGs(n)   { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatCant(n) { var f = parseFloat(n) || 0; return f % 1 === 0 ? parseInt(f) : f.toFixed(2); }
function escaparHtml(s) {
    return (s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
