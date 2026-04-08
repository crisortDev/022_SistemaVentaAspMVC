$(document).ready(function () {

    // Cargar Tiendas al abrir modal
    function cargarTiendas(idTiendaSeleccionada) {
        $.get($.MisUrls.url._ObtenerTiendasActivas, function (response) {
            var lista = Array.isArray(response) ? response
                : (response.data ? response.data : []);
            var $select = $("#cboTienda");
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

    // Cargar tiendas al iniciar la página
    cargarTiendas();

    // Abrir modal para agregar empleado
    $(document).on("click", "#btnAgregarEmpleado", function () {
        abrirPopUpFormEmpleado();
    });

    // Botón Guardar
    $("#btnGuardarEmpleado").click(function () {
        GuardarEmpleado();
    });

    // Buscar persona por CI
    $("#btnBuscarPersona").click(function () {
        var ci = $("#txtCI").val().trim();
        if (ci === "") return;

        $.get($.MisUrls.url._BuscarPorCI, { ci: ci }, function (resp) {
            if (resp.resultado) {
                $("#txtIdPersona").val(resp.data.IdPersona);
                $("#txtDocumento").val(resp.data.Documento);
                $("#txtNombres").val(resp.data.Nombres);
                $("#txtApellidos").val(resp.data.Apellidos);
                $("#txtCorreo").val(resp.data.Correo);
                $("#txtTelefono").val(resp.data.Telefono);

                // Desactivar campos que no deben modificarse
                $("#txtDocumento").prop("disabled", true);
                $("#txtNombres").prop("disabled", true);
                $("#txtApellidos").prop("disabled", true);
                $("#txtCorreo").prop("disabled", true);
                $("#txtTelefono").prop("disabled", true);

                // Activar solo los campos que se pueden modificar
                $("#txtFechaIngreso").prop("disabled", false);
                $("#ddlEstadoEmpleado").prop("disabled", false);
                $("#cboTienda").prop("disabled", false);

                Swal.fire("Info", "Persona encontrada. Complete los datos de empleado.", "info");
            } else {
                Swal.fire("Error", resp.mensaje, "warning");
            }
        });
    });

    // Guardar empleado
    function GuardarEmpleado() {
        var fechaIngreso = $("#txtFechaIngreso").val();
        if (fechaIngreso) {
            var partes = fechaIngreso.split('-');
            var fechaIngresada = new Date(partes[0], partes[1] - 1, partes[2]);
            var hoy = new Date();
            hoy.setHours(0, 0, 0, 0);

            if (fechaIngresada < hoy) {
                Swal.fire("Error", "La fecha de ingreso no puede ser menor que el día actual.", "warning");
                return;
            }
        }

        var emp = {
            IdEmpleado: $("#txtIdEmpleado").val(),
            IdPersona: $("#txtIdPersona").val(),
            Documento: $("#txtDocumento").val(),
            Nombres: $("#txtNombres").val(),
            Apellidos: $("#txtApellidos").val(),
            Correo: $("#txtCorreo").val(),
            Telefono: $("#txtTelefono").val(),
            FechaIngreso: $("#txtFechaIngreso").val(),
            Activo: $("#ddlEstadoEmpleado").val() === "1",
            IdTienda: $("#cboTienda").val()
        };

        $.ajax({
            url: '/Empleado/Guardar',
            type: 'POST',
            data: JSON.stringify(emp),
            contentType: 'application/json; charset=utf-8',
            success: function (resp) {
                if (resp.resultado) {
                    Swal.fire("Éxito", resp.mensaje, "success");
                    $('#FormEmpleado').modal('hide');
                    $('#tbEmpleados').DataTable().ajax.reload();
                } else {
                    Swal.fire("Error", resp.mensaje, "error");
                }
            }
        });
    }

    // Inicializar DataTable
    $('#tbEmpleados').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: { url: '/Empleado/Obtener', type: 'GET', datatype: 'json' },
        order: [[4, 'desc']],
        columns: [
            { data: 'Documento' },
            { data: 'Nombres' },
            { data: 'Apellidos' },
            { data: 'IdTienda', render: function (data) { return data; } },
            {
                data: 'FechaIngreso',
                render: function (data) {
                    if (!data) return '';
                    var timestamp = parseInt(data.replace(/\/Date\((\d+)\)\//, '$1'));
                    var fecha = new Date(timestamp);
                    return fecha.toLocaleDateString('es-ES');
                }
            },
            { data: 'Correo' },
            { data: 'Telefono' },
            {
                data: 'Activo',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdEmpleado',
                render: function (data, type, row) {
                    // Botón Ver (solo lectura)
                    let botones = `<button class="btn btn-sm btn-info mr-1" onclick='verEmpleado(${JSON.stringify(row)})' title="Ver detalle">
                        <i class="fa fa-eye"></i></button>`;

                    // Botón Editar siempre disponible
                    botones += `<button class="btn btn-sm btn-primary mr-1" onclick="abrirPopUpFormEmpleado(${data}, true)" title="Editar">
                        <i class="fa fa-edit"></i></button>`;

                    // Borrado lógico: toggle Activo/Inactivo según estado actual
                    if (row.Activo) {
                        botones += `<button class="btn btn-sm btn-danger" onclick="CambiarEstadoEmpleado(${data}, false)" title="Desactivar empleado">
                            <i class="fa fa-ban"></i></button>`;
                    } else {
                        botones += `<button class="btn btn-sm btn-success" onclick="CambiarEstadoEmpleado(${data}, true)" title="Activar empleado">
                            <i class="fa fa-check"></i></button>`;
                    }

                    return botones;
                },
                orderable: false,
                searchable: false,
                width: "130px"
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }
    });

    // Ver detalle empleado (solo lectura)
    window.verEmpleado = function (json) {
        $("#verDocumento").text(json.Documento || '—');
        $("#verNombres").text(json.Nombres || '—');
        $("#verApellidos").text(json.Apellidos || '—');
        $("#verCorreo").text(json.Correo || '—');
        $("#verTelefono").text(json.Telefono || '—');
        if (json.FechaIngreso) {
            var timestamp = parseInt(json.FechaIngreso.replace(/\/Date\((\d+)\)\//, '$1'));
            var fecha = new Date(timestamp);
            $("#verFechaIngreso").text(fecha.toLocaleDateString('es-ES'));
        } else {
            $("#verFechaIngreso").text('—');
        }
        $("#verEstado").html(json.Activo
            ? '<span class="badge badge-success">Activo</span>'
            : '<span class="badge badge-danger">Inactivo</span>');
        $('#VerModal').modal('show');
    };

    // Cambiar estado Activo/Inactivo (borrado lógico)
    window.CambiarEstadoEmpleado = function (id, activar) {
        let accion = activar ? "activar" : "desactivar";
        let icono = activar ? "question" : "warning";
        let confirmColor = activar ? "#27ae60" : "#e74c3c";
        let confirmText = activar ? "Sí, activar" : "Sí, desactivar";

        Swal.fire({
            title: '¿Está seguro?',
            text: `¿Desea ${accion} este empleado?`,
            icon: icono,
            showCancelButton: true,
            confirmButtonText: confirmText,
            cancelButtonText: 'Cancelar',
            confirmButtonColor: confirmColor
        }).then((result) => {
            if (result.isConfirmed) {
                $.post('/Empleado/CambiarEstado', { id: id, activo: activar }, function (resp) {
                    if (resp.resultado) {
                        let msg = activar ? "Empleado activado correctamente." : "Empleado desactivado correctamente.";
                        Swal.fire("Éxito", msg, "success");
                        $('#tbEmpleados').DataTable().ajax.reload();
                    } else {
                        Swal.fire("Error", resp.mensaje || "No se pudo actualizar.", "error");
                    }
                });
            }
        });
    };

    // Abrir modal para nuevo o editar empleado
    window.abrirPopUpFormEmpleado = function (idEmpleado, esEditar = false) {
        $("#formEmpleado")[0].reset();
        $("#txtIdPersona").val(0);
        $("#txtIdEmpleado").val(idEmpleado || 0);
        $("#ddlEstadoEmpleado").val("1");

        if (esEditar && idEmpleado) {
            $("#divBuscarPersona").hide();
            $("#FormEmpleado .modal-title").text("Editar Empleado");

            $.get("/Empleado/ObtenerPorId", { id: idEmpleado }, function (data) {
                if (data) {
                    $("#txtIdPersona").val(data.IdPersona);
                    $("#txtDocumento").val(data.Documento);
                    $("#txtNombres").val(data.Nombres);
                    $("#txtApellidos").val(data.Apellidos);
                    $("#txtCorreo").val(data.Correo);
                    $("#txtTelefono").val(data.Telefono);
                    $("#ddlEstadoEmpleado").val(data.Activo ? "1" : "0");
                    cargarTiendas(data.IdTienda);
                }
            });
        } else {
            $("#divBuscarPersona").show();
            $("#txtIdPersona").val(0);
            $("#FormEmpleado .modal-title").text("Nuevo Empleado");

            $("#txtDocumento, #txtNombres, #txtApellidos, #txtCorreo, #txtTelefono").prop("disabled", false);
            $("#txtFechaIngreso, #ddlEstadoEmpleado, #cboTienda").prop("disabled", false);
        }

        $("#FormEmpleado").modal("show");
    };

});