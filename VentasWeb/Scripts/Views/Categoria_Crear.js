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
            }
        },
        messages: {
            Descripcion: {
                required: "Ingrese descripción",
                minlength: "Mínimo 2 caracteres",
                maxlength: "Máximo 50 caracteres"
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
            "url": $.MisUrls.url._ObtenerCategorias,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "Descripcion" },
            {
                "data": "Activo", render: function (data) {
                    return data ? '<span class="badge badge-success">Activo</span>' : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                "data": "IdCategoria", render: function (data, type, row, meta) {
                    return "<button class='btn btn-primary btn-sm' type='button' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                        "<button class='btn btn-danger btn-sm ml-2' type='button' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
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
        $("#txtid").val(json.IdCategoria);
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
                IdCategoria: parseInt($("#txtid").val()),
                Descripcion: $("#txtDescripcion").val(),
                Activo: $("#cboEstado").val() == "1"
            }
        };

        $.ajax({
            url: $.MisUrls.url._GuardarCategoria,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                    swal("Éxito", "Categoría guardada correctamente", "success");
                } else {
                    swal("Atención", "No se pudo guardar los cambios", "warning");
                }
            },
            error: function (error) { console.log(error); }
        });
    }
}

function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar la categoría seleccionada?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No",
        closeOnConfirm: true
    }, function () {
        $.ajax({
            url: $.MisUrls.url._EliminarCategoria + "?id=" + id,
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    swal("Éxito", "Categoría eliminada correctamente", "success");
                } else {
                    swal("Atención", "No se pudo eliminar la categoría porque ya está asignada a un producto", "warning");
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
