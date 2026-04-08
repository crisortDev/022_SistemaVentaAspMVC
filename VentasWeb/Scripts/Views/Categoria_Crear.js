var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ── DataTable ─────────────────────────────────────────
    tabladata = $('#tbdata').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: {
            url: $.MisUrls.url._ObtenerCategorias,
            type: 'GET',
            datatype: 'json'
        },
        order: [[0, 'asc']],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        columns: [
            { data: 'Descripcion', defaultContent: '' },
            {
                data: 'PorcentajeGanancia',
                width: '110px',
                className: 'text-center',
                render: function (data) {
                    var val = parseFloat(data) || 0;
                    return val > 0
                        ? '<span class="badge badge-success">' + val.toFixed(2) + ' %</span>'
                        : '<span class="badge badge-secondary">Sin margen</span>';
                }
            },
            {
                data: 'Activo',
                width: '90px',
                className: 'text-center',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdCategoria',
                orderable: false,
                searchable: false,
                width: '130px',
                className: 'text-center',
                render: function (data, type, row) {
                    var btnVer = '<button class="btn btn-xs btn-info mr-1" ' +
                        'onclick=\'verCategoria(' + JSON.stringify(row) + ')\' title="Ver detalle">' +
                        '<i class="fa fa-eye"></i></button>';

                    var btnEditar = '<button class="btn btn-xs btn-primary mr-1" ' +
                        'onclick=\'abrirPopUpForm(' + JSON.stringify(row) + ')\' title="Editar">' +
                        '<i class="fa fa-edit"></i></button>';

                    // Usamos data-* para evitar bugs con comillas, tildes y
                    // caracteres especiales en la descripción al generar HTML inline.
                    var btnEstado = row.Activo
                        ? '<button class="btn btn-xs btn-danger btn-estado" ' +
                        'data-id="' + data + '" data-activo="1" title="Desactivar">' +
                        '<i class="fa fa-ban"></i></button>'
                        : '<button class="btn btn-xs btn-success btn-estado" ' +
                        'data-id="' + data + '" data-activo="0" ' +
                        'data-descripcion="' + $('<div>').text(row.Descripcion).html() + '" title="Activar">' +
                        '<i class="fa fa-check"></i></button>';

                    return btnVer + btnEditar + btnEstado;
                }
            }
        ]
    });

    // ── Forzar mayúsculas en descripción ──────────────────
    $('#txtDescripcion').on('input', function () {
        var pos = this.selectionStart;
        $(this).val($(this).val().toUpperCase());
        this.setSelectionRange(pos, pos);
    });

    // ── Solo números positivos en porcentaje ──────────────
    $('#txtPorcentaje').on('input', function () {
        var val = parseFloat($(this).val());
        if (val < 0) $(this).val(0);
        if (val > 999.99) $(this).val(999.99);
    });

    // ── Botones estado (delegado para filas dinámicas de DataTable) ───
    // Se usa delegación en lugar de onclick inline para evitar bugs
    // con caracteres especiales (tildes, comillas, etc.) en Descripcion.
    $('#tbdata').on('click', '.btn-estado', function () {
        var $btn = $(this);
        var id = parseInt($btn.data('id'));
        var activo = $btn.data('activo') === 1 || $btn.data('activo') === '1';
        var desc = $btn.data('descripcion') || '';

        if (activo) {
            desactivar(id);
        } else {
            activar(id, desc);
        }
    });
});

// ── Ver detalle (solo lectura) ────────────────────────────
function verCategoria(json) {
    var porcentaje = parseFloat(json.PorcentajeGanancia) || 0;
    $("#verDescripcion").text(json.Descripcion);
    $("#verPorcentaje").text(porcentaje.toFixed(2));
    $("#verEstado").html(json.Activo
        ? '<span class="badge badge-success">Activo</span>'
        : '<span class="badge badge-danger">Inactivo</span>');

    // Auditoría
    if (json.FechaModificacion) {
        var fecha = new Date(parseInt(json.FechaModificacion.replace('/Date(', '').replace(')/', '')));
        var fechaStr = fecha.toLocaleDateString('es-PY') + ' ' + fecha.toLocaleTimeString('es-PY', { hour: '2-digit', minute: '2-digit' });
        $("#verFechaModificacion").text(fechaStr);
    } else {
        $("#verFechaModificacion").text('—');
    }
    $("#verUsuarioModificacion").text(json.UsuarioModificacion || '—');

    $('#VerModal').modal('show');
}

// ── Abrir modal crear / editar ────────────────────────────
function abrirPopUpForm(json) {
    limpiarErrores();
    var $btnToggle = $('#btnToggleEstado');

    if (json != null) {
        // Modo editar
        $("#tituloModal").html('<i class="fa fa-edit mr-1"></i> Editar Categoría');
        $("#txtid").val(json.IdCategoria);
        $("#txtDescripcion").val(json.Descripcion);
        $("#txtPorcentaje").val(parseFloat(json.PorcentajeGanancia) || 0);
        $("#cboEstado").val(json.Activo ? 1 : 0);

        if (json.Activo) {
            $btnToggle
                .removeClass('d-none btn-success')
                .addClass('btn-danger')
                .html('<i class="fa fa-ban mr-1"></i> Desactivar');
        } else {
            $btnToggle
                .removeClass('d-none btn-danger')
                .addClass('btn-success')
                .html('<i class="fa fa-check mr-1"></i> Activar');
        }
    } else {
        // Modo crear
        $("#tituloModal").html('<i class="fa fa-tag mr-1"></i> Nueva Categoría');
        $("#txtid").val(0);
        $("#txtDescripcion").val('');
        $("#txtPorcentaje").val('');
        $("#cboEstado").val(1);
        $btnToggle.addClass('d-none').removeClass('btn-danger btn-success');
    }

    $('#FormModal').modal('show');
    setTimeout(function () { $('#txtDescripcion').focus(); }, 400);
}

// ── Toggle estado desde el modal editar ───────────────────
function toggleEstadoDesdeModal() {
    var id = parseInt($("#txtid").val());
    var activoActual = $("#cboEstado").val() === "1";
    var nuevaAccion = !activoActual;
    var texto = nuevaAccion ? 'activar' : 'desactivar';

    Swal.fire({
        title: '¿' + texto.charAt(0).toUpperCase() + texto.slice(1) + ' categoría?',
        icon: nuevaAccion ? 'question' : 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, ' + texto,
        cancelButtonText: 'Cancelar',
        confirmButtonColor: nuevaAccion ? '#27ae60' : '#e74c3c'
    }).then(function (result) {
        if (result.isConfirmed) {
            cambiarEstadoCategoria(id, nuevaAccion, function () {
                $('#FormModal').modal('hide');
            });
        }
    });
}

// ── Guardar ───────────────────────────────────────────────
function Guardar() {
    limpiarErrores();

    var desc = $("#txtDescripcion").val().trim();
    var pct = $("#txtPorcentaje").val();
    var pctVal = pct === '' ? 0 : parseFloat(pct);

    if (!desc) {
        marcarError("txtDescripcion", "La descripción es obligatoria.");
        return;
    }
    if (desc.length < 2) {
        marcarError("txtDescripcion", "Mínimo 2 caracteres.");
        return;
    }
    if (isNaN(pctVal) || pctVal < 0 || pctVal > 999.99) {
        marcarError("txtPorcentaje", "Ingrese un valor entre 0 y 999.99.");
        return;
    }

    var objeto = {
        IdCategoria: parseInt($("#txtid").val()),
        Descripcion: desc,
        PorcentajeGanancia: pctVal,
        Activo: $("#cboEstado").val() === "1"
    };

    $.ajax({
        url: $.MisUrls.url._GuardarCategoria,
        type: 'POST',
        data: JSON.stringify(objeto),
        contentType: 'application/json; charset=utf-8',
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                $('#FormModal').modal('hide');
                Swal.fire('Éxito', 'Categoría guardada correctamente.', 'success');
            } else {
                Swal.fire('Atención', data.mensaje || 'No se pudo guardar.', 'warning');
            }
        },
        error: function () {
            Swal.fire('Error', 'Ocurrió un error al guardar.', 'error');
        }
    });
}

// ── Borrado lógico desde columna acciones ─────────────────
function desactivar(id) {
    Swal.fire({
        title: '¿Desactivar categoría?',
        text: 'La categoría quedará inactiva pero podrá reactivarse.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, desactivar',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#e74c3c'
    }).then(function (result) {
        if (result.isConfirmed) cambiarEstadoCategoria(id, false);
    });
}

function activar(id, descripcion) {
    Swal.fire({
        title: '¿Activar categoría?',
        text: '"' + descripcion + '" volverá a estar disponible.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, activar',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#27ae60'
    }).then(function (result) {
        if (result.isConfirmed) cambiarEstadoCategoria(id, true);
    });
}

// ── AJAX compartido para cambiar estado ───────────────────
function cambiarEstadoCategoria(id, activo, callback) {
    $.ajax({
        url: $.MisUrls.url._CambiarEstadoCategoria,
        type: 'POST',
        data: { id: id, activo: activo },
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                var msg = activo ? 'Categoría activada.' : 'Categoría desactivada.';
                Swal.fire('Listo', msg, 'success');
                if (typeof callback === 'function') callback();
            } else {
                Swal.fire('Atención', data.mensaje || 'No se pudo cambiar el estado.', 'warning');
            }
        },
        error: function () {
            Swal.fire('Error', 'Ocurrió un error al cambiar el estado.', 'error');
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
            if ($li.find('a.nav-link').attr('name') === menuactivo) {
                $li.addClass('active');
            }
        }
    });
}