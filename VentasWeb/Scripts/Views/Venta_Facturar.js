// Venta_Facturar.js  —  Facturar desde Pre-venta
// Modalidades: Efectivo | Transferencia | Crédito (3/6/12/18 cuotas con recargo)
var dtCliente = null;

// Tabla de recargos por cuotas
var RECARGOS = { 3: 5, 6: 10, 12: 20, 18: 35 };

$(function () {
    iniciarTablaCliente();
    verificarStockInsuficiente();
    aplicarLogicaAperturaFondo();
});

// ── Helpers ────────────────────────────────────────────────────────────────
function r50(n) { return Math.ceil((n || 0) / 50) * 50; }

function leerTotal() {
    var txt = $('.table-primary td:eq(1)').text().replace(/[^0-9]/g, '');
    return r50(parseInt(txt) || 0);
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s)  { return (s || '').replace(/'/g, "\\'"); }

// ── Lógica según apertura de caja ─────────────────────────────────────────
function aplicarLogicaAperturaFondo() {
    var apertura = parseFloat($('#hdnMontoAperturaFondo').val()) || 0;
    if (apertura === 0) {
        // Sin fondo: cobro exacto en Efectivo
        $('#rdoEfectivo').prop('checked', true);
        toggleModalidad();
        var total = leerTotal();
        $('#txtImporteRecibido').val(total).prop('readonly', true);
        $('#txtCambio').val('0');
        $('#divImporte').prepend(
            '<div class="alert alert-info py-1 px-2 mb-2" id="alertaFondoCero" style="font-size:12px;">' +
            '<i class="fas fa-info-circle mr-1"></i>' +
            '<strong>Caja sin fondo inicial</strong> — cobro exacto (sin vuelto). ' +
            'Podés usar <strong>Transferencia</strong> o <strong>Crédito</strong> si corresponde.' +
            '</div>'
        );
        $('input[name="modalidadPago"]').off('change.fondo').on('change.fondo', function () {
            var modal = $(this).val();
            if (modal !== 'Efectivo') {
                $('#txtImporteRecibido').prop('readonly', false).val(0);
                $('#alertaFondoCero').remove();
            } else {
                var tot = leerTotal();
                $('#txtImporteRecibido').val(tot).prop('readonly', true);
                $('#txtCambio').val('0');
                if (!$('#alertaFondoCero').length) {
                    $('#divImporte').prepend(
                        '<div class="alert alert-info py-1 px-2 mb-2" id="alertaFondoCero" style="font-size:12px;">' +
                        '<i class="fas fa-info-circle mr-1"></i>' +
                        '<strong>Caja sin fondo inicial</strong> — cobro exacto (sin vuelto).' +
                        '</div>'
                    );
                }
            }
        });
    }
}

// ── Toggle modalidad ───────────────────────────────────────────────────────
function toggleModalidad() {
    var modal = $('input[name="modalidadPago"]:checked').val() || 'Efectivo';
    var esCredito      = modal === 'Crédito';
    var esTransferencia = modal === 'Transferencia';

    $('#divTransferencia').toggle(esTransferencia);
    $('#divCuotas').toggle(esCredito);
    $('#divImporte').toggle(!esCredito);
    $('#divAvisoCredito').toggle(esCredito);

    if (!esTransferencia) $('#txtNumeroTransferencia').val('');
    if (!esCredito) {
        $('#cboCuotas').val('');
        $('#divResumenCuotas').hide();
        $('#txtImporteRecibido').val(0);
        $('#txtCambio').val('0');
    }
    if (esCredito) {
        $('#txtImporteRecibido').val(0);
        $('#txtCambio').val('0');
    }
}

// ── Calculadora de cuotas ──────────────────────────────────────────────────
function calcularCuotas() {
    var cuotas = parseInt($('#cboCuotas').val()) || 0;
    if (!cuotas) { $('#divResumenCuotas').hide(); return; }

    var total    = leerTotal();
    var recargo  = RECARGOS[cuotas] || 0;
    // Monto financiado redondeado a 50 Gs
    var financiado = Math.ceil(total * (1 + recargo / 100) / 50) * 50;
    // Cuota base redondeada hacia abajo a 50 Gs
    var valorCuota = Math.floor(financiado / cuotas / 50) * 50;
    var ultimaCuota = financiado - valorCuota * (cuotas - 1);
    var hayAjuste  = ultimaCuota !== valorCuota;

    $('#lblTotalVenta').text('Gs. ' + formatGs(total));
    $('#lblRecargo').text(recargo + '%  (+Gs. ' + formatGs(financiado - total) + ')');
    $('#lblMontoFinanciado').text('Gs. ' + formatGs(financiado));
    $('#lblValorCuota').text('Gs. ' + formatGs(valorCuota) + ' × ' + (cuotas - (hayAjuste ? 1 : 0)) +
        (hayAjuste ? ' + Gs. ' + formatGs(ultimaCuota) + ' (última)' : ''));
    $('#lblAjusteCuota').toggle(hayAjuste);
    $('#divResumenCuotas').show();
}

// ── Calcular cambio (Efectivo / Transferencia) ─────────────────────────────
function calcularCambio() {
    var total    = leerTotal();
    var recibido = parseFloat($('#txtImporteRecibido').val()) || 0;
    var cambio   = recibido - total;
    $('#txtCambio').val(formatGs(Math.max(0, cambio)));
    if (recibido > 0 && recibido < total) {
        $('#txtCambio').addClass('text-danger').removeClass('text-success');
    } else {
        $('#txtCambio').removeClass('text-danger').addClass('text-success');
    }
}

// ── Tabla y selección de cliente ──────────────────────────────────────────
function iniciarTablaCliente() {
    dtCliente = $('#tbCliente').DataTable({
        ajax: { url: $.MisUrls.url._Venta_ObtenerClientes, dataSrc: 'data', type: 'GET' },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    return '<button class="btn btn-primary btn-sm" onclick="seleccionarCliente(' +
                        d.IdCliente + ',\'' + escapar(d.Nombre) + '\',' + (d.SaldoFavor || 0) + ')">Elegir</button>';
                }
            },
            { data: 'NumeroDocumento' },
            { data: 'Nombre' },
            { data: 'Telefono', defaultContent: '' }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }
    });
}

function cambiarCliente() {
    if (dtCliente) dtCliente.ajax.reload();
    $('#modalCliente').modal('show');
}

function seleccionarCliente(id, nombre, saldoFavor) {
    $('#hdnIdCliente').val(id);
    $('#lblNombreCliente').text(nombre);
    $('#modalCliente').modal('hide');

    // Mostrar saldo a favor si existe
    $('#alertaSaldoFavor').remove();
    if (saldoFavor && saldoFavor > 0) {
        var total = leerTotal();
        var aplicado = Math.min(saldoFavor, total);
        $('#divImporte').prepend(
            '<div class="alert alert-success py-1 px-2 mb-2" id="alertaSaldoFavor" style="font-size:12px;">' +
            '<i class="fas fa-gift mr-1"></i>' +
            '<strong>Saldo a favor: Gs. ' + formatGs(saldoFavor) + '</strong> — ' +
            'Se aplicarán automáticamente Gs. ' + formatGs(aplicado) +
            ' al facturar. Total a cobrar: Gs. ' + formatGs(total - aplicado) + '.' +
            '</div>'
        );
    }
}

function verificarStockInsuficiente() {
    if ($('.table-warning').length > 0) {
        $('#lblStockAlerta').removeClass('d-none');
    }
}

// ── Facturar ───────────────────────────────────────────────────────────────
function facturar() {
    var idCliente  = parseInt($('#hdnIdCliente').val()) || 0;
    var nombreCli  = $('#lblNombreCliente').text().trim();
    var sinCliente = idCliente === 0 && (nombreCli === '' || nombreCli === 'Sin cliente');
    if (sinCliente) {
        toastr.warning('Debe seleccionar un cliente antes de facturar.');
        $('#modalCliente').modal('show');
        return;
    }

    var modal = $('input[name="modalidadPago"]:checked').val() || 'Efectivo';

    // Validaciones por modalidad
    if (modal === 'Transferencia') {
        var nroTransf = $('#txtNumeroTransferencia').val().trim();
        if (!nroTransf) {
            toastr.warning('Debe ingresar el número de transferencia o comprobante.');
            $('#txtNumeroTransferencia').focus();
            return;
        }
    }

    if (modal === 'Crédito') {
        var cuotas = parseInt($('#cboCuotas').val()) || 0;
        if (!cuotas) {
            toastr.warning('Seleccione el plan de financiación (cuotas).');
            return;
        }
    }

    var recibido = (modal !== 'Crédito') ? (parseFloat($('#txtImporteRecibido').val()) || 0) : 0;
    if (modal !== 'Crédito' && recibido <= 0) {
        toastr.warning('Ingrese el importe recibido.');
        return;
    }

    // Advertir stock insuficiente
    if ($('.table-warning').length > 0) {
        Swal.fire({
            icon: 'warning', title: 'Stock insuficiente',
            html: 'Uno o más productos no tienen stock suficiente.<br><br>¿Querés continuar de todas formas?',
            showCancelButton: true,
            confirmButtonText: 'Sí, facturar igual',
            confirmButtonColor: '#e67e22',
            cancelButtonText: 'Cancelar'
        }).then(function (res) {
            if (res.isConfirmed) enviarFacturacion(idCliente, modal, recibido);
        });
        return;
    }

    enviarFacturacion(idCliente, modal, recibido);
}

function enviarFacturacion(idCliente, modal, recibido) {
    $('#btnFacturar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Facturando...');

    var datos = {
        idOrdenVenta:    $('#hdnIdOrdenVenta').val(),
        idCliente:       idCliente,
        modalidadPago:   modal,
        importeRecibido: recibido
    };

    if (modal === 'Transferencia') {
        datos.numeroTransferencia = $('#txtNumeroTransferencia').val().trim();
    }
    if (modal === 'Crédito') {
        datos.numeroCuotas = parseInt($('#cboCuotas').val());
    }

    $.ajax({
        url:    $.MisUrls.url._Venta_FacturarDesdeOV,
        method: 'POST',
        data:   datos,
        success: function (r) {
            if (r.resultado) {
                toastr.success('Factura emitida: ' + r.numeroFactura);
                setTimeout(function () {
                    window.open(r.urlDocumento, '_blank');
                    window.location.href = $.MisUrls.url._OV_Consultar;
                }, 1000);
            } else {
                toastr.error(r.mensaje || 'Error al facturar.');
                $('#btnFacturar').prop('disabled', false).html('<i class="fas fa-file-invoice-dollar"></i> Confirmar y Facturar');
            }
        },
        error: function () {
            toastr.error('Error de conexión.');
            $('#btnFacturar').prop('disabled', false).html('<i class="fas fa-file-invoice-dollar"></i> Confirmar y Facturar');
        }
    });
}
