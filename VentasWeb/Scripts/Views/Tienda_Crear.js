var tabladata;
$(document).ready(function () {
    activarMenu("Ventas");

    // Método personalizado: RUC (números y guion, ej. 80012345-6)
    $.validator.addMethod("rucValido", function (value, element) {
        return this.optional(element) || /^[\d\-]+$/.test(value);
    }, "El RUC solo puede contener números y guiones.");

    // Método personalizado: teléfono (números, espacios, guiones, paréntesis, +)
    $.validator.addMethod("telefonoValido", function (value, element) {
        return this.optional(element) || /^[\d\s\-\+\(\)]+$/.test(value);
    }, "Solo se permiten números, espacios, guiones y paréntesis.");

    ////validamos el formulario
    $("#form").validate({
        rules: {
            RazonSocial: { required: true, minlength: 3, maxlength: 150 },
            RUC:         { required: true, rucValido: true, minlength: 5, maxlength: 20 },
            Direccion:   { required: true, minlength: 5, maxlength: 200 },
            Telefono:    { required: true, telefonoValido: true, minlength: 6, maxlength: 20 }
        },
        messages: {
            RazonSocial: {
                required: "El nombre de la tienda es obligatorio.",
                minlength: "Debe tener al menos 3 caracteres.",
                maxlength: "No puede superar los 150 caracteres."
            },
            RUC: {
                required: "El RUC es obligatorio.",
                rucValido: "Solo se permiten números y guiones (Ej: 80012345-6).",
                minlength: "El RUC debe tener al menos 5 caracteres.",
                maxlength: "No puede superar los 20 caracteres."
            },
            Direccion: {
                required: "La dirección es obligatoria.",
                minlength: "Debe tener al menos 5 caracteres.",
                maxlength: "No puede superar los 200 caracteres."
            },
            Telefono: {
                required: "El teléfono es obligatorio.",
                telefonoValido: "Formato inválido. Solo números, guiones o paréntesis.",
                minlength: "Debe tener al menos 6 dígitos.",
                maxlength: "No puede superar los 20 caracteres."
            }
        },
        errorElement: 'span',
        errorClass: 'text-danger small',
        highlight: function (element) { $(element).addClass('is-invalid'); },
        unhighlight: function (element) { $(element).removeClass('is-invalid'); }
    });


    tabladata = $('#tbTienda').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerTiendas,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "Nombre" },
            { "data": "RUC" },
            { "data": "Direccion" },
            { "data": "Telefono" },
            {
                "data": "Activo", "render": function (data) {
                    if (data) {
                        return '<span class="badge badge-success">Activo</span>'
                    } else {
                        return '<span class="badge badge-danger">No Activo</span>'
                    }
                }
            },
            {
                "data": "IdTienda", "render": function (data, type, row, meta) {
                    var soloLectura = $('#hdnSoloLectura').val() === '1';
                    var btns = "<button class='btn btn-info btn-sm mr-1' type='button' onclick='verTienda(" + JSON.stringify(row) + ")' title='Ver detalle'><i class='fa fa-eye'></i></button>";
                    if (!soloLectura) {
                        btns += "<button class='btn btn-primary btn-sm mr-1' type='button' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                                "<button class='btn btn-danger btn-sm' type='button' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                    }
                    return btns;
                },
                "orderable": false,
                "searchable": false,
                "width": "130px"
            }

        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });


})


// ── Ver detalle (solo lectura) ────────────────────────────
function verTienda(json) {
    $("#verId").text(json.IdTienda);
    $("#verNombre").text(json.Nombre);
    $("#verRuc").text(json.RUC);
    $("#verDireccion").text(json.Direccion);
    $("#verTelefono").text(json.Telefono);
    $("#verEstado").html(json.Activo
        ? '<span class="badge badge-success">Activo</span>'
        : '<span class="badge badge-danger">No Activo</span>');
    $('#VerModal').modal('show');
}

function abrirPopUpForm(json) {

    $("#txtid").val(0);
    $("#form").validate().resetForm();
    $("#form .is-invalid").removeClass("is-invalid");

    if (json != null) {

        $("#txtid").val(json.IdTienda);

        $("#txtNombre").val(json.Nombre);
        $("#txtRuc").val(json.RUC);
        $("#txtDireccion").val(json.Direccion);
        $("#txtTelefono").val(json.Telefono);
        $("#cboEstado").val(json.Activo == true ? 1 : 0);

    } else {
        $("#txtNombre").val("");
        $("#txtRuc").val("");
        $("#txtTelefono").val("");
        $("#txtDireccion").val("");
        $("#cboEstado").val(1);
    }

    $('#FormModal').modal('show');

}


function Guardar() {

    if ($("#form").valid()) {

        var request = {
            objeto: {
                IdTienda: parseInt($("#txtid").val()),
                Nombre: $("#txtNombre").val(),
                RUC: $("#txtRuc").val(),
                Direccion: $("#txtDireccion").val(),
                Telefono: $("#txtTelefono").val(),
                Activo: ($("#cboEstado").val() == "1" ? true : false)
            }
        }

        jQuery.ajax({
            url: $.MisUrls.url._GuardarTienda,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {

                if (data.resultado) {
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                } else {

                    swal("Mensaje", data.mensaje || "No se pudo guardar los cambios", "warning")
                }
            },
            error: function (error) {
                console.log(error)
            },
            beforeSend: function () {

            },
        });

    }

}


function eliminar($id) {


    swal({
        title: "Mensaje",
        text: "¿Desea eliminar la tienda seleccionada?",
        type: "warning",
        showCancelButton: true,

        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",

        cancelButtonText: "No",

        closeOnConfirm: true
    },

        function () {
            jQuery.ajax({
                url: $.MisUrls.url._EliminarTienda + "?id=" + $id,
                type: "GET",
                dataType: "json",
                contentType: "application/json; charset=utf-8",
                success: function (data) {

                    if (data.resultado) {
                        tabladata.ajax.reload();
                    } else {
                        swal("Mensaje", data.mensaje || "No se pudo eliminar la tienda", "warning")
                    }
                },
                error: function (error) {
                    console.log(error)
                },
                beforeSend: function () {

                },
            });
        });

}