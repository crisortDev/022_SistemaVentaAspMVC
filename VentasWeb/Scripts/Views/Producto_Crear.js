var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    $("#form").validate({
        rules: {
            Nombre: "required",
            Descripcion: "required"
        },
        messages: {
            Nombre: "Este campo es obligatorio",
            Descripcion: "Este campo es obligatorio"
        },
        errorElement: 'span',
        errorClass: 'text-danger',
        errorPlacement: function (error, element) {
            error.addClass('invalid-feedback');
            element.closest('.form-group').append(error);
        },
        highlight: function (element) { $(element).addClass('is-invalid'); },
        unhighlight: function (element) { $(element).removeClass('is-invalid'); }
    });

    cargarCategorias();
    inicializarDataTable();
});

function cargarCategorias() {
    showLoading();
    $.ajax({
        url: $.MisUrls.url._ObtenerCategorias,
        type: "GET",
        dataType: "json",
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
        error: function () {
            Swal.fire("Error","No se pudieron cargar las categorías", "error");
            hideLoading();
        }
    });
}

function inicializarDataTable() {
    tabladata = $('#tbdata').DataTable({
        ajax: {
            // CAMBIO: trae activos e inactivos para ver y poder reactivar
            url: $.MisUrls.url._ObtenerProductos,
            type: "GET",
            beforeSend: function () { showLoading(); },
            complete: function () { hideLoading(); },
            error: function () { Swal.fire("Error","No se pudieron cargar los productos", "error"); }
        },
        columns: [
            { data: "Codigo" },
            { data: "Nombre" },
            { data: "Descripcion" },
            {
                data: "oCategoria",
                render: function (data) { return data ? data.Descripcion : "Sin categoría"; }
            },
            {
                data: "Activo",
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: null,
                orderable: false,
                searchable: false,
                width: "200px",
                render: function (data, type, row) {
                    var rowData = htmlEscape(JSON.stringify(row));

                    var btnVer = '<button class="btn btn-info btn-sm mr-1" ' +
                        'onclick="verProducto(\'' + rowData + '\')" title="Ver detalle">' +
                        '<i class="fa fa-eye"></i></button>';

                    var btnEditar = '<button class="btn btn-primary btn-sm mr-1" ' +
                        'onclick="abrirPopUpForm(\'' + rowData + '\')">' +
                        '<i class="fas fa-edit"></i> Editar</button>';

                    // CAMBIO: botón dinámico — desactivar si está activo, reactivar si está inactivo
                    var btnEstado;
                    if (row.Activo) {
                        btnEstado = '<button class="btn btn-danger btn-sm" ' +
                            'onclick="cambiarEstado(' + row.IdProducto + ', false)" title="Desactivar">' +
                            '<i class="fa fa-ban"></i> Desactivar</button>';
                    } else {
                        btnEstado = '<button class="btn btn-success btn-sm" ' +
                            'onclick="cambiarEstado(' + row.IdProducto + ', true)" title="Reactivar">' +
                            '<i class="fa fa-check"></i> Reactivar</button>';
                    }

                    return '<div class="btn-group">' + btnVer + btnEditar + btnEstado + '</div>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true,
        initComplete: function () { hideLoading(); }
    });
}

function htmlEscape(str) {
    return str
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function verProducto(jsonString) {
    try {
        var json = JSON.parse(jsonString.replace(/&#39;/g, '"'));
        $("#verCodigo").text(json.Codigo || '—');
        $("#verNombre").text(json.Nombre || '—');
        $("#verDescripcion").text(json.Descripcion || '—');
        $("#verCategoria").text((json.oCategoria && json.oCategoria.Descripcion) ? json.oCategoria.Descripcion : 'Sin categoría');
        $("#verEstado").html(json.Activo
            ? '<span class="badge badge-success">Activo</span>'
            : '<span class="badge badge-danger">Inactivo</span>');
        $('#VerModal').modal('show');
    } catch (e) {
        Swal.fire("Error","No se pudo cargar el detalle", "error");
    }
}

function abrirPopUpForm(jsonString) {
    try {
        var json = jsonString
            ? JSON.parse(jsonString.replace(/&#39;/g, '"'))
            : null;

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
        }

        $("#form").validate().resetForm();
        $(".form-control").removeClass("is-invalid");
        $('#FormModal').modal('show');
    } catch (e) {
        Swal.fire("Error","No se pudo cargar el formulario", "error");
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
                IdCategoria: parseInt($("#cboCategoria").val()) || 0,
                Activo: $("#cboEstado").val() === "1"
                // CAMBIO: PrecioVenta eliminado del formulario
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
                    Swal.fire("Éxito", "Producto guardado correctamente", "success");
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                } else {
                    Swal.fire("Error",data.mensaje || "No se pudo guardar el producto", "error");
                }
                hideLoading();
            },
            error: function () {
                Swal.fire("Error","Ocurrió un error al guardar", "error");
                hideLoading();
            }
        });
    }
}

// CAMBIO: reemplaza desactivarProducto() — ahora maneja desactivar Y reactivar
function cambiarEstado(id, activar) {
    var accion = activar ? 'reactivar' : 'desactivar';
    var textoConfirm = activar ? 'Sí, reactivar' : 'Sí, desactivar';

    Swal.fire({
        title: '¿' + accion.charAt(0).toUpperCase() + accion.slice(1) + ' producto?',
        text: activar
            ? 'El producto volverá a estar disponible.'
            : 'El producto quedará inactivo pero podrá reactivarse.',
        icon: activar ? 'question' : 'warning',
        showCancelButton: true,
        confirmButtonText: textoConfirm,
        cancelButtonText: 'Cancelar',
        confirmButtonColor: activar ? '#28a745' : '#d33'
    }).then(function (result) {
        if (result.isConfirmed) {
            showLoading();
            $.ajax({
                url: $.MisUrls.url._CambiarEstadoProducto,
                type: "POST",
                data: { id: id, activo: activar },
                success: function (data) {
                    if (data.resultado) {
                        Swal.fire('Listo', data.mensaje, 'success');
                        tabladata.ajax.reload(null, false);
                    } else {
                        Swal.fire('Atención', data.mensaje || 'No se pudo cambiar el estado.', 'warning');
                    }
                    hideLoading();
                },
                error: function () {
                    Swal.fire('Error', 'Ocurrió un error al cambiar el estado.', 'error');
                    hideLoading();
                }
            });
        }
    });
}

// ── Auxiliares ────────────────────────────────────────────
function showLoading() {
    $('body').LoadingOverlay("show", { background: "rgba(0,0,0,0.5)", imageColor: "#1cc88a" });
}

function hideLoading() {
    $('body').LoadingOverlay("hide");
}