var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ================== VALIDACIONES ==================
    $("#form").validate({
        rules: {
            Nombres: {
                required: true,
                minlength: 2,
                maxlength: 50
            },
            Apellidos: {
                required: true,
                minlength: 2,
                maxlength: 50
            },
            CI: {
                required: true,
                minlength: 1,
                maxlength: 15
            },
            Correo: {
                required: true,
                email: true,
                maxlength: 30
            },
            Clave: {
                required: function () {
                    return $("#txtid").val() == "0"; // obligatorio solo al crear
                },
                minlength: 6,
                maxlength: 8
            }
        },
        messages: {
            Nombres: {
                required: "Ingrese nombres",
                minlength: "Mínimo 2 caracteres",
                maxlength: "Máximo 50 caracteres"
            },
            Apellidos: {
                required: "Ingrese apellidos",
                minlength: "Mínimo 2 caracteres",
                maxlength: "Máximo 50 caracteres"
            },
            CI: {
                required: "Ingrese CI",
                minlength: "Debe tener al menos 1 carácter",
                maxlength: "Máximo 15 caracteres"
            },
            Correo: {
                required: "Ingrese correo",
                email: "Formato de correo inválido",
                maxlength: "Máximo 30 caracteres"
            },
            Clave: {
                required: "Ingrese contraseña",
                minlength: "Mínimo 6 caracteres",
                maxlength: "Máximo 8 caracteres"
            }
        },
        errorElement: 'span',
        errorPlacement: function (error, element) {
            error.addClass("text-danger ml-2");
            error.insertAfter(element);
        }
    });

    // ================== CARGA DE ROLES ==================
    $.ajax({
        url: $.MisUrls.url._ObtenerRoles,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            $("#cboRol").html("");
            if (data.data != null) {
                $.each(data.data, function (i, item) {
                    if (item.Activo === true) {
                        $("<option>").attr({ "value": item.IdRol }).text(item.Descripcion).appendTo("#cboRol");
                    }
                });
                $("#cboRol").val($("#cboRol option:first").val());
            }
        },
        error: function (error) { console.log(error); }
    });

    // ================== CARGA DE TIENDAS ==================
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            $("#cboTienda").html("");
            if (data.data != null) {
                $.each(data.data, function (i, item) {
                    if (item.Activo === true) {
                        $("<option>").attr({ "value": item.IdTienda }).text(item.Nombre).appendTo("#cboTienda");
                    }
                });
                $("#cboTienda").val($("#cboTienda option:first").val());
            }
        },
        error: function (error) { console.log(error); }
    });

    // ================== DATATABLE ==================
    tabladata = $('#tbdata').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerUsuarios,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "oRol", render: function (data) { return data.Descripcion; } },
            { "data": "Nombres" },
            { "data": "Apellidos" },
            { "data": "Correo" },
            {
                "data": "Activo", render: function (data) {
                    return data ? '<span class="badge badge-success">Activo</span>' : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                "data": "IdUsuario", render: function (data, type, row) {
                    return "<button class='btn btn-primary btn-sm' type='button' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                        "<button class='btn btn-danger btn-sm ml-2' type='button' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                }, "orderable": false, "searchable": false, "width": "90px"
            }
        ],
        "language": { "url": $.MisUrls.url.Url_datatable_spanish },
        responsive: true
    });
});

// ================== FUNCIONES ==================
function abrirPopUpForm(json) {
    $("#txtid").val(0);

    if (json != null) {
        // === EDITAR ===
        $("#txtid").val(json.IdUsuario);
        $("#txtNombres").val(json.Nombres);
        $("#txtApellidos").val(json.Apellidos);
        $("#txtCI").val(json.CI).prop("readonly", true); // CI readonly al editar
        $("#txtCorreo").val(json.Correo);
        $("#txtClave").val(json.Clave).prop("disabled", true); // Clave no editable
        $("#cboTienda").val(json.IdTienda);
        $("#cboRol").val(json.IdRol);
        $("#cboEstado").val(json.Activo ? 1 : 0);
    } else {
        // === CREAR ===
        $("#txtNombres").val("");
        $("#txtApellidos").val("");
        $("#txtCI").val("").prop("readonly", false);
        $("#txtCorreo").val("");
        $("#txtClave").val("").prop("disabled", false);
        $("#cboTienda").val($("#cboTienda option:first").val());
        $("#cboRol").val($("#cboRol option:first").val());
        $("#cboEstado").val(1);
    }

    $('#FormModal').modal('show');
}

function Guardar() {
    if ($("#form").valid()) {
        var request = {
            objeto: {
                CI: $("#txtCI").val(),
                Nombres: $("#txtNombres").val(),
                Apellidos: $("#txtApellidos").val(),
                Correo: $("#txtCorreo").val(),
                Clave: $("#txtClave").val(),
                IdTienda: $("#cboTienda").val(),
                IdRol: $("#cboRol").val(),
                Activo: $("#cboEstado").val() == "1"
            }
        };

        $.ajax({
            url: $.MisUrls.url._GuardarUsuario,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                    swal("Éxito", data.mensaje, "success");
                } else {
                    swal("Atención", data.mensaje, "warning");
                }
            },
            error: function (error) { console.log(error); }
        });
    }
}

function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el usuario seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No",
        closeOnConfirm: true
    }, function () {
        $.ajax({
            url: $.MisUrls.url._EliminarUsuario + "?id=" + id,
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                } else {
                    swal("Mensaje", "No se pudo eliminar el usuario", "warning");
                }
            },
            error: function (error) { console.log(error); }
        });
    });
}

// ================== ACTIVAR MENU ==================
function activarMenu(menuactivo) {
    var ul = $("ul.navbar-nav");
    ul.find("li.nav-item").each(function (i, li) {
        var a;
        if ($(li).find("div.dropdown-menu").length != 0) {
            var div = $($(li).find("div.dropdown-menu"));
            div.find("a.dropdown-item").each(function (x, tagA) {
                if ($(tagA).attr("name") == menuactivo) {
                    $(li).addClass("active");
                    return false;
                }
            })
        } else {
            a = $(li).find("a.nav-link");
            if ($(a).attr("name") == menuactivo) {
                $(li).addClass("active");
                return false;
            }
        }
    });
}
