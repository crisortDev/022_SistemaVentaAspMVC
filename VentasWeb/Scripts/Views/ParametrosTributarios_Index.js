// ParametrosTributarios_Index.js
'use strict';

$(function () {
    // Preview en tiempo real del próximo número de factura
    $('#txtEstablecimiento, #txtPuntoExpedicion').on('input', actualizarPreview);
});

function actualizarPreview() {
    var estab = $('#txtEstablecimiento').val().padStart(3, '0').substring(0, 3);
    var punto = $('#txtPuntoExpedicion').val().padStart(3, '0').substring(0, 3);
    // La secuencia viene del servidor; aquí solo mostramos el formato
    $('#lblPreviewFactura').text(estab + '-' + punto + '-0000XXX');
}

function guardarConfiguracion() {
    var timbrado    = $('#txtNumeroTimbrado').val().trim();
    var vencimiento = $('#txtVencimiento').val().trim();
    var estab       = $('#txtEstablecimiento').val().trim();
    var punto       = $('#txtPuntoExpedicion').val().trim();
    var razon       = $('#txtRazonSocial').val().trim();

    if (!timbrado)    { toastr.warning('Ingresá el número de timbrado.'); return; }
    if (!vencimiento) { toastr.warning('Ingresá la fecha de vencimiento.'); return; }
    if (estab.length !== 3 || punto.length !== 3) {
        toastr.warning('Establecimiento y Punto de Expedición deben tener 3 dígitos.');
        return;
    }

    // Advertir si cambia el timbrado (se reinicia secuencia)
    var timbradoOriginal = $('#txtNumeroTimbrado').data('original') || $('#txtNumeroTimbrado').val();
    var cambiaTimbrado   = timbrado !== String($('#txtNumeroTimbrado').data('original') || '');

    var accion = cambiaTimbrado
        ? Swal.fire({
            icon: 'warning',
            title: 'Renovar timbrado',
            html: 'Estás registrando un <strong>nuevo timbrado</strong>.<br>La secuencia de facturas se reiniciará a <strong>0</strong>.<br><br>¿Confirmás?',
            showCancelButton: true,
            confirmButtonText: 'Sí, renovar',
            confirmButtonColor: '#e67e22',
            cancelButtonText: 'Cancelar'
          })
        : Promise.resolve({ isConfirmed: true });

    accion.then(function (res) {
        if (!res.isConfirmed) return;

        $.ajax({
            url:    $.MisUrls.url._ParamTrib_Guardar,
            method: 'POST',
            data: {
                numeroTimbrado:      timbrado,
                vencimientoTimbrado: vencimiento,
                establecimiento:     estab,
                puntoExpedicion:     punto,
                razonSocial:         razon
            },
            success: function (r) {
                if (r.resultado) {
                    toastr.success(r.mensaje);
                    setTimeout(function () { location.reload(); }, 1200);
                } else {
                    toastr.error(r.mensaje);
                }
            },
            error: function () { toastr.error('Error de conexión.'); }
        });
    });
}
