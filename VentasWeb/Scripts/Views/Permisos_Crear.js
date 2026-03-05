var idRolUsuarioActual = 0;
var usuarioActualEsAdmin = false;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // Capturar IdRol del usuario actual desde el hidden
    idRolUsuarioActual = parseInt($("#hdIdRolUsuario").val(), 10) || 0;
    usuarioActualEsAdmin = idRolUsuarioActual === 1; // 1 = ADMINISTRADOR
    console.log("IdRol usuario actual:", idRolUsuarioActual, "Es admin?", usuarioActualEsAdmin);

    // Cargar roles
    cargarRoles();

    // Evento cambio de rol
    $(document).on('change', '#cboRol', function () {
        var idRol = parseInt($(this).val(), 10) || 0;
        if (idRol > 0) {
            cargarPermisos(idRol);
        } else {
            $("#tblPermisos tbody").html(`<tr><td colspan="2" class="text-center text-muted">Seleccione un rol para ver sus permisos</td></tr>`);
        }
    });

    // Evento cambio de checkbox de permisos
    $(document).on('change', '.chkPermiso', function () {
        var idPermiso = $(this).data("idpermiso");
        var activo = $(this).is(':checked');
        actualizarPermiso(idPermiso, activo, this);
    });
});

// ==========================
// Cargar roles en el combo
// ==========================
function cargarRoles() {
    $.ajax({
        url: $.MisUrls.url._ObtenerRoles,
        type: 'GET',
        success: function (data) {
            const $cboRol = $("#cboRol");
            if (data.data && data.data.length > 0) {
                $cboRol.empty().append('<option value="">Seleccione un Rol</option>');
                data.data.forEach(rol => $cboRol.append(`<option value="${rol.IdRol}">${rol.Descripcion}</option>`));
            } else {
                $cboRol.html('<option value="">No hay roles disponibles</option>');
            }
        },
        error: function () { alert("Error al cargar los roles."); }
    });
}

// ==========================
// Cargar permisos por rol
// ==========================
function cargarPermisos(idRol) {
    // Validación: usuario no admin no puede ver permisos de admin
    if (!usuarioActualEsAdmin && idRol === 1) {
        swal("Mensaje", "No puede modificar permisos de administradores", "warning");
        $("#tblPermisos tbody").html(`<tr><td colspan="2" class="text-center text-muted">No puede ver permisos de administradores</td></tr>`);
        return;
    }

    $.ajax({
        url: '/Permiso/ListarPermisosPorRol',
        type: 'GET',
        data: { idRol: idRol },
        success: function (data) {
            const permisos = data.data || [];
            let html = "";

            if (permisos.length === 0) {
                html = `<tr><td colspan="2" class="text-center text-muted">Este rol no tiene permisos asignados.</td></tr>`;
            } else {
                permisos.forEach(p => {
                    html += `<tr>
                        <td>${p.NombreSubMenu}</td>
                        <td class="text-center">
                            <input type="checkbox" class="chkPermiso" 
                                   data-idpermiso="${p.IdPermiso}" 
                                   ${p.Activo ? 'checked' : ''}>
                        </td>
                    </tr>`;
                });
            }

            $("#tblPermisos tbody").html(html);
        },
        error: function () {
            alert("Error al cargar permisos del rol seleccionado.");
        }
    });
}

// ==========================
// Actualizar permiso individual
// ==========================
function actualizarPermiso(idPermiso, activo, checkbox) {
    $.ajax({
        url: '/Permiso/ActualizarEstadoPermiso',
        type: 'POST',
        data: { idPermiso: idPermiso, activo: activo },
        success: function (data) {
            if (data.resultado) {
                console.log("Permiso actualizado correctamente.");
            } else {
                alert("No se pudo actualizar el permiso.");
                $(checkbox).prop('checked', !activo); // revertir checkbox
            }
        },
        error: function () {
            alert("Error al actualizar el permiso.");
            $(checkbox).prop('checked', !activo); // revertir checkbox
        }
    });
}

// ==========================
// Guardar todos los permisos (si necesitás XML o POST masivo)
// ==========================
function Guardar() {
    const idRol = parseInt($("#cboRol").val(), 10) || 0;
    if (idRol === 0) {
        swal("Mensaje", "Seleccione un rol", "warning");
        return;
    }

    const permisosArray = $(".chkPermiso").map(function () {
        return `<PERMISO>
                    <IdPermiso>${$(this).data("idpermiso")}</IdPermiso>
                    <Activo>${$(this).is(':checked') ? 1 : 0}</Activo>
                </PERMISO>`;
    }).get();

    const xml = `<DETALLE>${permisosArray.join("")}</DETALLE>`;

    $.ajax({
        url: $.MisUrls.url._GuardarPermisos,
        type: 'POST',
        data: JSON.stringify({ xml: xml }),
        contentType: 'application/json; charset=utf-8',
        success: function (data) {
            if (data.resultado) {
                swal("Éxito", "Permisos guardados correctamente", "success");
                cargarPermisos(idRol); // recargar tabla
            } else {
                swal("Error", data.mensaje || "No se pudo guardar", "warning");
            }
        },
        error: function (err) {
            console.error("Error al guardar permisos:", err);
        }
    });
}
