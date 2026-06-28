var idRolUsuarioActual = 0;
var usuarioActualEsAdmin = false;

$(document).ready(function () {
    activarMenu("Configuración");

    // Capturar IdRol del usuario actual desde el hidden
    idRolUsuarioActual = parseInt($("#hdIdRolUsuario").val(), 10) || 0;
    usuarioActualEsAdmin = idRolUsuarioActual === 1 || idRolUsuarioActual === 14; // 1 = ADMINISTRADOR, 14 = SUPERADMIN
    console.log("IdRol usuario actual:", idRolUsuarioActual, "Es admin?", usuarioActualEsAdmin);

    // Cargar roles
    cargarRoles();

    // Evento cambio de rol
    $(document).on('change', '#cboRol', function () {
        var idRol = parseInt($(this).val(), 10) || 0;
        if (idRol > 0) {
            cargarPermisos(idRol);
        } else {
            $("#tbpermiso tbody").html(`<tr><td colspan="4" class="text-center text-muted">Seleccione un rol para ver sus permisos</td></tr>`);
        }
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
// Buscar (botón de la vista)
// ==========================
function buscar() {
    var idRol = parseInt($("#cboRol").val(), 10) || 0;
    if (idRol > 0) {
        cargarPermisos(idRol);
    } else {
        Swal.fire({ title: "Atención", text: "Seleccione un rol primero", icon: "warning" });
    }
}

// ==========================
// Cargar permisos por rol
// ==========================
function cargarPermisos(idRol) {
    if (!usuarioActualEsAdmin && idRol === 1) {
        Swal.fire({ title: "Atención", text: "No puede modificar permisos de administradores", icon: "warning" });
        $("#tbpermiso tbody").html(`<tr><td colspan="4" class="text-center text-muted">No puede ver permisos de administradores</td></tr>`);
        return;
    }

    $.ajax({
        url: $.MisUrls.url._ListPermisosPorRol,
        type: 'GET',
        data: { idRol: idRol },
        success: function (data) {
            const permisos = data.data || [];
            let html = "";

            if (permisos.length === 0) {
                html = `<tr><td colspan="4" class="text-center text-muted">Este rol no tiene permisos asignados.</td></tr>`;
            } else {
                let menuActual = null;
                let contador = 0;
                permisos.forEach((p) => {
                    if (p.Menu !== menuActual) {
                        menuActual = p.Menu;
                        html += `<tr style="background:#e8f4f8">
                            <td colspan="4" style="font-weight:600;font-size:.8rem;
                                color:#117a8b;text-transform:uppercase;letter-spacing:.05em">
                                <i class="fas fa-folder-open fa-xs mr-1"></i>${menuActual}
                            </td>
                        </tr>`;
                    }
                    contador++;
                    html += `<tr>
                        <td style="padding-left:1.5rem">${contador}</td>
                        <td class="text-center">
                            <input type="checkbox" class="chkPermiso"
                                   data-idpermiso="${p.IdPermisos}"
                                   ${p.Activo ? 'checked' : ''}>
                        </td>
                        <td>${p.Menu || ''}</td>
                        <td>${p.SubMenu || ''}</td>
                    </tr>`;
                });
            }

            $("#tbpermiso tbody").html(html);
        },
        error: function () {
            alert("Error al cargar permisos del rol seleccionado.");
        }
    });
}

// ==========================
// Guardar todos los permisos (si necesitás XML o POST masivo)
// ==========================
function Guardar() {
    const idRol = parseInt($("#cboRol").val(), 10) || 0;
    if (idRol === 0) {
        Swal.fire({ title: "Atención", text: "Seleccione un rol", icon: "warning" });
        return;
    }

    const permisosArray = $(".chkPermiso").map(function () {
        return `<PERMISO>
                    <IdPermisos>${$(this).data("idpermiso")}</IdPermisos>
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
                Swal.fire({ title: "Éxito", text: "Permisos guardados correctamente", icon: "success" });
                cargarPermisos(idRol);
            } else {
                Swal.fire({ title: "Error", text: data.mensaje || "No se pudo guardar", icon: "warning" });
            }
        },
        error: function (err) {
            console.error("Error al guardar permisos:", err);
        }
    });
}
