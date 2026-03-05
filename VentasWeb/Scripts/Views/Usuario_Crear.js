$(document).ready(function () {

    // ══════════════════════════════════════════════════
    //  INICIALIZACIÓN
    // ══════════════════════════════════════════════════
    cargarRoles();
    cargarTiendas();
    iniciarDataTable();

    // ══════════════════════════════════════════════════
    //  CARGA DE SELECTS
    //  _ObtenerRoles  → Rol/Obtener  (ya definido en layout)
    //  _ObtenerTiendasActivas → Empleado/ObtenerTiendasActivas
    // ══════════════════════════════════════════════════
    function cargarRoles() {
        $.get($.MisUrls.url._ObtenerRoles, function (response) {
            var lista = Array.isArray(response) ? response
                : (response.data ? response.data : []);
            var $s = $("#cboRolUsuario");
            $s.empty().append('<option value="">-- Seleccione Rol --</option>');
            lista.filter(function (r) { return r.Activo; }).forEach(function (item) {
                $s.append('<option value="' + item.IdRol + '">' + item.Descripcion + '</option>');
            });
        });
    }

    function cargarTiendas(idSeleccionada) {
        $.get($.MisUrls.url._ObtenerTiendasActivas, function (response) {
            var lista = Array.isArray(response) ? response
                : (response.data ? response.data : []);
            var $s = $("#cboTiendaUsuario");
            $s.empty().append('<option value="">-- Seleccione Tienda --</option>');
            lista.forEach(function (item) {
                $s.append('<option value="' + item.IdTienda + '">' + item.Nombre + '</option>');
            });
            if (idSeleccionada) $s.val(idSeleccionada);
        });
    }

    // ══════════════════════════════════════════════════
    //  DATATABLE  — _ObtenerUsuarios → Usuario/Obtener
    // ══════════════════════════════════════════════════
    function iniciarDataTable() {
        $('#tbUsuarios').DataTable({
            responsive: true,
            autoWidth: false,
            ajax: {
                url: $.MisUrls.url._ObtenerUsuarios,
                type: 'GET',
                datatype: 'json'
            },
            columns: [
                { data: 'Nombres' },
                { data: 'Apellidos' },
                { data: 'Correo' },
                {
                    data: 'oRol',
                    render: function (data) {
                        return (data && data.Descripcion) ? data.Descripcion : '';
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
                        return row.Activo
                            ? '<button class="btn btn-sm btn-warning" onclick="CambiarEstado(' + data + ',false)" title="Desactivar"><i class="fa fa-toggle-off"></i></button>'
                            : '<button class="btn btn-sm btn-success" onclick="CambiarEstado(' + data + ',true)"  title="Activar"><i class="fa fa-check"></i></button>';
                    },
                    orderable: false,
                    searchable: false,
                    width: "80px"
                }
            ],
            language: { url: $.MisUrls.url.Url_datatable_spanish }
        });
    }

    // ══════════════════════════════════════════════════
    //  ABRIR MODAL
    // ══════════════════════════════════════════════════
    $(document).on("click", "#btnAgregarUsuario", function () {
        resetearFormulario();
        $("#FormUsuario").modal("show");
    });

    function resetearFormulario() {
        $("#txtIdEmpleadoUsuario").val(0);
        $("#txtDocumentoUsuario, #txtNombresUsuario, #txtApellidosUsuario, #txtCIRUCUsuario, #txtCorreoUsuario").val("");
        $("#cboRolUsuario").val("");
        $("#ddlEstadoUsuario").val("1");
        cargarTiendas();
        desbloquearCamposProtegidos();
    }

    // ══════════════════════════════════════════════════
    //  BUSCAR EMPLEADO — _BuscarEmpleadoPorCI → Usuario/BuscarEmpleadoPorCI
    // ══════════════════════════════════════════════════
    $("#btnBuscarEmpleado").click(function () {
        var ci = $("#txtDocumentoUsuario").val().trim();
        if (!ci) {
            Swal.fire("Atención", "Ingrese un CI o RUC para buscar.", "warning");
            return;
        }

        $.get($.MisUrls.url._BuscarEmpleadoPorCI, { ci: ci }, function (resp) {
            if (!resp.existe) {
                Swal.fire("No encontrado", resp.mensaje || "No se encontró la persona.", "warning");
                desbloquearCamposProtegidos();
                return;
            }

            var d = resp.data;
            $("#txtIdEmpleadoUsuario").val(d.IdEmpleado || 0);
            $("#txtNombresUsuario").val(d.Nombres || "");
            $("#txtApellidosUsuario").val(d.Apellidos || "");
            $("#txtCIRUCUsuario").val(d.Documento || "");
            $("#txtCorreoUsuario").val(d.Correo || "");

            if (d.IdTienda && d.IdTienda > 0) cargarTiendas(d.IdTienda);

            bloquearCamposProtegidos();

        }).fail(function () {
            Swal.fire("Error", "No se pudo conectar con el servidor.", "error");
        });
    });

    // ══════════════════════════════════════════════════
    //  HELPERS
    // ══════════════════════════════════════════════════
    function bloquearCamposProtegidos() {
        $("#txtNombresUsuario, #txtApellidosUsuario, #txtCIRUCUsuario, #txtCorreoUsuario")
            .prop("readonly", true).addClass("campo-bloqueado");
    }
    function desbloquearCamposProtegidos() {
        $("#txtNombresUsuario, #txtApellidosUsuario, #txtCIRUCUsuario, #txtCorreoUsuario")
            .prop("readonly", false).removeClass("campo-bloqueado");
    }

    // ══════════════════════════════════════════════════
    //  GUARDAR — _CrearUsuarioPendiente → Usuario/CrearUsuarioPendiente
    // ══════════════════════════════════════════════════
    $("#btnGuardarUsuario").click(function () {
        var idEmpleado = parseInt($("#txtIdEmpleadoUsuario").val()) || 0;
        var correo = $("#txtCorreoUsuario").val().trim();
        var idRol = $("#cboRolUsuario").val();
        var idTienda = $("#cboTiendaUsuario").val();
        var activo = $("#ddlEstadoUsuario").val() === "1";

        if (idEmpleado <= 0) { Swal.fire("Atención", "Busque y seleccione un empleado primero.", "warning"); return; }
        if (!correo) { Swal.fire("Atención", "El correo es obligatorio.", "warning"); return; }
        if (!idRol) { Swal.fire("Atención", "Seleccione un rol.", "warning"); return; }
        if (!idTienda) { Swal.fire("Atención", "Seleccione una tienda.", "warning"); return; }

        $.ajax({
            url: $.MisUrls.url._CrearUsuarioPendiente,
            type: 'POST',
            data: JSON.stringify({
                IdEmpleado: idEmpleado,
                Correo: correo,
                IdRol: parseInt(idRol),
                IdTienda: parseInt(idTienda),
                Activo: activo
            }),
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
    });

    // ══════════════════════════════════════════════════
    //  CAMBIAR ESTADO — _CambiarEstadoUsuario → Usuario/CambiarEstadoUsuario
    // ══════════════════════════════════════════════════
    window.CambiarEstado = function (id, activar) {
        Swal.fire({
            title: '¿Está seguro?',
            text: '¿Desea ' + (activar ? 'activar' : 'desactivar') + ' este usuario?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí',
            cancelButtonText: 'No'
        }).then(function (result) {
            if (result.isConfirmed) {
                $.post($.MisUrls.url._CambiarEstadoUsuario, { id: id, activo: activar ? "true" : "false" }, function (resp) {
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