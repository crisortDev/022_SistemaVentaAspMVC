var tabladata;

$(document).ready(function () {
    activarMenu("Clientes");

    // Validación del formulario
    $("#form").validate({
        rules: {
            numerodocumento: "required",
            nombres: "required",
            direccion: "required",
            telefono: "required"
        },
        messages: {
            numerodocumento: "(*)",
            nombres: "(*)",
            direccion: "(*)",
            telefono: "(*)"
        },
        errorElement: 'span'
    });

    // Inicializar DataTable con scroll horizontal y vertical
    tabladata = $('#tbdata').DataTable({
        ajax: {
            url: $.MisUrls.url._ObtenerClientes,
            type: "GET",
            datatype: "json"
        },
        columns: [
            { data: "TipoDocumento" },
            { data: "NumeroDocumento" },
            { data: "Nombre" },
            { data: "Direccion" },
            { data: "Telefono" },
            { data: "Ciudad" },
            { data: "Barrio" },
            { data: "Calle" },
            { data: "NumeroCasa" },
            { data: "Referencia" },
            {
                data: "Activo",
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                data: "IdCliente",
                render: function (data, type, row) {
                    return "<button class='btn btn-primary btn-sm' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                        "<button class='btn btn-danger btn-sm ml-2' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                },
                orderable: false,
                searchable: false,
                width: "90px"
            }
        ],
        language: {
            url: $.MisUrls.url.Url_datatable_spanish
        },
        // Eliminar responsive para evitar el control +
        // responsive: true,  <-- QUITAR

        scrollX: true,        // Habilitar scroll horizontal
        scrollY: "400px",     // Opcional scroll vertical
        scrollCollapse: true,
        paging: true,
    });

});

function abrirPopUpForm(json) {
    $("#txtid").val(0);

    if (json != null) {
        $("#txtid").val(json.IdCliente);
        $("#cboclientetipodocumento").val(json.TipoDocumento);
        $("#txtNumeroDocumento").val(json.NumeroDocumento);
        $("#txtNombres").val(json.Nombre);
        $("#txtDireccion").val(json.Direccion);
        $("#txtTelefono").val(json.Telefono);
        $("#txtCiudad").val(json.Ciudad);
        $("#txtBarrio").val(json.Barrio);
        $("#txtCalle").val(json.Calle);
        $("#txtNumeroCasa").val(json.NumeroCasa);
        $("#txtReferencia").val(json.Referencia);
        $("#cboEstado").val(json.Activo ? 1 : 0);
    } else {
        $("#form")[0].reset();
        $("#cboEstado").val(1);
    }
    $('#FormModal').modal('show');
}

function Guardar() {
    if (!$("#form").valid()) return;

    var request = {
        objeto: {
            IdCliente: $("#txtid").val(),
            TipoDocumento: $("#cboclientetipodocumento").val(),
            NumeroDocumento: $("#txtNumeroDocumento").val(),
            Nombre: $("#txtNombres").val(),
            Direccion: $("#txtDireccion").val(),
            Telefono: $("#txtTelefono").val(),
            Ciudad: $("#txtCiudad").val(),
            Barrio: $("#txtBarrio").val(),
            Calle: $("#txtCalle").val(),
            NumeroCasa: $("#txtNumeroCasa").val(),
            Referencia: $("#txtReferencia").val(),
            Activo: $("#cboEstado").val() == "1"
        }
    };


    $.ajax({
        url: $.MisUrls.url._GuardarCliente,
        type: "POST",
        data: JSON.stringify(request),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                $('#FormModal').modal('hide');
            } else {
                swal("Mensaje", "No se pudo guardar los cambios", "warning");
            }
        },
        error: function (err) {
            console.log("ERROR:", err);
        }
    });
}

function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el cliente seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No"
    }, function () {
        $.ajax({
            url: $.MisUrls.url._EliminarCliente + "?id=" + id,
            type: "GET",
            dataType: "json",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                } else {
                    swal("Mensaje", "No se pudo eliminar el cliente", "warning");
                }
            },
            error: function (err) {
                console.log("ERROR:", err);
            }
        });
    });
}
