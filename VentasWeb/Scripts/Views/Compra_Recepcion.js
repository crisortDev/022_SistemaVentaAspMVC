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
    $('#btnNC').on('click', generarNC);

    // Recalcular total al cambiar cantidades
    $(document).on('input', '.txtRecibida', recalcularTotal);

    // Limpiar is-invalid al corregir el número de factura
    $('#txtNumeroFactura').on('input', function () {
        $(this).removeClass('is-invalid');
    });
});

// ── Cargar líneas desde la OC ─────────────────────────
var _fechaOC = null;   // Date — fecha de registro de la OC, para validar fecha factura

function cargarLineasOC(idOC) {
    $.getJSON($.MisUrls.url._Compra_LineasOC, { idordencompra: idOC })
        .done(function (res) {
            if (!res.resultado) {
                Swal.fire({ title: 'Atención', text: res.mensaje || 'OC no encontrada o no está Aprobada.', icon: 'warning' });
                return;
            }

            var oc = res.data;

            // Guardar fecha de la OC para validación posterior (punto b)
            if (oc.FechaRegistro) {
                var m = String(oc.FechaRegistro).match(/(\d{4})-(\d{2})-(\d{2})/);
                if (m) _fechaOC = new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]));
            } else {
                _fechaOC = null;
            }

            // Cabecera
            $('#txtProveedor').val(oc.oProveedor ? oc.oProveedor.RazonSocial : '');
            $('#txtNumeroOrden').val(oc.NumeroOrden);
            $('#txtTienda').val(oc.oTienda ? oc.oTienda.Nombre : '');

            // Mostrar fecha OC como referencia visual
            if (_fechaOC) {
                var dd = String(_fechaOC.getDate()).padStart(2,'0');
                var mm = String(_fechaOC.getMonth()+1).padStart(2,'0');
                var aaaa = _fechaOC.getFullYear();
                $('#txtFechaOC').val(dd + '/' + mm + '/' + aaaa);
            }

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

            // Mostrar panel de captura; ocultar Fase 2 y NC hasta guardar
            $('#panelRecepcion').removeClass('d-none');
            $('#panelFase2').addClass('d-none');
            $('#panelNC').addClass('d-none');
            $('#panelGuardar').show();
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

    // ── Validaciones de campos obligatorios ────────────────────────────
    if (!nf) {
        Swal.fire({ title: 'Atención', text: 'Ingrese el N° de Factura.', icon: 'warning' }); return;
    }
    if (!validarFormatoFactura(nf)) {
        Swal.fire({ title: 'Formato inválido', text: 'El número de factura debe tener el formato SET PY: xxx-xxx-xxxxxxx (ej: 001-001-0000001).', icon: 'warning' });
        $('#txtNumeroFactura').addClass('is-invalid').focus();
        return;
    }
    if (!nt)  { Swal.fire({ title: 'Atención', text: 'Ingrese el N° de Timbrado.',          icon: 'warning' }); return; }
    if (!fvt) { Swal.fire({ title: 'Atención', text: 'Ingrese la Fecha de Venc. Timbrado.', icon: 'warning' }); return; }
    if (!ff)  { Swal.fire({ title: 'Atención', text: 'Ingrese la Fecha de Factura.',        icon: 'warning' }); return; }

    // ── Validar que fecha de factura >= fecha de OC (punto b) ──────────
    if (_fechaOC) {
        var dtFF = parseFechaRec(ff);
        if (dtFF && dtFF < _fechaOC) {
            var strOC = String(_fechaOC.getDate()).padStart(2,'0') + '/' +
                        String(_fechaOC.getMonth()+1).padStart(2,'0') + '/' +
                        _fechaOC.getFullYear();
            Swal.fire({
                title: 'Fecha inválida',
                text:  'La fecha de la factura (' + ff + ') no puede ser anterior a la fecha de la Orden de Compra (' + strOC + ').',
                icon:  'warning'
            });
            $('#txtFechaFactura').addClass('is-invalid').focus();
            return;
        }
    }

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
        data['lineas[' + i + '].IdDetalleOC']      = parseInt($(this).data('id'))  || 0;
        data['lineas[' + i + '].CantidadRecibida'] = parseInt($(this).val())       || 0;
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

                // Bloquear campos fiscales y cantidades
                $('#txtNumeroFactura, #txtNumeroTimbrado, #txtFechaVencTimbrado, #txtFechaFactura, #txtFechaEntrega')
                    .prop('readonly', true).removeClass('is-invalid');
                $('.txtRecibida').prop('disabled', true);
                $('#btnBuscarOC, #txtIdOrdenCompra').prop('disabled', true);
                $('#panelGuardar').hide();

                // Verificar si hubo diferencia en alguna línea (recibido < pedido)
                var hayDiferencia = false;
                $('.txtRecibida').each(function () {
                    var recibido = parseInt($(this).val()) || 0;
                    var pedido   = parseInt($(this).data('cantidad')) || 0;
                    if (recibido < pedido) { hayDiferencia = true; return false; }
                });

                // Mostrar NC solo si hay diferencia
                if (hayDiferencia) {
                    $('#panelNC').removeClass('d-none');
                    $('#btnNC').prop('disabled', false)
                               .html('<i class="fas fa-file-invoice-dollar"></i> Generar NC');
                }

                // Mostrar Fase 2 (aviso de siguiente paso)
                $('#panelFase2').removeClass('d-none');
            } else {
                Swal.fire({ title: 'Error', text: res.mensaje, icon: 'error' });
            }
        },
        error: function () { Swal.fire({ title: 'Error', text: 'Error de red.', icon: 'error' }); }
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

// ══════════════════════════════════════════════════════
//  HELPERS — FORMATO Y VALIDACIÓN
// ══════════════════════════════════════════════════════

/**
 * Auto-formatea el campo N° Factura con guiones (xxx-xxx-xxxxxxx).
 * Igual al formateo de NC (mismo estándar SET Paraguay).
 */
function formatearNumFactura(input) {
    var v   = input.value.replace(/\D/g, '');
    var out = '';
    if (v.length > 0) out = v.substring(0, Math.min(3, v.length));
    if (v.length > 3) out += '-' + v.substring(3, Math.min(6, v.length));
    if (v.length > 6) out += '-' + v.substring(6, Math.min(13, v.length));
    input.value = out;
    $(input).removeClass('is-invalid');
}

/**
 * Valida formato xxx-xxx-xxxxxxx (3-3-7 dígitos con guiones).
 */
function validarFormatoFactura(str) {
    return /^\d{3}-\d{3}-\d{7}$/.test(str);
}

/**
 * Parsea fecha en formato dd/MM/yyyy a objeto Date.
 */
function parseFechaRec(str) {
    if (!str) return null;
    var p = str.split('/');
    if (p.length !== 3) return null;
    var d = new Date(parseInt(p[2]), parseInt(p[1]) - 1, parseInt(p[0]));
    d.setHours(0, 0, 0, 0);
    return isNaN(d.getTime()) ? null : d;
}
