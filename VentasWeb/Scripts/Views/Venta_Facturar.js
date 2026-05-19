// Venta_Facturar.js  —  Facturar desde Pre-venta
var dtCliente = null;

$(function () {
    cargarFormasCobro();
    iniciarTablaCliente();
    verificarStockInsuficiente();
});

function cargarFormasCobro() {
    $.get($.MisUrls.url._Venta_FormasCobro, function (r) {
        if (r && r.data) {
            r.data.forEach(function (f) {
                $('#cboFormaCobro').append($('<option>', { value: f.IdFormaCobro, text: f.Nombre }));
            });
        }
    });
}

function verificarStockInsuficiente() {
    // La vista Razor ya marcó las filas en rojo con table-warning
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

function calcularCambio() {
    // El total viene del modelo Razor, lo leemos del tfoot
    var totalText = $('.table-primary td:eq(1)').text().replace(/[^0-9]/g, '');
    var total = parseInt(totalText) || 0;
    var recibido = parseFloat($('#txtImporteRecibido').val()) || 0;
    var cambio = recibido - total;
    $('#txtCambio').val(formatGs(Math.max(0, cambio)));
    if (recibido > 0 && recibido < total) {
        $('#txtCambio').addClass('text-danger').removeClass('text-success');
    } else {
        $('#txtCambio').removeClass('text-danger').addClass('text-success');
    }
}

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
    var recibido = parseFloat($('#txtImporteRecibido').val()) || 0;
    if (recibido <= 0) { toastr.warning('Ingrese el importe recibido.'); return; }

    // Advertir stock insuficiente (no bloquear — el cajero decide)
    if ($('.table-warning').length > 0) {
        Swal.fire({
            icon: 'warning',
            title: 'Stock insuficiente',
            html: 'Uno o más productos no tienen stock suficiente en el sistema.<br><br>¿Querés continuar de todas formas?',
            showCancelButton: true,
            confirmButtonText: 'Sí, facturar igual',
            confirmButtonColor: '#e67e22',
            cancelButtonText: 'Cancelar'
        }).then(function (res) {
            if (res.isConfirmed) enviarFacturacion(idCliente, formaCobro, recibido);
        });
        return;
    }

    enviarFacturacion(idCliente, formaCobro, recibido);
}

function enviarFacturacion(idCliente, formaCobro, recibido) {
    $('#btnFacturar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Facturando...');
    $.ajax({
        url: $.MisUrls.url._Venta_FacturarDesdeOV,
        method: 'POST',
        data: {
            idOrdenVenta:    $('#hdnIdOrdenVenta').val(),
            idCliente:       idCliente,
            idFormaCobro:    formaCobro,
            importeRecibido: recibido
        },
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
