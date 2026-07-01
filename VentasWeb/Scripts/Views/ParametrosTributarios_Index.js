// ParametrosTributarios_Index.js
'use strict';

$(function () {
    // Preview en tiempo real del próximo número de factura
    $('#txtEstablecimiento, #txtPuntoExpedicion').on('input', actualizarPreview);

    // Guardar valor original del timbrado para detectar cambios (advertencia de reinicio de secuencia)
    $('#txtNumeroTimbrado').data('original', $('#txtNumeroTimbrado').val());

    if ($('#formParamTrib').length) {
        $.validator.addMethod('soloDigitos3', function (value, element) {
            return this.optional(element) || /^\d{3}$/.test(value.trim());
        }, 'Debe tener exactamente 3 dígitos numéricos.');

        $.validator.addMethod('soloDigitosTimbrado', function (value, element) {
            return this.optional(element) || /^\d+$/.test(value.trim());
        }, 'El número de timbrado solo puede contener dígitos.');

        $('#formParamTrib').validate({
            rules: {
                RazonSocial:      { required: true, minlength: 3, maxlength: 200 },
                NumeroTimbrado:   { required: true, soloDigitosTimbrado: true, minlength: 6, maxlength: 20 },
                Vencimiento:      { required: true },
                Establecimiento:  { required: true, soloDigitos3: true },
                PuntoExpedicion:  { required: true, soloDigitos3: true }
            },
            messages: {
                RazonSocial:     { required: "La razón social es obligatoria.", minlength: "Mínimo 3 caracteres." },
                NumeroTimbrado:  { required: "El número de timbrado es obligatorio.", minlength: "Debe tener al menos 6 dígitos." },
                Vencimiento:     { required: "La fecha de vencimiento es obligatoria." },
                Establecimiento: { required: "El establecimiento es obligatorio." },
                PuntoExpedicion: { required: "El punto de expedición es obligatorio." }
            },
            errorElement: 'small',
            errorClass: 'text-danger d-block',
            highlight: function (element) { $(element).addClass('is-invalid'); },
            unhighlight: function (element) { $(element).removeClass('is-invalid'); }
        });
    }
});

function actualizarPreview() {
    var estab = $('#txtEstablecimiento').val().padStart(3, '0').substring(0, 3);
    var punto = $('#txtPuntoExpedicion').val().padStart(3, '0').substring(0, 3);
    // La secuencia viene del servidor; aquí solo mostramos el formato
    $('#lblPreviewFactura').text(estab + '-' + punto + '-0000XXX');
}

function guardarConfiguracion() {
    if ($('#formParamTrib').length && !$('#formParamTrib').valid()) return;

    var timbrado    = $('#txtNumeroTimbrado').val().trim();
    var vencimiento = $('#txtVencimiento').val().trim();
    var estab       = $('#txtEstablecimiento').val().trim();
    var punto       = $('#txtPuntoExpedicion').val().trim();
    var razon       = $('#txtRazonSocial').val().trim();

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
