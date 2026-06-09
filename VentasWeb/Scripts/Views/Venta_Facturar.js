// Venta_Facturar.js  —  Facturar desde Pre-venta
var dtCliente = null;

$(function () {
    cargarFormasCobro(function () {
        aplicarLogicaAperturaFondo();
    });
    iniciarTablaCliente();
    verificarStockInsuficiente();
});

// ── Helpers ────────────────────────────────────────────────────────────────
// Redondea al múltiplo de 50 superior (moneda mínima Paraguay = 50 Gs)
function r50(n) { return Math.ceil((n || 0) / 50) * 50; }

function leerTotal() {
    var txt = $('.table-primary td:eq(1)').text().replace(/[^0-9]/g, '');
    return r50(parseInt(txt) || 0);
}

// ── Lógica según monto de apertura de caja ─────────────────────────────────
// Apertura = 0 → el cajero abrió sin efectivo; no puede dar vuelto.
//   • Contado: cobro exacto en efectivo (importe = total, readonly).
//   • Crédito: siempre disponible (no involucra efectivo ahora).
// Apertura > 0 → todas las opciones habilitadas normalmente.
function aplicarLogicaAperturaFondo() {
    var apertura = parseFloat($('#hdnMontoAperturaFondo').val()) || 0;

    if (apertura === 0) {
        // Forzar Efectivo y Contado como punto de partida
        $('#rdoContado').prop('checked', true);
        toggleCondicion();

        $('#cboFormaCobro option').filter(function () {
            return $(this).text().trim().toLowerCase() === 'efectivo';
        }).prop('selected', true);

        var total = leerTotal();
        $('#txtImporteRecibido').val(total).prop('readonly', true);
        $('#txtCambio').val('0');

        $('#divImporte').prepend(
            '<div class="alert alert-info py-1 px-2 mb-2" id="alertaFondoCero" style="font-size:12px;">' +
            '<i class="fas fa-info-circle mr-1"></i>' +
            '<strong>Caja sin fondo inicial</strong> — Contado: cobro exacto (sin vuelto). ' +
            'Podés cambiar a <strong>Crédito</strong> si el cliente paga después.' +
            '</div>'
        );

        // Cuando el cajero cambia la condición, actualizar el bloqueo del importe
        $('input[name="condicion"]').off('change.fondo').on('change.fondo', function () {
            var esCred = $(this).val() === 'Crédito';
            if (esCred) {
                // Crédito: liberar el campo (no se cobra ahora)
                $('#txtImporteRecibido').prop('readonly', false).val(0);
                $('#txtCambio').val('0');
                $('#alertaFondoCero').remove();
            } else {
                // Vuelve a Contado: restaurar monto exacto
                var tot = leerTotal();
                $('#txtImporteRecibido').val(tot).prop('readonly', true);
                $('#txtCambio').val('0');
                if ($('#alertaFondoCero').length === 0) {
                    $('#divImporte').prepend(
                        '<div class="alert alert-info py-1 px-2 mb-2" id="alertaFondoCero" style="font-size:12px;">' +
                        '<i class="fas fa-info-circle mr-1"></i>' +
                        '<strong>Caja sin fondo inicial</strong> — Contado: cobro exacto (sin vuelto). ' +
                        'Podés cambiar a <strong>Crédito</strong> si el cliente paga después.' +
                        '</div>'
                    );
                }
            }
        });
    }
    // Si apertura > 0: todas las opciones habilitadas (comportamiento normal)
}

// ── Formas de cobro ────────────────────────────────────────────────────────
function cargarFormasCobro(callback) {
    $.get($.MisUrls.url._Venta_FormasCobro, function (r) {
        if (r && r.data) {
            r.data.forEach(function (f) {
                $('#cboFormaCobro').append($('<option>', { value: f.IdFormaCobro, text: f.Nombre }));
            });
            $('#cboFormaCobro option').filter(function () {
                return $(this).text().trim().toLowerCase() === 'efectivo';
            }).prop('selected', true);
        }
        if (typeof callback === 'function') callback();
    });
}

function verificarStockInsuficiente() {
    if ($('.table-warning').length > 0) {
        $('#lblStockAlerta').removeClass('d-none');
    }
}

function iniciarTablaCliente() {
    dtCliente = $('#tbCliente').DataTable({
        ajax: { url: $.MisUrls.url._Venta_ObtenerClientes, dataSrc: 'data', type: 'GET' },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    return '<button class="btn btn-primary btn-sm" onclick="seleccionarCliente(' +
                        d.IdCliente + ',\'' + escapar(d.Nombre) + '\')">Elegir</button>';
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

function seleccionarCliente(id, nombre) {
    $('#hdnIdCliente').val(id);
    $('#lblNombreCliente').text(nombre);
    $('#modalCliente').modal('hide');
}

// ── Condición de pago ───────────────────────────────────────────────────────
function toggleCondicion() {
    var esCredito = $('input[name="condicion"]:checked').val() === 'Crédito';
    $('#divPlazo').toggle(esCredito);
    $('#divImporte').toggle(!esCredito);
    $('#divAvisoCredito').toggle(esCredito);
    if (esCredito) {
        $('#txtImporteRecibido').val(0);
        $('#txtCambio').val(0);
    }
}

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

// ── Facturar ────────────────────────────────────────────────────────────────
function facturar() {
    var idCliente  = parseInt($('#hdnIdCliente').val()) || 0;
    var nombreCli  = $('#lblNombreCliente').text().trim();
    var sinCliente = idCliente === 0 && (nombreCli === '' || nombreCli === 'Sin cliente');
    if (sinCliente) {
        toastr.warning('Debe seleccionar un cliente antes de facturar.');
        $('#modalCliente').modal('show');
        return;
    }

    var formaCobro = parseInt($('#cboFormaCobro').val());
    if (!formaCobro) { toastr.warning('Seleccione la forma de cobro.'); return; }

    var condicion = $('input[name="condicion"]:checked').val() || 'Contado';
    var esCredito = condicion === 'Crédito';
    var recibido  = esCredito ? 0 : (parseFloat($('#txtImporteRecibido').val()) || 0);
    var plazo     = esCredito ? parseInt($('#cboPlazo').val()) : null;

    // Solo validar importe si es Contado
    if (!esCredito && recibido <= 0) {
        toastr.warning('Ingrese el importe recibido.');
        return;
    }

    // Advertir stock insuficiente (no bloquear — el cajero decide)
    if ($('.table-warning').length > 0) {
        Swal.fire({
            icon: 'warning',
            title: 'Stock insuficiente',
            html: 'Uno o más productos no tienen stock suficiente.<br><br>¿Querés continuar de todas formas?',
            showCancelButton: true,
            confirmButtonText: 'Sí, facturar igual',
            confirmButtonColor: '#e67e22',
            cancelButtonText: 'Cancelar'
        }).then(function (res) {
            if (res.isConfirmed) enviarFacturacion(idCliente, formaCobro, recibido, condicion, plazo);
        });
        return;
    }

    enviarFacturacion(idCliente, formaCobro, recibido, condicion, plazo);
}

function enviarFacturacion(idCliente, formaCobro, recibido, condicion, plazo) {
    $('#btnFacturar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Facturando...');
    var datos = {
        idOrdenVenta:    $('#hdnIdOrdenVenta').val(),
        idCliente:       idCliente,
        idFormaCobro:    formaCobro,
        importeRecibido: recibido,
        condicion:       condicion || 'Contado'
    };
    if (plazo) datos.plazoCredito = plazo;

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

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
