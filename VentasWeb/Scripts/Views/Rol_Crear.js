var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ================== VALIDACIONES ==================
    $("#form").validate({
        rules: {
            Descripcion: {
                required: true,
                minlength: 2,
                maxlength: 50
            },
            Activo: {
                required: true
            }
        },
        messages: {
            Descripcion: {
                required: "Ingrese la descripción",
                minlength: "Mínimo 2 caracteres",
                maxlength: "Máximo 50 caracteres"
            },
            Activo: {
                required: "Seleccione un estado"
            }
        },
        errorElement: 'span',
        errorPlacement: function (error, element) {
            error.addClass("text-danger ml-2");
            error.insertAfter(element);
        }
    });

    // ================== DATATABLE ==================
    tabladata = $('#tbdata').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerRoles + "?v=" + new Date().getTime(), // Anti-cache
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "Descripcion" },
            {
                "data": "Activo",
                "render": function (data) {
                    return data ? '<span class="badge badge-success">Activo</span>' :
                        '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                "data": "IdRol",
                "render": function (data, type, row) {
                    var btnEditar = "<button class='btn btn-primary btn-sm' type='button' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>";
                    var btnDesactivar = "<button class='btn btn-warning btn-sm ml-2' type='button' onclick='desactivar(" + data + ")'><i class='fas fa-ban'></i></button>";
                    return btnEditar + btnDesactivar;
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });
});

// ================== FUNCIONES ==================
function abrirPopUpForm(json) {
    $("#txtid").val(0);

    if (json != null) {
        $("#txtid").val(json.IdRol);
        $("#txtDescripcion").val(json.Descripcion);
        $("#cboEstado").val(json.Activo ? 1 : 0);
    } else {
        $("#txtDescripcion").val("");
        $("#cboEstado").val(1);
    }

    $('#FormModal').modal('show');
}

function Guardar() {
    if ($("#form").valid()) {
        var request = {
            objeto: {
                IdRol: $("#txtid").val(),
                Descripcion: $("#txtDescripcion").val(),
                Activo: $("#cboEstado").val() == "1"
            }
        };

        $.ajax({
            url: $.MisUrls.url._GuardarRol,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload(null, false);
                    $('#FormModal').modal('hide');
                    swal("Éxito", "Rol guardado correctamente", "success");
                } else {
                    swal("Atención", data.mensaje || "No se pudo guardar el rol", "warning");
                }
            },
            error: function (error) { console.log(error); }
        });
    }
}

function desactivar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea desactivar el rol seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Sí",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No",
        closeOnConfirm: true
    }, function () {
        $.ajax({
            url: $.MisUrls.url._DesactivarRol + "?id=" + id,
            type: "POST",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload(null, false);
                    swal("Éxito", data.mensaje || "Rol desactivado correctamente", "success");
                } else {
                    swal("Atención", data.mensaje || "No se pudo desactivar el rol", "warning");
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
            });
        } else {
            a = $(li).find("a.nav-link");
            if ($(a).attr("name") == menuactivo) {
                $(li).addClass("active");
                return false;
            }
        }
    });
}
