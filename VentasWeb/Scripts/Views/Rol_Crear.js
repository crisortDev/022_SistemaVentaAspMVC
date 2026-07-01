$(document).ready(function () {

    // Cargar permisos disponibles y roles al iniciar
    cargarPermisosDisponibles();
    cargarRoles();

    // Método personalizado: nombre de rol (letras y espacios, admite acentos)
    $.validator.addMethod("soloLetras", function (value, element) {
        return this.optional(element) || /^[a-zA-ZÁÉÍÓÚáéíóúÑñÜü\s]+$/.test(value.trim());
    }, "El nombre del rol solo puede contener letras y espacios.");

    $("#formRol").validate({
        rules: {
            descripcionRol: { required: true, soloLetras: true, minlength: 3, maxlength: 50 }
        },
        messages: {
            descripcionRol: {
                required: "Ingresá el nombre del rol.",
                soloLetras: "El nombre del rol solo puede contener letras y espacios.",
                minlength: "Debe tener al menos 3 caracteres.",
                maxlength: "No puede superar los 50 caracteres."
            }
        },
        errorElement: 'small',
        errorClass: 'text-danger d-block',
        highlight: function (element) { $(element).addClass('is-invalid'); },
        unhighlight: function (element) { $(element).removeClass('is-invalid'); }
    });

    // 25002500 Forzar may00fasculas al escribir el nombre del rol 2500
    $("#txtDescripcionRol").on("input", function () {
        var pos = this.selectionStart; // conservar posici00f3n del cursor
        $(this).val($(this).val().toUpperCase());
        this.setSelectionRange(pos, pos);
    });

    // ── Seleccionar / deseleccionar todos ─────────────
    $("#chkTodos").change(function () {
        var checked = $(this).is(":checked");
        $(".permisoCheck").prop("checked", checked);
        actualizarContador();
    });

    // ── Contador de permisos seleccionados ────────────
    $(document).on("change", ".permisoCheck", function () {
        actualizarContador();
        // Si se desmarca uno, desmarcar el "todos"
        if (!$(this).is(":checked")) {
            $("#chkTodos").prop("checked", false);
        }
        // Si todos están marcados, marcar el "todos"
        if ($(".permisoCheck:checked").length === $(".permisoCheck").length) {
            $("#chkTodos").prop("checked", true);
        }
    });

    // ── Cambio de rol en el selector derecho ──────────
    $("#cboRol").on("change", function () {
        var idRol = parseInt($(this).val()) || 0;
        if (idRol > 0) {
            cargarPermisosPorRol(idRol);
        } else {
            $("#tbodyPermisos").html(
                '<tr><td colspan="2" class="text-center text-muted py-3">' +
                '<i class="fa fa-info-circle"></i> Seleccione un rol para ver sus permisos</td></tr>'
            );
        }
    });

    // ── Guardar Rol con Permisos ───────────────────────
    $("#btnGuardarRol").click(function () {
        if (!$("#formRol").valid()) return;

        var descripcion = $("#txtDescripcionRol").val().trim();

        var permisosSeleccionados = [];
        $(".permisoCheck:checked").each(function () {
            permisosSeleccionados.push(parseInt($(this).val()));
        });

        if (permisosSeleccionados.length === 0) {
            swal("Atención", "Seleccione al menos un permiso.", "warning");
            return;
        }

        var modelo = {
            Descripcion: descripcion,
            Activo: true,
            Permisos: permisosSeleccionados
        };

        $.ajax({
            url: $.MisUrls.url._GuardarRolConPermisos,
            type: "POST",
            data: JSON.stringify(modelo),
            contentType: "application/json; charset=utf-8",
            dataType: "text",
            success: function (respText) {
                try {
                    var resultado = JSON.parse(respText);

                    if (resultado && resultado.resultado === true) {
                        Swal.fire({
                            title: '¡Éxito!',
                            text: resultado.mensaje || "Rol y permisos guardados correctamente.",
                            icon: 'success',
                            confirmButtonText: 'Entendido',
                            confirmButtonColor: '#2563eb'
                        }).then(function () {
                            // Limpiar formulario
                            $("#txtDescripcionRol").val("");
                            $("#formRol").validate().resetForm();
                            $("#formRol .is-invalid").removeClass("is-invalid");
                            $(".permisoCheck").prop("checked", false);
                            $("#chkTodos").prop("checked", false);
                            actualizarContador();
                            // Recargar selector de roles
                            cargarRoles();
                        });
                    } else {
                        Swal.fire({
                            title: 'Error',
                            text: (resultado && resultado.mensaje) || "No se pudo guardar el rol.",
                            icon: 'error',
                            confirmButtonText: 'Entendido',
                            confirmButtonColor: '#dc2626'
                        });
                    }
                } catch (parseError) {
                    console.error("Error:", parseError);
                    Swal.fire({
                        title: 'Error',
                        text: "Error al procesar la respuesta del servidor.",
                        icon: 'error',
                        confirmButtonText: 'Entendido',
                        confirmButtonColor: '#dc2626'
                    });
                }
            },
            error: function (xhr, status, error) {
                console.error("Error AJAX:", error);
                Swal.fire({
                    title: 'Error de Conexión',
                    text: "Error en la petición: " + error,
                    icon: 'error',
                    confirmButtonText: 'Entendido',
                    confirmButtonColor: '#dc2626'
                });
            }
        });
    });

});

// ── Cargar permisos disponibles (panel izquierdo) ─────
function cargarPermisosDisponibles() {
    $.ajax({
        url: $.MisUrls.url._ListPermisosDisponibles,
        type: "GET",
        success: function (data) {
            var lista = data.data || data;
            var html = "";

            if (!lista || lista.length === 0) {
                html = '<div class="text-muted text-center w-100">No hay permisos disponibles.</div>';
            } else {
                // Agrupar por NombreMenu
                var grupos = {};
                lista.forEach(function (p) {
                    if (!grupos[p.NombreMenu]) grupos[p.NombreMenu] = [];
                    grupos[p.NombreMenu].push(p);
                });

                Object.keys(grupos).forEach(function (menu) {
                    html += '<div style="width:100%;margin-bottom:.4rem">' +
                            '<div style="font-weight:600;font-size:.78rem;color:#117a8b;' +
                            'text-transform:uppercase;letter-spacing:.05em;padding:4px 2px 2px;' +
                            'border-bottom:1px solid #bee5eb;margin-bottom:.3rem">' +
                            '<i class="fas fa-folder-open fa-xs mr-1"></i>' + menu +
                            '</div>';

                    grupos[menu].forEach(function (p) {
                        html += '<div class="form-check" style="padding-left:1.5rem">' +
                            '<input class="form-check-input permisoCheck" type="checkbox"' +
                            ' value="' + p.IdSubMenu + '" id="perm_' + p.IdSubMenu + '">' +
                            '<label class="form-check-label" for="perm_' + p.IdSubMenu + '" title="' + p.NombreSubMenu + '">' +
                            p.NombreSubMenu +
                            '</label>' +
                            '</div>';
                    });

                    html += '</div>';
                });
            }

            $("#divPermisosCheckbox").html(html);
            actualizarContador();
        },
        error: function () {
            $("#divPermisosCheckbox").html('<div class="text-danger">Error al cargar permisos.</div>');
        }
    });
}

// ── Cargar roles en el selector (panel derecho) ───────
function cargarRoles() {
    $.ajax({
        url: $.MisUrls.url._ObtenerRoles,
        type: "GET",
        success: function (data) {
            var lista = data.data || data;
            var $select = $("#cboRol");
            $select.empty().append('<option value="">-- Seleccione --</option>');
            lista.forEach(function (r) {
                $select.append('<option value="' + r.IdRol + '">' + r.Descripcion + '</option>');
            });
        }
    });
}

// ── Cargar permisos de un rol (panel derecho) ─────────
function cargarPermisosPorRol(idRol) {
    $("#tbodyPermisos").html(
        '<tr><td colspan="3" class="text-center py-2">' +
        '<i class="fa fa-spinner fa-spin"></i> Cargando...</td></tr>'
    );

    $.ajax({
        url: $.MisUrls.url._ListPermisosPorRol,
        type: "GET",
        data: { idRol: idRol },
        success: function (data) {
            var lista = data.data || data;
            var html = "";

            if (!lista || lista.length === 0) {
                html = '<tr><td colspan="3" class="text-center text-muted py-3">Este rol no tiene permisos asignados.</td></tr>';
            } else {
                var menuActual = null;
                lista.forEach(function (p) {
                    if (p.Menu !== menuActual) {
                        menuActual = p.Menu;
                        html += '<tr style="background:#e8f4f8">' +
                            '<td colspan="3" style="font-weight:600;font-size:.8rem;' +
                            'color:#117a8b;text-transform:uppercase;letter-spacing:.05em">' +
                            '<i class="fas fa-folder-open fa-xs mr-1"></i>' + menuActual +
                            '</td></tr>';
                    }
                    var badge = p.Activo
                        ? '<span class="badge-activo">Activo</span>'
                        : '<span class="badge-inactivo">Inactivo</span>';
                    html += '<tr>' +
                        '<td style="padding-left:1.5rem">' + p.SubMenu + '</td>' +
                        '<td class="text-center">' + badge + '</td>' +
                        '</tr>';
                });
            }

            $("#tbodyPermisos").html(html);
        },
        error: function () {
            $("#tbodyPermisos").html('<tr><td colspan="3" class="text-danger text-center">Error al cargar permisos.</td></tr>');
        }
    });
}

// ── Actualizar contador de permisos seleccionados ─────
function actualizarContador() {
    var total = $(".permisoCheck:checked").length;
    $("#lblContador").text(total + " seleccionado" + (total !== 1 ? "s" : ""));
}
