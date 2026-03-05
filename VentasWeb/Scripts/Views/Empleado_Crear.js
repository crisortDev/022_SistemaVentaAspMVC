$(document).ready(function () {

    // ══════════════════════════════════════════════════
    //  INICIALIZACIÓN
    // ══════════════════════════════════════════════════
    cargarRoles();
    cargarTiendas();

    // ── Cargar Roles ──────────────────────────────────
    function cargarRoles() {
        $.get('/Usuario/ObtenerRoles', function (response) {
            var lista = Array.isArray(response) ? response : (response.data ? response.data : []);
            var $select = $("#cboRolUsuario");
            $select.empty();
            $select.append('<option value="">-- Seleccione Rol --</option>');
            lista.forEach(function (item) {
                $select.append(`<option value="${item.IdRol}">${item.Descripcion}</option>`);
            });
        });
    }

    // ── Cargar Tiendas ────────────────────────────────
    function cargarTiendas(idTiendaSeleccionada) {
        $.get('/Empleado/ObtenerTiendasActivas', function (response) {
            var lista = Array.isArray(response) ? response : (response.data ? response.data : []);
            var $select = $("#cboTiendaUsuario");
            $select.empty();
            $select.append('<option value="">-- Seleccione Tienda --</option>');
            lista.forEach(function (item) {
                $select.append(`<option value="${item.IdTienda}">${item.Nombre}</option>`);
            });
            if (idTiendaSeleccionada) {
                $select.val(idTiendaSeleccionada);
            }
        });
    }

    // ══════════════════════════════════════════════════
    //  ABRIR MODAL
    // ══════════════════════════════════════════════════
    $(document).on("click", "#btnAgregarUsuario", function () {
        abrirFormUsuario();
    });

    window.abrirFormUsuario = function () {
        // Limpiar todos los campos
        $("#txtIdEmpleadoUsuario").val(0);
        $("#txtDocumentoUsuario").val("");
        $("#txtNombresUsuario").val("");
        $("#txtApellidosUsuario").val("");
        $("#txtCIRUCUsuario").val("");
        $("#txtCorreoUsuario").val("");
        $("#cboRolUsuario").val("");
        $("#ddlEstadoUsuario").val("1"); // default Activo
        cargarTiendas();

        // Desbloquear campo de búsqueda y limpiar estilos de solo lectura
        desbloquearCamposProtegidos();

        $("#FormUsuario").modal("show");
    };

    // ══════════════════════════════════════════════════
    //  BUSCAR EMPLEADO POR CI / RUC
    // ══════════════════════════════════════════════════
    $("#btnBuscarEmpleado").click(function () {
        var documento = $("#txtDocumentoUsuario").val().trim();

        if (!documento) {
            Swal.fire("Atención", "Ingrese un CI o RUC para buscar.", "warning");
            return;
        }

        $.get('/Empleado/BuscarPersonaPorDocumento', { documento: documento }, function (resp) {

            if (!resp.existe) {
                Swal.fire("No encontrado", resp.mensaje || "No se encontró la persona.", "warning");
                desbloquearCamposProtegidos();
                return;
            }

            var data = resp.data;

            // ── Rellenar campos ────────────────────────────
            $("#txtIdEmpleadoUsuario").val(data.IdEmpleado || 0);
            $("#txtNombresUsuario").val(data.Nombres || "");
            $("#txtApellidosUsuario").val(data.Apellidos || "");
            $("#txtCIRUCUsuario").val(data.Documento || "");   // ← CI/RUC se rellena correctamente
            $("#txtCorreoUsuario").val(data.Correo || "");     // ← Correo de Persona (solo lectura)

            // ── Preseleccionar tienda si el empleado ya tiene una ──
            if (data.IdTienda && data.IdTienda > 0) {
                cargarTiendas(data.IdTienda);
            }

            // ── Bloquear campos protegidos ─────────────────
            bloquearCamposProtegidos();

            if (!resp.esEmpleado) {
                Swal.fire("Info",
                    "Persona encontrada pero no está registrada como empleado activo.",
                    "info");
            }
        }).fail(function () {
            Swal.fire("Error", "No se pudo conectar con el servidor.", "error");
        });
    });

    // ══════════════════════════════════════════════════
    //  HELPERS — bloquear / desbloquear campos
    // ══════════════════════════════════════════════════
    function bloquearCamposProtegidos() {
        $("#txtNombresUsuario, #txtApellidosUsuario, #txtCIRUCUsuario, #txtCorreoUsuario")
            .prop("readonly", true)
            .addClass("campo-bloqueado");
    }

    function desbloquearCamposProtegidos() {
        $("#txtNombresUsuario, #txtApellidosUsuario, #txtCIRUCUsuario, #txtCorreoUsuario")
            .prop("readonly", false)
            .removeClass("campo-bloqueado");
    }

    // ══════════════════════════════════════════════════
    //  GUARDAR USUARIO
    // ══════════════════════════════════════════════════
    $("#btnGuardarUsuario").click(function () {
        GuardarUsuario();
    });

    function GuardarUsuario() {
        var idEmpleado = parseInt($("#txtIdEmpleadoUsuario").val()) || 0;
        var correo = $("#txtCorreoUsuario").val().trim();
        var idRol = $("#cboRolUsuario").val();
        var idTienda = $("#cboTiendaUsuario").val();
        var activo = $("#ddlEstadoUsuario").val() === "1";

        // ── Validaciones ───────────────────────────────
        if (idEmpleado <= 0) {
            Swal.fire("Atención", "Busque y seleccione un empleado primero.", "warning");
            return;
        }
        if (!correo) {
            Swal.fire("Atención", "El correo es obligatorio.", "warning");
            return;
        }
        if (!idRol) {
            Swal.fire("Atención", "Seleccione un rol.", "warning");
            return;
        }
        if (!idTienda) {
            Swal.fire("Atención", "Seleccione una tienda.", "warning");
            return;
        }

        var datos = {
            IdEmpleado: idEmpleado,
            Correo: correo,
            IdRol: parseInt(idRol),
            IdTienda: parseInt(idTienda),
            Activo: activo
        };

        $.ajax({
            url: '/Usuario/Guardar',
            type: 'POST',
            data: JSON.stringify(datos),
            contentType: 'application/json; charset=utf-8',
            success: function (resp) {
                if (resp.resultado) {
                    Swal.fire("Éxito", resp.mensaje, "success");
                    $('#FormUsuario').modal('hide');
                    $('#tbUsuarios').DataTable().ajax.reload();
                } else {
                    Swal.fire("Error", resp.mensaje, "error");
                }
            },
            error: function () {
                Swal.fire("Error", "No se pudo conectar con el servidor.", "error");
            }
        });
    }

    // ══════════════════════════════════════════════════
    //  DATATABLE USUARIOS
    // ══════════════════════════════════════════════════
    $('#tbUsuarios').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: { url: '/Usuario/Obtener', type: 'GET', datatype: 'json' },
        order: [[0, 'asc']],
        columns: [
            { data: 'Nombres' },
            { data: 'Apellidos' },
            { data: 'Correo' },
            {
                data: 'oRol',
                render: function (data) {
                    return data ? data.Descripcion : '';
                }
            },
            {
                data: 'Activo',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdUsuario',
                render: function (data, type, row) {
                    if (row.Activo) {
                        return `<button class="btn btn-sm btn-warning" onclick="cambiarEstadoUsuario(${data}, false)">
                                    <i class="fa fa-toggle-off" title="Desactivar"></i>
                                </button>`;
                    } else {
                        return `<button class="btn btn-sm btn-success" onclick="cambiarEstadoUsuario(${data}, true)">
                                    <i class="fa fa-check" title="Activar"></i>
                                </button>`;
                    }
                },
                orderable: false,
                searchable: false,
                width: "80px"
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }
    });

    // ── Cambiar estado Activo/Inactivo ────────────────
    window.cambiarEstadoUsuario = function (id, activar) {
        Swal.fire({
            title: '¿Está seguro?',
            text: `¿Desea ${activar ? 'activar' : 'desactivar'} este usuario?`,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí',
            cancelButtonText: 'No'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post('/Usuario/CambiarEstado', { id: id, activo: activar }, function (resp) {
                    if (resp.resultado) {
                        Swal.fire("Éxito", "Usuario actualizado correctamente.", "success");
                        $('#tbUsuarios').DataTable().ajax.reload();
                    } else {
                        Swal.fire("Error", resp.mensaje || "No se pudo actualizar.", "error");
                    }
                });
            }
        });
    };

});