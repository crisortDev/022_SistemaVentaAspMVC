// ═══════════════════════════════════════════════════════
//  COMPRA — RECEPCIÓN DE MERCADERÍA DESDE OC
// ═══════════════════════════════════════════════════════

// idCompraActual y idOCActual se declaran en la vista (Recepcion.cshtml)

$(function () {
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $('.datepicker').datepicker({ dateFormat: 'dd/mm/yy', changeYear: true, changeMonth: true });

    // Fecha entrega por defecto = hoy
    $('#txtFechaEntrega').datepicker('setDate', new Date());

    $('#btnBuscarOC').on('click', function () {
        idOCActual = parseInt($('#txtIdOrdenCompra').val()) || 0;
        if (idOCActual <= 0) {
            Swal.fire({ title: 'Atención', text: 'Ingrese un ID de Orden de Compra válido.', icon: 'warning' });
            return;
        }
        cargarLineasOC(idOCActual);
    });

    $('#btnGuardarRecepcion').on('click', guardarRecepcion);
    $('#btnConfirmar').on('click',  confirmarCompra);
    $('#btnGenerarOP').on('click',  generarOP);
    $('#btnNC').on('click',         generarNC);

    // Recalcular total al cambiar cantidades
    $(document).on('input', '.txtRecibida', recalcularTotal);
});

// ── Cargar líneas desde la OC ─────────────────────────
function cargarLineasOC(idOC) {
    $.getJSON($.MisUrls.url._Compra_LineasOC, { idordencompra: idOC })
        .done(function (res) {
            if (!res.resultado) {
                Swal.fire({ title: 'Atención', text: res.mensaje || 'OC no encontrada o no está Aprobada.', icon: 'warning' });
                return;
            }

            var oc = res.data;

            // Cabecera
            $('#txtProveedor').val(oc.oProveedor ? oc.oProveedor.RazonSocial : '');
            $('#txtNumeroOrden').val(oc.NumeroOrden);
            $('#txtTienda').val(oc.oTienda ? oc.oTienda.Nombre : '');

            // Líneas
            var tbody = $('#tbodyLineas').empty();
            $.each(oc.oListaDetalle, function (i, d) {
                var precio = d.PrecioUnitario || 0;
                var total  = d.Cantidad * precio;
                tbody.append(
                    '<tr>' +
                    '<td>' + (d.oProducto ? d.oProducto.Nombre : 'Producto') + '</td>' +
                    '<td class="text-center">' + d.Cantidad + '</td>' +
                    '<td class="text-center">' +
                      '<input type="number" class="form-control form-control-sm txtRecibida" ' +
                      'data-id="'      + d.IdDetalleOrdenCompra + '" ' +
                      'data-precio="'  + precio + '" ' +
                      'data-cantidad="' + d.Cantidad + '" ' +
                      'value="' + d.Cantidad + '" min="0" max="' + d.Cantidad + '" ' +
                      'style="width:80px;margin:auto" />' +
                    '</td>' +
                    '<td class="text-center">Gs. ' + formatGs(precio) + '</td>' +
                    '<td class="text-center total-linea">Gs. ' + formatGs(total) + '</td>' +
                    '</tr>'
                );
            });

            recalcularTotal();

            // Mostrar panel
            $('#panelRecepcion').removeClass('d-none');
            $('#panelFase2').addClass('d-none');
            $('#panelGuardar').show();
            $('#btnNC').prop('disabled', false).html('<i class="fas fa-file-invoice-dollar"></i> Generar NC');
            idCompraActual = 0;
        })
        .fail(function () {
            Swal.fire({ title: 'Error', text: 'Error al cargar la Orden de Compra.', icon: 'error' });
        });
}

// ── Recalcular totales ────────────────────────────────
function recalcularTotal() {
    var total = 0;
    $('.txtRecibida').each(function () {
        var cant   = parseInt($(this).val()) || 0;
        var precio = parseFloat($(this).data('precio')) || 0;
        var linea  = cant * precio;
        total += linea;
        $(this).closest('tr').find('.total-linea').text('Gs. ' + formatGs(linea));
    });
    $('#tdTotalCompra').text('Gs. ' + formatGs(total));
}

function formatGs(n) {
    return Math.round(n).toLocaleString('es-PY');
}

// ── Guardar recepción (crea COMPRA + DETALLE en un paso) ──
function guardarRecepcion() {
    if (idOCActual <= 0) {
        Swal.fire({ title: 'Atención', text: 'Primero busque una Orden de Compra.', icon: 'warning' });
        return;
    }

    var nf  = $('#txtNumeroFactura').val().trim();
    var nt  = $('#txtNumeroTimbrado').val().trim();
    var fvt = $('#txtFechaVencTimbrado').val().trim();
    var ff  = $('#txtFechaFactura').val().trim();
    var fe  = $('#txtFechaEntrega').val().trim();

    if (!nf)  { Swal.fire({ title: 'Atención', text: 'Ingrese el N° de Factura.',            icon: 'warning' }); return; }
    if (!nt)  { Swal.fire({ title: 'Atención', text: 'Ingrese el N° de Timbrado.',           icon: 'warning' }); return; }
    if (!fvt) { Swal.fire({ title: 'Atención', text: 'Ingrese la Fecha de Venc. Timbrado.',  icon: 'warning' }); return; }
    if (!ff)  { Swal.fire({ title: 'Atención', text: 'Ingrese la Fecha de Factura.',         icon: 'warning' }); return; }

    // Construir data con binding indexado para List<T>
    var data = {
        idordencompra:     idOCActual,
        numerofactura:     nf,
        numerotimbrado:    nt,
        fechavencTimbrado: fvt,
        fechafactura:      ff,
        fechaentrega:      fe
    };

    $('.txtRecibida').each(function (i) {
        data['lineas[' + i + '].IdDetalleOC']       = parseInt($(this).data('id'))       || 0;
        data['lineas[' + i + '].CantidadRecibida']  = parseInt($(this).val())            || 0;
    });

    $.ajax({
        url:  $.MisUrls.url._Compra_RegistrarDesdeOC,
        type: 'POST',
        data: data,
        beforeSend: function () { $('body').LoadingOverlay('show'); },
        complete:   function () { $('body').LoadingOverlay('hide'); },
        success: function (res) {
            if (res.resultado) {
                idCompraActual = res.idcompra;
                Swal.fire({ title: 'Éxito', text: res.mensaje || 'Recepción guardada.', icon: 'success' });
                // Pasar a Fase 2
                $('#panelGuardar').hide();
                $('#panelFase2').removeClass('d-none');
                // Bloquear campos fiscales y cantidades
                $('#txtNumeroFactura, #txtNumeroTimbrado, #txtFechaVencTimbrado, #txtFechaFactura, #txtFechaEntrega').prop('readonly', true);
                $('.txtRecibida').prop('disabled', true);
                $('#btnBuscarOC, #txtIdOrdenCompra').prop('disabled', true);
            } else {
                Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
            }
        },
        error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
    });
}

// ── Confirmar compra ──────────────────────────────────
function confirmarCompra() {
    if (idCompraActual <= 0) {
        Swal.fire({ title: 'Atención', text: 'Primero guarde la recepción.', icon: 'warning' });
        return;
    }
    Swal.fire({
        title: '¿Confirmar compra?',
        text:  'Esta acción actualizará el stock.',
        icon:  'question',
        showCancelButton:  true,
        confirmButtonText: 'Confirmar',
        cancelButtonText:  'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:  $.MisUrls.url._Compra_Confirmar,
            type: 'POST',
            data: { idcompra: idCompraActual },
            beforeSend: function () { $('body').LoadingOverlay('show'); },
            complete:   function () { $('body').LoadingOverlay('hide'); },
            success: function (res) {
                if (res.resultado) Swal.fire({ title: 'Éxito', text: res.mensaje || 'Compra confirmada.', icon: 'success' });
                else Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
            },
            error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
        });
    });
}

// ── Generar Orden de Pago ─────────────────────────────
function generarOP() {
    if (idCompraActual <= 0) {
        Swal.fire({ title: 'Atención', text: 'Primero guarde y confirme la recepción.', icon: 'warning' });
        return;
    }
    Swal.fire({
        title: '¿Generar Orden de Pago?',
        text:  'Se creará la OP para esta compra.',
        icon:  'question',
        showCancelButton:  true,
        confirmButtonText: 'Generar',
        cancelButtonText:  'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:  $.MisUrls.url._Compra_GenerarOP,
            type: 'POST',
            data: { idcompra: idCompraActual },
            beforeSend: function () { $('body').LoadingOverlay('show'); },
            complete:   function () { $('body').LoadingOverlay('hide'); },
            success: function (res) {
                if (res.resultado) {
                    Swal.fire({ title: 'Éxito', text: res.mensaje || 'Orden de Pago generada.', icon: 'success' });
                    if (res.idgenerado > 0)
                        window.open($.MisUrls.url._OP_Documento + '?idordenpago=' + res.idgenerado, '_blank');
                } else {
                    Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
                }
            },
            error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
        });
    });
}

// ── Generar Nota de Crédito ───────────────────────────
function generarNC() {
    if (idCompraActual <= 0) {
        Swal.fire({ title: 'Atención', text: 'Primero guarde la recepción.', icon: 'warning' });
        return;
    }
    var idMotivo = parseInt($('#cboMotivoNC').val()) || 0;
    if (idMotivo <= 0) {
        Swal.fire({ title: 'Atención', text: 'Seleccione un motivo de NC.', icon: 'warning' });
        return;
    }
    $.ajax({
        url:  $.MisUrls.url._Compra_NotaCredito,
        type: 'POST',
        data: { idcompra: idCompraActual, idmotivoNC: idMotivo },
        beforeSend: function () { $('body').LoadingOverlay('show'); },
        complete:   function () { $('body').LoadingOverlay('hide'); },
        success: function (res) {
            if (res.resultado) {
                Swal.fire({ title: 'Éxito', text: res.mensaje || 'Nota de crédito generada.', icon: 'success' });
                // Deshabilitar botón para evitar NC duplicadas
                $('#btnNC').prop('disabled', true).html('<i class="fas fa-check"></i> NC Generada');
            } else {
                Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
            }
        },
        error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
    });
}
