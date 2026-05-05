// ═══════════════════════════════════════════════════════
//  COMPRA — RECEPCIÓN DE MERCADERÍA
// ═══════════════════════════════════════════════════════

var idCompraActual = 0;

$(function () {
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $('.datepicker').datepicker({ dateFormat: 'dd/mm/yy', changeYear: true, changeMonth: true });

    // Si la vista cargó con un idCompra predefinido (navegación desde Consultar)
    if (typeof idCompraInicial !== 'undefined' && idCompraInicial > 0) {
        idCompraActual = idCompraInicial;
        cargarLineas(idCompraActual);
    }

    $('#btnBuscarCompra').on('click', function () {
        idCompraActual = parseInt($('#txtIdCompra').val()) || 0;
        if (idCompraActual <= 0) { Swal.fire({ title: 'Atención', text: 'Ingrese un ID válido.', icon: 'warning' }); return; }
        cargarLineas(idCompraActual);
    });

    $('#btnGuardarRecepcion').on('click', guardarRecepcion);
    $('#btnConfirmar').on('click', confirmarCompra);
    $('#btnGenerarOP').on('click', generarOP);
    $('#btnNC').on('click', generarNC);
});

// ── Cargar líneas de la compra ────────────────────────
function cargarLineas(idCompra) {
    $.getJSON($.MisUrls.url._Compra_LineasRecepcion, { idcompra: idCompra })
        .done(function (res) {
            if (!res.data || res.data.length === 0) {
                Swal.fire({ title: 'Atención', text: 'No se encontraron líneas para esa compra.', icon: 'warning' });
                return;
            }
            $('#panelCompra').removeClass('d-none');
            var tbody = $('#tbodyLineas').empty();
            $.each(res.data, function (i, d) {
                tbody.append(
                    '<tr>' +
                    '<td>' + (d.oProducto ? d.oProducto.Nombre : 'ID ' + d.IdDetalleCompra) + '</td>' +
                    '<td class="text-center">' + (d.CantidadFacturada || d.Cantidad) + '</td>' +
                    '<td class="text-center">' +
                      '<input type="number" class="form-control form-control-sm txtRecibida" ' +
                      'data-id="' + d.IdDetalleCompra + '" value="' + (d.CantidadFacturada || d.Cantidad) +
                      '" min="0" style="width:80px;margin:auto" />' +
                    '</td>' +
                    '<td class="text-center">' + (d.EstadoLinea || 'Pendiente') + '</td>' +
                    '</tr>'
                );
            });
        })
        .fail(function () { Swal.fire({ title: 'Error', text: 'Error al cargar líneas.', icon: 'error' }); });
}

// ── Guardar recepción ─────────────────────────────────
function guardarRecepcion() {
    if (idCompraActual <= 0) { Swal.fire({ title: 'Atención', text: 'Primero busque una compra.', icon: 'warning' }); return; }
    var ff = $('#txtFechaFactura').val().trim();
    var fe = $('#txtFechaEntrega').val().trim();
    if (!ff) { Swal.fire({ title: 'Atención', text: 'Ingrese la fecha de factura.', icon: 'warning' }); return; }

    // MVC necesita el formato indexado lineas[0].IdDetalleCompra para List<T>
    var data = { idcompra: idCompraActual, fechafactura: ff, fechaentrega: fe };
    $('.txtRecibida').each(function (i) {
        data['lineas[' + i + '].IdDetalleCompra']  = parseInt($(this).data('id')) || 0;
        data['lineas[' + i + '].CantidadRecibida'] = parseInt($(this).val()) || 0;
    });

    $.ajax({
        url: $.MisUrls.url._Compra_RegistrarRecepcion,
        type: 'POST',
        data: data,
        beforeSend: function () { $('body').LoadingOverlay('show'); },
        complete:   function () { $('body').LoadingOverlay('hide'); },
        success: function (res) {
            if (res.resultado) Swal.fire({ title: 'Éxito', text: res.mensaje || 'Recepción registrada.', icon: 'success' });
            else Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
        },
        error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
    });
}

// ── Confirmar compra ──────────────────────────────────
function confirmarCompra() {
    if (idCompraActual <= 0) { Swal.fire({ title: 'Atención', text: 'Primero busque una compra.', icon: 'warning' }); return; }
    Swal.fire({
        title: '¿Confirmar compra?',
        text: 'Esta acción actualizará el stock.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Confirmar',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url: $.MisUrls.url._Compra_Confirmar,
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
    if (idCompraActual <= 0) { Swal.fire({ title: 'Atención', text: 'Primero busque una compra.', icon: 'warning' }); return; }
    Swal.fire({
        title: '¿Generar Orden de Pago?',
        text: 'Se creará la OP para esta compra.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Generar',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url: $.MisUrls.url._Compra_GenerarOP,
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
    if (idCompraActual <= 0) { Swal.fire({ title: 'Atención', text: 'Primero busque una compra.', icon: 'warning' }); return; }
    var idMotivo = parseInt($('#cboMotivoNC').val()) || 0;
    if (idMotivo <= 0) { Swal.fire({ title: 'Atención', text: 'Seleccione un motivo de NC.', icon: 'warning' }); return; }

    $.ajax({
        url: $.MisUrls.url._Compra_NotaCredito,
        type: 'POST',
        data: { idcompra: idCompraActual, idmotivoNC: idMotivo },
        beforeSend: function () { $('body').LoadingOverlay('show'); },
        complete:   function () { $('body').LoadingOverlay('hide'); },
        success: function (res) {
            if (res.resultado) Swal.fire({ title: 'Éxito', text: res.mensaje || 'Nota de crédito generada.', icon: 'success' });
            else Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
        },
        error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
    });
}
