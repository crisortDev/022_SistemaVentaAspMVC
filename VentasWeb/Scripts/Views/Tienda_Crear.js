var tabladata;
$(document).ready(function () {
    activarMenu("Ventas");


    ////validamos el formulario
    $("#form").validate({
        rules: {
            RUC: "required",
            RazonSocial: "required",
            Telefono: "required",
            Direccion: "required"
        },
        messages: {
            RUC: "(*)",
            RazonSocial: "(*)",
            Telefono: "(*)",
            Direccion: "(*)"

        },
        errorElement: 'span'
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