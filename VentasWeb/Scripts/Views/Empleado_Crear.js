$(document).ready(function () {

    // Cargar Tiendas al abrir modal
    function cargarTiendas() {
        $.get($.MisUrls.url._ObtenerTiendasActivas, function (data) {
            var $select = $("#cboTienda");
            $select.empty();
            $select.append('<option value="">-- Seleccione Tienda --</option>');
            data.forEach(function (item) {
                $select.append(`<option value="${item.IdTienda}">${item.Nombre}</option>`);
            });
        });
    }

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

                // 🔒 Desactivar campos que no deben modificarse
                $("#txtDocumento").prop("disabled", true);
                $("#txtNombres").prop("disabled", true);
                $("#txtApellidos").prop("disabled", true);
                $("#txtCorreo").prop("disabled", true);
                $("#txtTelefono").prop("disabled", true);

                // ✅ Activar solo los campos que se pueden modificar
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
                    let botones = `<button class="btn btn-sm btn-primary" onclick="abrirPopUpFormEmpleado(${data}, true)">
            <i class="fa fa-edit"></i></button> `;

                    if (row.Activo) {
                        botones += `<button class="btn btn-sm btn-warning" onclick="CambiarEstadoEmpleado(${data}, false)">
                <i class="fa fa-toggle-off" title="Desactivar empleado"></i></button>`;
                    } else {
                        botones += `<button class="btn btn-sm btn-success" onclick="CambiarEstadoEmpleado(${data}, true)">
                <i class="fa fa-check" title="Activar empleado"></i></button>`;
                    }

                    return botones;
                },
                orderable: false,
                searchable: false,
                width: "120px"
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }
    });

    // Cambiar estado Activo/Inactivo
    window.CambiarEstadoEmpleado = function (id, activar) {
        let mensaje = activar ? "activar" : "desactivar";
        Swal.fire({
            title: '¿Está seguro?',
            text: `Desea ${mensaje} este empleado?`,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí',
            cancelButtonText: 'No'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post('/Empleado/CambiarEstado', { id: id, activo: activar }, function (resp) {
                    if (resp.resultado) {
                        Swal.fire("Éxito", "Empleado actualizado correctamente", "success");
                        $('#tbEmpleados').DataTable().ajax.reload();
                    } else {
                        Swal.fire("Error", resp.mensaje || "No se pudo actualizar", "error");
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
        cargarTiendas();

        if (esEditar && idEmpleado) {
            $("#divBuscarPersona").hide(); // ocultar campo CI y botón Buscar
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
                    $("#cboTienda").val(data.IdTienda);
                }
            });
        } else {
            $("#divBuscarPersona").show(); // mostrar campo CI y botón Buscar
            $("#txtIdPersona").val(0);
            $("#FormEmpleado .modal-title").text("Nuevo Empleado");

            // 👇 Aquí agregás tu bloque
            $("#txtDocumento, #txtNombres, #txtApellidos, #txtCorreo, #txtTelefono").prop("disabled", false);
            $("#txtFechaIngreso, #ddlEstadoEmpleado, #cboTienda").prop("disabled", false);
        }

        $("#FormEmpleado").modal("show");
    };

});
