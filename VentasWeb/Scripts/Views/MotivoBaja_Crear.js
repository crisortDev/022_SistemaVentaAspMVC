var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ── DataTable ─────────────────────────────────────────
    tabladata = $('#tbdata').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: {
            url: '/MotivoBaja/Obtener',
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
                width: '100px',
                render: function (data, type, row) {
                    return '<button class="btn btn-xs btn-primary mr-1" ' +
                        'onclick=\'abrirPopUpForm(' + JSON.stringify(row) + ')\' title="Editar">' +
                        '<i class="fa fa-edit"></i></button>' +
                        '<button class="btn btn-xs btn-danger" ' +
                        'onclick="eliminar(' + data + ')" title="Eliminar">' +
                        '<i class="fa fa-trash"></i></button>';
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

// ── Eliminar ──────────────────────────────────────────────
function eliminar(id) {
    Swal.fire({
        title: '¿Eliminar motivo?',
        text: 'Esta acción no se puede deshacer.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#d33'
    }).then(function (result) {
        if (result.isConfirmed) {
            $.ajax({
                url: '/MotivoBaja/Eliminar?id=' + id,
                type: 'GET',
                success: function (resp) {
                    if (resp.resultado) {
                        tabladata.ajax.reload();
                        Swal.fire('Eliminado', resp.mensaje, 'success');
                    } else {
                        Swal.fire('Atención', resp.mensaje, 'warning');
                    }
                },
                error: function () {
                    Swal.fire('Error', 'Ocurrió un error al eliminar.', 'error');
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