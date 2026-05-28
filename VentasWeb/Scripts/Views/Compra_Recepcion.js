// ═══════════════════════════════════════════════════════
//  COMPRA — RECEPCIÓN DE MERCADERÍA DESDE OC
// ═══════════════════════════════════════════════════════

// idCompraActual y idOCActual se declaran en la vista (Recepcion.cshtml)

$(function () {
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $('.datepicker').datepicker({ dateFormat: 'dd/mm/yy', changeYear: true, changeMonth: true });

    // Fecha factura y entrega por defecto = hoy
    $('#txtFechaFactura').datepicker('setDate', new Date());
    $('#txtFechaEntrega').datepicker('setDate', new Date());

    // Fecha Vencimiento Timbrado por defecto = hoy + 1 año
    var hoyMasUnAnio = new Date();
    hoyMasUnAnio.setFullYear(hoyMasUnAnio.getFullYear() + 1);
    $('#txtFechaVencTimbrado').datepicker('setDate', hoyMasUnAnio);

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
var _fechaOC            = null;  // Date — fecha de registro de la OC
var _fechaTopeEntregaOC = null;  // Date — fecha tope de entrega pactada en la OC

function parsearFechaOC(valorJson) {
    if (!valorJson) return null;
    var s = String(valorJson);

    // 1) ASP.NET MVC serializa DateTime como /Date(milisegundos)/
    var mTicks = s.match(/\/Date\((-?\d+)(?:[+-]\d+)?\)\//);
    if (mTicks) {
        var d1 = new Date(parseInt(mTicks[1]));
        d1.setHours(0, 0, 0, 0);
        // Descartar DateTime.MinValue (año < 1900)
        if (isNaN(d1.getTime()) || d1.getFullYear() < 1900) return null;
        return d1;
    }

    // 2) Formato dd/MM/yyyy (como llegan los strings desde el SP)
    var mDMY = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (mDMY) {
        var d2 = new Date(parseInt(mDMY[3]), parseInt(mDMY[2]) - 1, parseInt(mDMY[1]));
        d2.setHours(0, 0, 0, 0);
        return isNaN(d2.getTime()) ? null : d2;
    }

    // 3) Formato ISO yyyy-MM-dd (fallback)
    var mISO = s.match(/(\d{4})-(\d{2})-(\d{2})/);
    if (mISO) {
        var d3 = new Date(parseInt(mISO[1]), parseInt(mISO[2]) - 1, parseInt(mISO[3]));
        d3.setHours(0, 0, 0, 0);
        return isNaN(d3.getTime()) ? null : d3;
    }

    return null;
}

function formatFechaDisplay(dt) {
    if (!dt) return '';
    return String(dt.getDate()).padStart(2,'0') + '/' +
           String(dt.getMonth()+1).padStart(2,'0') + '/' +
           dt.getFullYear();
}

function cargarLineasOC(idOC) {
    $.getJSON($.MisUrls.url._Compra_LineasOC, { idordencompra: idOC })
        .done(function (res) {
            if (!res.resultado) {
                Swal.fire({ title: 'Atención', text: res.mensaje || 'OC no encontrada o no está Aprobada.', icon: 'warning' });
                return;
            }

            var oc = res.data;

            // Guardar fechas de la OC para validaciones
            // FechaOrden llega como string "dd/MM/yyyy" y es la fecha real de creación.
            // FechaRegistro llega como DateTime.MinValue porque el SP no la mapea en el XML.
            _fechaOC            = parsearFechaOC(oc.FechaOrden);
            _fechaTopeEntregaOC = parsearFechaOC(oc.FechaTopeEntrega);

            // Cabecera
            $('#txtProveedor').val(oc.oProveedor ? oc.oProveedor.RazonSocial : '');
            $('#txtNumeroOrden').val(oc.NumeroOrden);
            $('#txtTienda').val(oc.oTienda ? oc.oTienda.Nombre : '');

            // Mostrar fechas de la OC como referencia visual
            $('#txtFechaOC').val(formatFechaDisplay(_fechaOC));
            $('#txtFechaTopeOC').val(formatFechaDisplay(_fechaTopeEntregaOC));

            // Líneas
            var tbody = $('#tbodyLineas').empty();
            $.each(oc.oListaDetalle, function (i, d) {
                var precio   = d.PrecioUnitario || 0;
                var total    = d.Cantidad * precio;
                var unidad   = (d.oProducto && d.oProducto.UnidadMedida) ? d.oProducto.UnidadMedida : 'Unidad';
                var lblUnidad = unidad === 'Metro' ? 'mts' : (unidad === 'Unidad' ? 'und.' : unidad.toLowerCase() + '.');
                tbody.append(
                    '<tr>' +
                    '<td>' + (d.oProducto ? d.oProducto.Nombre : 'Producto') + '</td>' +
                    '<td class="text-center">' + d.Cantidad + ' <small class="text-muted">' + lblUnidad + '</small></td>' +
                    '<td class="text-center">' +
                      '<input type="number" class="form-control form-control-sm txtRecibida" ' +
                      'data-id="'      + d.IdDetalleOrdenCompra + '" ' +
                      'data-precio="'  + precio + '" ' +
                      'data-cantidad="' + d.Cantidad + '" ' +
                      'value="' + d.Cantidad + '" min="0" max="' + d.Cantidad + '" ' +
                      'style="width:80px;margin:auto" />' +
                      '<div class="text-muted" style="font-size:11px;">' + lblUnidad + '</div>' +
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

    // ── Validar que fecha de factura >= fecha de OC ─────────────────────
    if (_fechaOC) {
        var dtFF = parseFechaRec(ff);
        if (dtFF && dtFF < _fechaOC) {
            Swal.fire({
                title: 'Fecha inválida',
                text:  'La Fecha de Factura (' + ff + ') no puede ser anterior a la fecha de registro de la OC (' + formatFechaDisplay(_fechaOC) + ').',
                icon:  'warning'
            });
            $('#txtFechaFactura').addClass('is-invalid').focus();
            return;
        }
    }

    // ── Validar que fecha de entrega >= fecha de OC ──────────────────────
    if (fe && _fechaOC) {
        var dtFE = parseFechaRec(fe);
        if (dtFE && dtFE < _fechaOC) {
            Swal.fire({
                title: 'Fecha de Entrega inválida',
                text:  'La Fecha de Entrega (' + fe + ') no puede ser anterior a la fecha de registro de la OC (' + formatFechaDisplay(_fechaOC) + ').',
                icon:  'warning'
            });
            $('#txtFechaEntrega').addClass('is-invalid').focus();
            return;
        }
        // Advertir (sin bloquear) si la entrega supera el tope pactado en la OC
        if (dtFE && _fechaTopeEntregaOC && dtFE > _fechaTopeEntregaOC) {
            Swal.fire({
                title: 'Entrega fuera de plazo',
                html:  'La Fecha de Entrega (<strong>' + fe + '</strong>) supera el tope pactado en la OC (<strong>' + formatFechaDisplay(_fechaTopeEntregaOC) + '</strong>).<br/><br/>¿Desea guardar de todas formas?',
                icon:  'warning',
                showCancelButton:  true,
                confirmButtonText: 'Sí, guardar igual',
                cancelButtonText:  'Cancelar'
            }).then(function (result) {
                if (result.isConfirmed) _enviarRecepcion();
            });
            return; // esperar respuesta del SweetAlert
        }
    }

    _enviarRecepcion();
}

// ── Enviar petición AJAX de recepción ────────────────
function _enviarRecepcion() {
    var nf  = $('#txtNumeroFactura').val().trim();
    var nt  = $('#txtNumeroTimbrado').val().trim();
    var fvt = $('#txtFechaVencTimbrado').val().trim();
    var ff  = $('#txtFechaFactura').val().trim();
    var fe  = $('#txtFechaEntrega').val().trim();

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
