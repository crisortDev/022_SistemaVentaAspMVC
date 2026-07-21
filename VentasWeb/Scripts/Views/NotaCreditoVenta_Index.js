// NotaCreditoVenta_Index.js
var dtNCV = null;
var detalleNCActual = [];
// Guarda el IdVenta detectado como crédito para redirigir
var idVentaCreditoActual = 0;

$(function () {
    var hoy = new Date();
    var hace30 = new Date(); hace30.setDate(hoy.getDate() - 30);
    $('#txtFechaInicio').val(formatFecha(hace30));
    $('#txtFechaFin').val(formatFecha(hoy));
    iniciarTabla();
    cargarMotivos();
    buscarNCV();
});

function iniciarTabla() {
    dtNCV = $('#tbNCV').DataTable({
        data: [],
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var btnPrint = '<a class="btn btn-outline-secondary btn-sm" title="Imprimir NC" ' +
                                   'href="' + $.MisUrls.url._NCV_Imprimir + '?idNCVenta=' + d.IdNCVenta + '" ' +
                                   'target="_blank"><i class="fas fa-print"></i></a>';

                    if (d.Estado !== 'Pendiente') return btnPrint;

                    var modal = escapar(d.ModalidadPago || 'Efectivo');
                    return '<button class="btn btn-success btn-sm mr-1" title="Aprobar" onclick="abrirAprobacion(' +
                               d.IdNCVenta + ',\'' + escapar(d.NumeroNCV) + '\',\'' + escapar(d.NumeroFactura) + '\',\'' +
                               escapar(d.NombreCliente) + '\',' + d.Monto + ',' + (d.SaldoActualCliente || 0) + ',\'Aprobar\',\'' + modal + '\')">' +
                               '<i class="fas fa-check"></i></button>' +
                           '<button class="btn btn-danger btn-sm mx-1" title="Rechazar" onclick="abrirAprobacion(' +
                               d.IdNCVenta + ',\'' + escapar(d.NumeroNCV) + '\',\'' + escapar(d.NumeroFactura) + '\',\'' +
                               escapar(d.NombreCliente) + '\',' + d.Monto + ',' + (d.SaldoActualCliente || 0) + ',\'Rechazar\',\'' + modal + '\')">' +
                               '<i class="fas fa-times"></i></button>' +
                           btnPrint;
                }
            },
            { data: 'NumeroNCV' },
            { data: 'NumeroFactura' },
            {
                data: null, render: function (d) {
                    var saldo = d.SaldoActualCliente || 0;
                    var badge = saldo > 0
                        ? ' <span class="badge badge-info" title="Saldo a favor vigente"><i class="fas fa-wallet mr-1"></i>Gs. ' + formatGs(saldo) + '</span>'
                        : '';
                    return escaparHtml(d.NombreCliente) + badge;
                }
            },
            { data: 'MotivoNC' },
            { data: 'Monto', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'NombreRegistro' },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            {
                data: 'Estado', render: function (v) {
                    var c = { 'Pendiente': 'warning', 'Aprobada': 'success', 'Rechazada': 'danger' };
                    return '<span class="badge badge-' + (c[v] || 'secondary') + '">' + v + '</span>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[8, 'desc']]
    });
}

function cargarMotivos() {
    $.get($.MisUrls.url._NCV_Motivos, function (r) {
        if (r && r.data) {
            r.data.forEach(function (m) {
                $('#cboMotivoNC').append($('<option>', { value: m.IdMotivoNotaCredito, text: m.Descripcion }));
            });
        }
    });
}

function buscarNCV() {
    var params = {
        fechainicio: $('#txtFechaInicio').val(),
        fechafin:    $('#txtFechaFin').val(),
        estado:      $('#cboEstado').val(),
        idtienda:    parseInt($('#cboTiendaNCV').val()) || 0
    };
    $.get($.MisUrls.url._NCV_Obtener, params, function (r) {
        dtNCV.clear().rows.add(r.data || []).draw();
    });
}

// ─── REGISTRAR NC (modal único) ──────────────────────────────────────────────

function abrirModalRegistrar() {
    // Reset completo del modal
    $('#txtBuscarFactura').val('');
    $('#hdnIdVentaNC').val(0);
    idVentaCreditoActual = 0;

    // Ocultar todas las secciones dinámicas
    $('#infoVentaNC').addClass('d-none');
    $('#divNCContado').addClass('d-none');
    $('#divNCCredito').addClass('d-none');
    $('#divBuscandoNC').addClass('d-none');
    $('#btnRegistrarNC').addClass('d-none');
    $('#btnIrProductos').addClass('d-none');

    // Reset campos contado
    $('#cboMotivoNC').val(0);
    $('#txtMontoNC').val(0);
    $('#txtObservacionNC').val('');

    $('#modalRegistrar').modal('show');
    setTimeout(function () { $('#txtBuscarFactura').focus(); }, 400);
}

/**
 * Busca la venta por número de factura y detecta automáticamente
 * si es contado (muestra form de monto) o crédito (muestra sección de redirect).
 */
function buscarVentaParaNC() {
    var nroFactura = $('#txtBuscarFactura').val().trim();
    if (!nroFactura) { toastr.warning('Ingrese el número de factura.'); return; }

    // Reset secciones
    $('#infoVentaNC').addClass('d-none');
    $('#divNCContado').addClass('d-none');
    $('#divNCCredito').addClass('d-none');
    $('#btnRegistrarNC').addClass('d-none');
    $('#btnIrProductos').addClass('d-none');
    $('#divBuscandoNC').removeClass('d-none');

    // Paso 1: obtener la venta para conseguir IdVenta e info básica
    $.get($.MisUrls.url._Venta_Obtener, { numerofactura: nroFactura, estado: 'Activa' }, function (r) {
        if (!r.data || r.data.length === 0) {
            $('#divBuscandoNC').addClass('d-none');
            toastr.warning('No se encontró una venta activa con ese número de factura.');
            return;
        }

        var v = r.data[0];
        var idVenta = v.IdVenta;

        // Mostrar info básica de la venta
        $('#hdnIdVentaNC').val(idVenta);
        $('#lblInfoVentaNC').html(
            '<i class="fas fa-file-invoice mr-1"></i>' +
            ' <strong>' + escaparHtml(nroFactura) + '</strong>' +
            ' &nbsp;|&nbsp; ' + escaparHtml(v.NombreCliente || '—') +
            ' &nbsp;|&nbsp; Total: <strong>Gs. ' + formatGs(v.TotalCosto) + '</strong>'
        );
        $('#alertVentaNC').removeClass('alert-success alert-info alert-warning').addClass('alert-success');
        $('#infoVentaNC').removeClass('d-none');

        // Paso 2: intentar cargar como crédito
        $.get($.MisUrls.url._NCV_ObtenerProductos, { idVenta: idVenta }, function (resp) {
            $('#divBuscandoNC').addClass('d-none');

            if (resp.resultado) {
                // ✅ Es una venta en CUOTAS válida para NC
                idVentaCreditoActual = idVenta;
                $('#divNCCredito').removeClass('d-none');
                $('#btnIrProductos').removeClass('d-none');
            } else {
                // El SP rechazó — determinar si es contado (mostrar form) u otro error (bloquear)
                var msg = (resp.mensaje || '').toLowerCase();
                var esContado = msg.indexOf('no es de crédito') !== -1 ||
                                msg.indexOf('no es crédito')    !== -1 ||
                                msg.indexOf('contado')          !== -1 ||
                                msg.indexOf('transferencia')    !== -1;

                if (esContado) {
                    // Venta contado/transferencia: mostrar formulario de monto manual
                    $('#txtMontoNC').val(Math.round(v.TotalCosto));
                    $('#divNCContado').removeClass('d-none');
                    $('#btnRegistrarNC').removeClass('d-none');
                } else {
                    // Otro error de validación (cuotas pagadas, NC ya existe, etc.)
                    toastr.error(resp.mensaje || 'No se puede crear una NC para esta venta.');
                    // Deshabilitar botones, solo mostrar info
                    $('#alertVentaNC').removeClass('alert-success').addClass('alert-warning');
                }
            }
        }).fail(function () {
            $('#divBuscandoNC').addClass('d-none');
            toastr.error('Error de conexión al verificar la venta.');
        });

    }).fail(function () {
        $('#divBuscandoNC').addClass('d-none');
        toastr.error('Error de conexión.');
    });
}

/** Redirige a la vista de selección de productos para NC en cuotas */
function irASeleccionProductos() {
    if (!idVentaCreditoActual) { toastr.warning('No hay una venta en cuotas seleccionada.'); return; }
    $('#modalRegistrar').modal('hide');
    window.location.href = $.MisUrls.url._NCV_RegistrarCredito + '?idVenta=' + idVentaCreditoActual;
}

/** Registra NC contado (monto manual) */
function registrarNC() {
    var idVenta = parseInt($('#hdnIdVentaNC').val()) || 0;
    if (!idVenta) { toastr.warning('Busque y seleccione una factura válida.'); return; }
    var motivo = parseInt($('#cboMotivoNC').val());
    if (!motivo) { toastr.warning('Seleccione el motivo.'); return; }
    var monto = parseFloat($('#txtMontoNC').val()) || 0;
    if (monto <= 0) { toastr.warning('El monto debe ser mayor a cero.'); return; }

    $.ajax({
        url: $.MisUrls.url._NCV_Registrar,
        method: 'POST',
        data: { idVenta: idVenta, idMotivoNC: motivo, monto: monto, observacion: $('#txtObservacionNC').val() },
        success: function (r) {
            if (r.resultado) {
                toastr.success('Nota de crédito registrada. Pendiente de aprobación.');
                $('#modalRegistrar').modal('hide');
                buscarNCV();
            } else {
                toastr.error(r.mensaje || 'Error al registrar.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

// ─── APROBAR / RECHAZAR ──────────────────────────────────────────────────────

function abrirAprobacion(id, numero, factura, cliente, monto, saldoActual, accion, modalidadPago) {
    $('#hdnIdNCV').val(id);
    $('#hdnAccionNCV').val(accion);
    $('#lblNcvAprobacion').text(numero);
    $('#lblVentaAprobacion').text(factura);
    $('#lblMontoAprobacion').text('Gs. ' + formatGs(monto));
    $('#txtMotivoRechazo').val('');
    detalleNCActual = [];

    if (accion === 'Aprobar') {
        $('#divInfoSaldoFavor').html('<i class="fas fa-spinner fa-spin"></i> Cargando detalle...').removeClass('d-none');
        $('#divMotivoRechazo').addClass('d-none');
        $('#modalAprobacionHeader').removeClass('bg-danger').addClass('bg-success');
        $('#lblTituloAprobacion').html('<i class="fas fa-check mr-1"></i> Aprobar Nota de Crédito');
        $('#btnConfirmarAprobacion').removeClass('btn-danger').addClass('btn-success');

        $.get($.MisUrls.url._NCV_ObtenerDetalle, { idNCVenta: id }, function (r) {
            var detalle = (r && r.data) || [];
            detalleNCActual = detalle;

            if (modalidadPago === 'Crédito' && detalle.length > 0) {
                var rows = detalle.map(function (d) {
                    return '<tr><td>' + escaparHtml(d.NombreProducto) + '</td>' +
                           '<td class="text-center">' + d.Cantidad + '</td>' +
                           '<td class="text-right">Gs. ' + formatGs(d.PrecioUnitario) + '</td>' +
                           '<td class="text-right">Gs. ' + formatGs(d.TotalLinea) + '</td></tr>';
                }).join('');

                var html = '<div class="alert alert-warning py-2 mb-2">' +
                    '<i class="fas fa-undo-alt mr-1"></i> <strong>NC de Cuotas</strong> — ' +
                    'Al aprobar, las cuotas se recalcularán descontando el monto de esta NC.</div>' +
                    '<table class="table table-sm table-bordered mb-0"><thead><tr>' +
                    '<th>Producto</th><th class="text-center">Cant.</th>' +
                    '<th class="text-right">Precio</th><th class="text-right">Subtotal</th>' +
                    '</tr></thead><tbody>' + rows + '</tbody></table>';
                $('#divInfoSaldoFavor').html(html);
            } else {
                var saldoNuevo = (saldoActual || 0) + monto;
                var infoSaldo = '<div class="alert alert-info mt-2 mb-0 py-2">' +
                    '<i class="fas fa-wallet mr-1"></i> ' +
                    '<strong>' + escaparHtml(cliente) + '</strong> recibirá <strong>Gs. ' + formatGs(monto) + '</strong> como saldo a favor.' +
                    (saldoActual > 0
                        ? ' Saldo actual: Gs. ' + formatGs(saldoActual) + ' → nuevo total: <strong>Gs. ' + formatGs(saldoNuevo) + '</strong>.'
                        : '') +
                    '<br><small class="text-muted">Se aplicará automáticamente en la próxima venta.</small>' +
                    '</div>';
                $('#divInfoSaldoFavor').html(infoSaldo);
            }
        }).fail(function () {
            $('#divInfoSaldoFavor').html('<div class="alert alert-warning">No se pudo cargar el detalle.</div>');
        });
    } else {
        $('#divInfoSaldoFavor').addClass('d-none').html('');
        $('#divMotivoRechazo').removeClass('d-none');
        $('#modalAprobacionHeader').removeClass('bg-success').addClass('bg-danger');
        $('#lblTituloAprobacion').html('<i class="fas fa-times mr-1"></i> Rechazar Nota de Crédito');
        $('#btnConfirmarAprobacion').removeClass('btn-success').addClass('btn-danger');
    }
    $('#modalAprobacion').modal('show');
}

function confirmarAprobacion() {
    var accion = $('#hdnAccionNCV').val();
    var motivo = $('#txtMotivoRechazo').val().trim();
    if (accion === 'Rechazar' && !motivo) { toastr.warning('Ingrese el motivo del rechazo.'); return; }

    $.ajax({
        url: $.MisUrls.url._NCV_AprobarRechazar,
        method: 'POST',
        data: { idNCVenta: $('#hdnIdNCV').val(), accion: accion, motivoRechazo: motivo },
        success: function (r) {
            if (r.resultado) {
                toastr.success('Nota de crédito ' + accion.toLowerCase() + 'da correctamente.');
                $('#modalAprobacion').modal('hide');
                buscarNCV();
            } else {
                toastr.error(r.mensaje || 'Error al procesar.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFecha(d) { return ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear(); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
function escaparHtml(s) {
    return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
