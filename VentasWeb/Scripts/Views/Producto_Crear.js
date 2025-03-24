var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // Validación del formulario mejorada
    $("#form").validate({
        rules: {
            Nombre: "required",
            Descripcion: "required",
            PrecioVenta: {
                required: true,
                number: true,
                min: 0
            }
        },
        messages: {
            Nombre: "Este campo es obligatorio",
            Descripcion: "Este campo es obligatorio",
            PrecioVenta: {
                required: "Este campo es obligatorio",
                number: "Debe ser un número válido",
                min: "El valor mínimo es 0"
            }
        },
        errorElement: 'span',
        errorClass: 'text-danger',
        errorPlacement: function (error, element) {
            error.addClass('invalid-feedback');
            element.closest('.form-group').append(error);
        },
        highlight: function (element, errorClass, validClass) {
            $(element).addClass('is-invalid');
        },
        unhighlight: function (element, errorClass, validClass) {
            $(element).removeClass('is-invalid');
        }
    });

    // Obtener categorías
    cargarCategorias();

    // Configuración de DataTable
    inicializarDataTable();
});

function cargarCategorias() {
    showLoading();
    $.ajax({
        url: $.MisUrls.url._ObtenerCategorias,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            $("#cboCategoria").html("");
            if (data.data != null) {
                $.each(data.data, function (i, item) {
                    if (item.Activo) {
                        $("<option>").attr({ "value": item.IdCategoria }).text(item.Descripcion).appendTo("#cboCategoria");
                    }
                });
            }
            hideLoading();
        },
        error: function (error) {
            console.error("Error al cargar categorías:", error);
            swal("Error", "No se pudieron cargar las categorías", "error");
            hideLoading();
        }
    });
}

function inicializarDataTable() {
    tabladata = $('#tbdata').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductos,
            "type": "GET",
            "datatype": "json",
            "beforeSend": function () {
                showLoading();
            },
            "complete": function () {
                hideLoading();
            },
            "error": function (xhr, error, thrown) {
                console.error("Error al cargar productos:", error);
                swal("Error", "No se pudieron cargar los productos", "error");
            }
        },
        "columns": [
            { "data": "Codigo" },
            { "data": "Nombre" },
            { "data": "Descripcion" },
            {
                "data": "oCategoria",
                "render": function (data) {
                    return data ? data.Descripcion : "Sin categoría";
                }
            },
            {
                "data": "Activo",
                "render": function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                "data": null,
                "render": function (data, type, row) {
                    // Escapar comillas para evitar problemas con el JSON
                    var rowData = htmlEscape(JSON.stringify(row));
                    return '<div class="btn-group">' +
                        '<button class="btn btn-primary btn-sm" onclick="abrirPopUpForm(\'' + rowData + '\')">' +
                        '<i class="fas fa-edit"></i> Editar' +
                        '</button>' +
                        '<button class="btn btn-danger btn-sm ml-2" onclick="eliminar(' + row.IdProducto + ')">' +
                        '<i class="fa fa-trash"></i> Eliminar' +
                        '</button>' +
                        '</div>';
                },
                "orderable": false,
                "searchable": false,
                "width": "150px"
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        "responsive": true,
        "initComplete": function () {
            hideLoading();
        }
    });
}

function htmlEscape(str) {
    return str.replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function abrirPopUpForm(jsonString) {
    try {
        // Convertir el string JSON a objeto
        var json = jsonString ? JSON.parse(jsonString.replace(/&#39;/g, '"')) : null;

        // Resetear formulario
        $("#form")[0].reset();
        $("#txtid").val(0);
        $("#txtCodigo").val("AUTOGENERADO").prop("disabled", true);

        if (json) {
            $("#txtid").val(json.IdProducto);
            $("#txtCodigo").val(json.Codigo);
            $("#txtNombre").val(json.Nombre);
            $("#txtDescripcion").val(json.Descripcion);
            $("#cboCategoria").val(json.IdCategoria);
            $("#cboEstado").val(json.Activo ? "1" : "0");
            $("#cboPrecioVenta").val(json.PrecioVenta || 0);
        }

        // Limpiar errores de validación
        $("#form").validate().resetForm();
        $(".form-control").removeClass("is-invalid");

        $('#FormModal').modal('show');
    } catch (e) {
        console.error("Error al abrir formulario:", e);
        swal("Error", "No se pudo cargar el formulario", "error");
    }
}

function Guardar() {
    if ($("#form").valid()) {
        showLoading();

        var request = {
            objeto: {
                IdProducto: parseInt($("#txtid").val()) || 0,
                Nombre: $("#txtNombre").val(),
                Descripcion: $("#txtDescripcion").val(),
                IdCategoria: $("#cboCategoria").val(),
                PrecioVenta: parseFloat($("#cboPrecioVenta").val()) || 0,
                Activo: $("#cboEstado").val() === "1"
            }
        };

        $.ajax({
            url: $.MisUrls.url._GuardarProducto,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    swal("Éxito", "Producto guardado correctamente", "success");
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                } else {
                    swal("Error", "No se pudo guardar el producto", "error");
                }
                hideLoading();
            },
            error: function (error) {
                console.error("Error al guardar:", error);
                swal("Error", "Ocurrió un error al guardar", "error");
                hideLoading();
            }
        });
    }
}

function eliminar(id) {
    console.log("ID recibido para eliminación:", id);  // Agrega esta línea para depuración
    if (!id || isNaN(id) || id <= 0) {
        console.error("ID inválido recibido:", id);
        swal("Error", "El ID del producto no es válido", "error");
        return;
    }

    swal({
        title: "Confirmar eliminación",
        text: "¿Está seguro que desea eliminar este producto? Esta acción no se puede deshacer.",
        icon: "warning",
        buttons: {
            cancel: {
                text: "Cancelar",
                value: null,
                visible: true,
                className: "btn-light"
            },
            confirm: {
                text: "Sí, eliminar",
                value: true,
                className: "btn-danger"
            }
        },
        dangerMode: true
    }).then((confirmed) => {
        if (!confirmed) return;

        showLoading();
        console.log("Iniciando eliminación del producto ID:", id);

        eliminarProducto(id)
            .then(response => {
                console.log("Respuesta del servidor:", response);  // Verifica la respuesta
                if (response.resultado) {
                    swal({
                        title: "¡Eliminado!",
                        text: response.mensaje || "Producto eliminado correctamente",
                        icon: "success",
                        timer: 2000
                    });
                    tabladata.ajax.reload(null, false); // Recarga manteniendo paginación
                } else {
                    swal("Error", response.mensaje || "No se pudo completar la eliminación", "error");
                }
            })
            .catch(error => {
                console.error("Error en la petición:", error);
                swal("Error", "No se pudo eliminar el producto", "error");
            })
            .finally(() => {
                hideLoading();
            });
    });
}


// Función para envolver AJAX en una promesa
function eliminarProducto(id) {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: $.MisUrls.url._EliminarProducto,
            type: "POST",
            data: JSON.stringify({ id: id }),
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            timeout: 10000 // 10 segundos de timeout
        })
            .done(function (response) {
                resolve(response);  // Resolviendo la promesa con la respuesta
            })
            .fail(function (xhr, status, error) {
                reject(error);  // Rechazando la promesa si hay un error
            });
    });
}


// Función para envolver AJAX en una promesa
function eliminarProducto(id) {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: $.MisUrls.url._EliminarProducto,
            type: "POST",
            data: JSON.stringify({ id: id }),
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            timeout: 10000 // 10 segundos de timeout
        })
            .done(function (response) {
                resolve(response);  // Resolviendo la promesa con la respuesta
            })
            .fail(function (xhr, status, error) {
                reject(error);  // Rechazando la promesa si hay un error
            });
    });
}

// Funciones auxiliares
function showLoading() {
    $('body').LoadingOverlay("show", {
        background: "rgba(0, 0, 0, 0.5)",
        imageColor: "#1cc88a"
    });
}

function hideLoading() {
    $('body').LoadingOverlay("hide");
}