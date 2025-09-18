var tabladata;
var idRolUsuarioActual = 0;
var usuarioActualEsAdmin = false;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // Capturar IdRol del usuario actual desde el hidden
    idRolUsuarioActual = parseInt($("#hdIdRolUsuario").val(), 10) || 0;
    usuarioActualEsAdmin = idRolUsuarioActual === 1; // 1 = ADMINISTRADOR

    console.log("IdRol usuario actual:", idRolUsuarioActual, "Es admin?", usuarioActualEsAdmin);

    cargarRoles();
});

// ==========================
// Cargar roles en el combo
// ==========================
function cargarRoles() {
    $.ajax({
        url: $.MisUrls.url._ObtenerRoles,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            var $cbo = $("#cboRol");
            $cbo.empty();
            $("<option>").attr({ "value": 0 }).text("-- Seleccione --").appendTo($cbo);

            if (data?.data) {
                $.each(data.data, function (i, item) {
                    if (item.Activo) {
                        $("<option>").attr({ "value": item.IdRol }).text(item.Descripcion).appendTo($cbo);
                    }
                });
            }
        },
        error: function (err) {
            console.error("Error al cargar roles:", err);
        }
    });
}

// ==========================
// Buscar permisos por rol
// ==========================
function buscar() {
    var rolSeleccionadoId = parseInt($("#cboRol").val(), 10) || 0;

    if (rolSeleccionadoId === 0) {
        swal("Mensaje", "Seleccione un rol", "warning");
        return;
    }

    // Validación: usuario no admin no puede modificar permisos de admin
    if (!usuarioActualEsAdmin && rolSeleccionadoId === 1) {
        swal("Mensaje", "No puede modificar permisos de administradores", "warning");
        return;
    }

    $.ajax({
        url: $.MisUrls.url._ObtenerPermisos + "?id=" + rolSeleccionadoId,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        beforeSend: function () {
            $(".card-load").LoadingOverlay("show");
        },
        success: function (data) {
            $(".card-load").LoadingOverlay("hide");
            $("#tbpermiso tbody").empty();

            if (!data) return;

            const permisosCriticos = [1, 2, 3]; // ids de permisos críticos

            $.each(data, function (i, row) {
                var $checkbox = $("<input>").attr({ type: "checkbox" })
                    .data("IdPermiso", row.IdPermisos)
                    .prop("checked", row.Activo);

                // Bloquear permisos críticos de admin
                if (rolSeleccionadoId === 1 && permisosCriticos.includes(row.IdPermisos)) {
                    $checkbox.prop("checked", true).prop("disabled", true);
                }

                // Bloquear todo si usuario no admin y rol admin
                if (!usuarioActualEsAdmin && rolSeleccionadoId === 1) {
                    $checkbox.prop("disabled", true);
                }

                $("<tr>").append(
                    $("<td>").text(i + 1),
                    $("<td>").append($checkbox),
                    $("<td>").text(row.Menu),
                    $("<td>").text(row.SubMenu)
                ).appendTo("#tbpermiso tbody");
            });
        },
        error: function (err) {
            console.error("Error al obtener permisos:", err);
        }
    });
}

// ==========================
// Guardar cambios de permisos
// ==========================
function Guardar() {
    var rolSeleccionadoId = parseInt($("#cboRol").val(), 10) || 0;

    if (rolSeleccionadoId === 0) {
        swal("Mensaje", "Seleccione un rol", "warning");
        return;
    }

    if ($("#tbpermiso tbody tr").length === 0) {
        swal("Mensaje", "No hay datos", "warning");
        return;
    }

    // Validación: usuario no admin no puede guardar permisos de admin
    if (!usuarioActualEsAdmin && rolSeleccionadoId === 1) {
        swal("Mensaje", "No puede modificar permisos de administradores", "warning");
        return;
    }

    var permisosArray = $('input[type="checkbox"]').map(function () {
        return `<PERMISO>
                    <IdPermisos>${$(this).data("IdPermiso")}</IdPermisos>
                    <Activo>${$(this).prop("checked") ? 1 : 0}</Activo>
                </PERMISO>`;
    }).get();

    var xml = `<DETALLE>${permisosArray.join("")}</DETALLE>`;

    $.ajax({
        url: $.MisUrls.url._GuardarPermisos,
        type: "POST",
        data: JSON.stringify({ xml: xml }),
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        beforeSend: function () {
            $(".card-load").LoadingOverlay("show");
        },
        success: function (data) {
            $(".card-load").LoadingOverlay("hide");

            if (data.resultado) {
                $("#cboRol").val(0);
                $("#tbpermiso tbody").empty();
                location.reload();
            } else {
                swal("Mensaje", data.mensaje || "No se pudo guardar los cambios", "warning");
            }
        },
        error: function (err) {
            console.error("Error al guardar permisos:", err);
        }
    });
}

// ==========================
// Recargar menú lateral
// ==========================
function recargarMenu() {
    $("#menuLateral").load("/Home/RecargarMenu");
}
