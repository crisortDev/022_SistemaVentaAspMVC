var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ── DataTable ─────────────────────────────────────────
    // CAMBIO: la URL ahora trae todos los registros (activos e inactivos)
    // para poder ver el estado y reactivar si se quiere
    tabladata = $('#tbdata').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: {
            url: '/MotivoBaja/ObtenerTodos', // CAMBIO: nuevo endpoint que trae activos e inactivos
            type: 'GET',
            datatype: 'json'
        },
        order: [[0, 'asc']],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        columns: [
            { data: 'Descripcion', defaultContent: '' },
            {
                data: 'Activo',
                width: '90px',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdMotivoBaja',
                orderable: false,
                searchable: false,
                width: '120px',
                render: function (data, type, row) {
                    var btnEditar = '<button class="btn btn-xs btn-primary mr-1" ' +
                        'onclick=\'abrirPopUpForm(' + JSON.stringify(row) + ')\' title="Editar">' +
                        '<i class="fa fa-edit"></i></button>';

                    // CAMBIO: el botón cambia según el estado actual del registro
                    var btnEstado;
                    if (row.Activo) {
                        // Si está activo → mostrar botón para desactivar (borrado lógico)
                        btnEstado = '<button class="btn btn-xs btn-danger" ' +
                            'onclick="cambiarEstado(' + data + ', false)" title="Desactivar">' +
                            '<i class="fa fa-ban"></i></button>';
                    } else {
                        // Si está inactivo → mostrar botón para reactivar
                        btnEstado = '<button class="btn btn-xs btn-success" ' +
                            'onclick="cambiarEstado(' + data + ', true)" title="Reactivar">' +
                            '<i class="fa fa-check"></i></button>';
                    }

                    return btnEditar + btnEstado;
                }
            }
        ]
    });

    // ── Forzar mayúsculas ─────────────────────────────────
    $('#txtDescripcion').on('input', function () {
        var pos = this.selectionStart;
        $(this).val($(this).val().toUpperCase());
        this.setSelectionRange(pos, pos);
    });
});

// ── Abrir modal ───────────────────────────────────────────
function abrirPopUpForm(json) {
    limpiarErrores();

    if (json != null) {
        $("#tituloModal").html('<i class="fas fa-edit mr-1"></i> Editar Motivo de Baja');
        $("#txtid").val(json.IdMotivoBaja);
        $("#txtDescripcion").val(json.Descripcion);
        $("#cboEstado").val(json.Activo ? 1 : 0);
    } else {
        $("#tituloModal").html('<i class="fas fa-ban mr-1"></i> Nuevo Motivo de Baja');
        $("#txtid").val(0);
        $("#txtDescripcion").val("");
        $("#cboEstado").val(1);
    }

    $('#FormModal').modal('show');
    setTimeout(function () { $('#txtDescripcion').focus(); }, 400);
}

// ── Guardar ───────────────────────────────────────────────
function Guardar() {
    limpiarErrores();

    var desc = $("#txtDescripcion").val().trim();

    if (!desc) {
        marcarError("txtDescripcion", "La descripción es obligatoria.");
        return;
    }
    if (desc.length < 2) {
        marcarError("txtDescripcion", "Mínimo 2 caracteres.");
        return;
    }

    var objeto = {
        IdMotivoBaja: parseInt($("#txtid").val()),
        Descripcion: desc,
        Activo: $("#cboEstado").val() === "1"
    };

    $.ajax({
        url: '/MotivoBaja/Guardar',
        type: 'POST',
        data: JSON.stringify(objeto),
        contentType: 'application/json; charset=utf-8',
        success: function (resp) {
            if (resp.resultado) {
                tabladata.ajax.reload();
                $('#FormModal').modal('hide');
                Swal.fire('Éxito', resp.mensaje, 'success');
            } else {
                Swal.fire('Atención', resp.mensaje, 'warning');
            }
        },
        error: function () {
            Swal.fire('Error', 'Ocurrió un error al guardar.', 'error');
        }
    });
}

// ── CAMBIO: reemplaza la función eliminar() por cambiarEstado() ───────────
// En vez de eliminar, desactiva o reactiva el registro (borrado lógico)
function cambiarEstado(id, activar) {
    var accion = activar ? 'reactivar' : 'desactivar';
    var icono = activar ? 'question' : 'warning';
    var textoConfirm = activar ? 'Sí, reactivar' : 'Sí, desactivar';

    Swal.fire({
        title: '¿' + accion.charAt(0).toUpperCase() + accion.slice(1) + ' motivo?',
        text: activar
            ? 'El motivo volverá a estar disponible.'
            : 'El motivo ya no estará disponible para nuevos movimientos.',
        icon: icono,
        showCancelButton: true,
        confirmButtonText: textoConfirm,
        cancelButtonText: 'Cancelar',
        confirmButtonColor: activar ? '#28a745' : '#d33'
    }).then(function (result) {
        if (result.isConfirmed) {
            $.ajax({
                url: '/MotivoBaja/CambiarEstado?id=' + id + '&activar=' + activar,
                type: 'GET',
                success: function (resp) {
                    if (resp.resultado) {
                        tabladata.ajax.reload();
                        Swal.fire('Listo', resp.mensaje, 'success');
                    } else {
                        Swal.fire('Atención', resp.mensaje, 'warning');
                    }
                },
                error: function () {
                    Swal.fire('Error', 'Ocurrió un error al cambiar el estado.', 'error');
                }
            });
        }
    });
}

// ── Helpers validación visual ─────────────────────────────
function marcarError(idCampo, mensaje) {
    $('#' + idCampo).addClass('is-invalid')
        .closest('.form-group').find('.invalid-feedback').text(mensaje).show();
}

function limpiarErrores() {
    $('#form .form-control').removeClass('is-invalid');
    $('#form .invalid-feedback').text('').hide();
}

// ── Activar menú ──────────────────────────────────────────
function activarMenu(menuactivo) {
    $('ul.navbar-nav li.nav-item').each(function () {
        var $li = $(this);
        if ($li.find('div.dropdown-menu').length) {
            $li.find('a.dropdown-item').each(function () {
                if ($(this).attr('name') === menuactivo) {
                    $li.addClass('active');
                    return false;
                }
            });
        } else {
            if ($li.find('a.nav-link').attr('name') === menuactivo)
                $li.addClass('active');
        }
    });
}