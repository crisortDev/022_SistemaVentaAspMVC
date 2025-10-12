$(document).ready(function () {
    const tabla = $('#tbdata').DataTable({
        createdRow: function (row, data, dataIndex) {
            $('td', row).addClass('text-wrap');
            $('td:last-child', row).removeClass('text-wrap').addClass('no-wrap');
        },


        responsive: true,
        autoWidth: false,
        ajax: { url: '/Persona/Obtener', type: 'GET', datatype: 'json' },
        order: [[12, 'desc']],
        createdRow: function (row, data, dataIndex) {
            // Aplica estilo de envolvimiento a todas las celdas
            $('td', row).css('white-space', 'normal');
            // Evita envolvimiento en columna de acciones
            $('td:last-child', row).css('white-space', 'nowrap');
        },
        columns: [
            { data: 'Nombres' },
            { data: 'Apellidos' },
            { data: 'RazonSocial' },
            { data: 'Correo' },
            { data: 'Telefono' },
            { data: 'Calle1' },
            { data: 'Calle2' },
            { data: 'Ciudad' },
            { data: 'Barrio' },
            { data: 'TipoDocumento' },
            { data: 'Documento' },
            {
                data: 'Activo',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdPersona',
                render: function (data, type, row) {
                    let botones = `<button class="btn btn-sm btn-primary" onclick="abrirPopUpForm(${data})">
                        <i class="fa fa-edit"></i></button> `;

                    if (row.Activo) {
                        botones += `<button class="btn btn-sm btn-warning" onclick="CambiarEstado(${data}, false)">
                            <i class="fa fa-toggle-off"></i></button>`;
                    } else {
                        botones += `<button class="btn btn-sm btn-success" onclick="CambiarEstado(${data}, true)">
                            <i class="fa fa-check"></i></button>`;
                    }

                    return botones;
                },
                orderable: false,
                searchable: false,
                width: "120px"
            },
            { data: 'IdPersona', visible: false }
        ]
    });

    $("#btnAgregarNueva").click(function () {
        abrirPopUpForm(null);
    });

    $("#btnGuardarPersona").click(function () {
        GuardarPersona();
    });

    $("input[name='tipoPersona']").change(function () {
        ajustarCamposPorTipoPersona();
    });

    $("#txtTelefono").val("+595");
    $("#txtTelefono").on("input", function () {
        if (!$(this).val().startsWith("+595")) $(this).val("+595");
    });
});

function CambiarEstado(id, activar) {
    let mensaje = activar ? "activar" : "desactivar";
    let afectarHijos = !activar;

    Swal.fire({
        title: '¿Está seguro?',
        text: `Desea ${mensaje} esta persona?`,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí',
        cancelButtonText: 'No'
    }).then((result) => {
        if (result.isConfirmed) {
            $.ajax({
                url: '/Persona/CambiarEstado',
                type: 'POST',
                data: { id: id, activo: activar, afectarHijos: afectarHijos },
                success: function (resp) {
                    if (resp.resultado) {
                        Swal.fire("Éxito", "Persona actualizada correctamente", "success");
                        $('#tbdata').DataTable().ajax.reload();
                    } else {
                        Swal.fire("Error", resp.mensaje || "No se pudo actualizar", "error");
                    }
                },
                error: function () {
                    Swal.fire("Error", "Ocurrió un error", "error");
                }
            });
        }
    });
}

function abrirPopUpForm(idPersona) {
    $("#form")[0].reset();
    $("#txtTelefono").val("+595");

    if (idPersona == null) {
        $("#txtid").val(0);
        $("#ddlEstado").val("1");
        $("input, select").prop("disabled", false).prop("required", true);
        ajustarCamposPorTipoPersona();
        $("#FormModal").modal("show");
    } else {
        $.get("/Persona/ObtenerPorId", { id: idPersona }, function (data) {
            if (data) {
                $("#txtid").val(data.IdPersona);
                $("#txtDocumento").val(data.Documento);
                $("#txtNombres").val(data.Nombres);
                $("#txtApellidos").val(data.Apellidos);
                $("#txtCorreo").val(data.Correo);
                $("#txtTelefono").val(data.Telefono || "+595");
                $("#txtCallePrincipal").val(data.Calle1);
                $("#txtCalleSecundaria").val(data.Calle2);
                $("#txtCiudad").val(data.Ciudad);
                $("#txtBarrio").val(data.Barrio);
                $("#cboTipoDocumento").val(data.TipoDocumento);
                $("#txtRazonSocial").val(data.RazonSocial);

                $("input[name='tipoPersona'][value='" + (data.TipoDocumento === "RUC" ? "J" : "F") + "']").prop("checked", true);
                ajustarCamposPorTipoPersona();

                $("#FormModal").modal("show");
            }
        });
    }
}

function ajustarCamposPorTipoPersona() {
    let tipo = $("input[name='tipoPersona']:checked").val();

    if (tipo === "F") {
        $("#txtNombres, #txtApellidos").prop("disabled", false);
        $("#txtRazonSocial").prop("disabled", true).val("");
        $("#cboTipoDocumento").empty()
            .append('<option value="CI">CI</option>')
            .append('<option value="RUC">RUC</option>')
            .prop("disabled", false);
    } else if (tipo === "J") {
        $("#txtNombres, #txtApellidos").prop("disabled", true).val("");
        $("#txtRazonSocial").prop("disabled", false);
        $("#cboTipoDocumento").empty()
            .append('<option value="RUC">RUC</option>')
            .prop("disabled", false);
    }
}

function GuardarPersona() {
    var persona = {
        IdPersona: $("#txtid").val(),
        Documento: $("#txtDocumento").val(),
        Nombres: $("#txtNombres").val(),
        Apellidos: $("#txtApellidos").val(),
        Correo: $("#txtCorreo").val(),
        Telefono: $("#txtTelefono").val(),
        Calle1: $("#txtCallePrincipal").val(),
        Calle2: $("#txtCalleSecundaria").val(),
        Ciudad: $("#txtCiudad").val(),
        Barrio: $("#txtBarrio").val(),
        TipoDocumento: $("#cboTipoDocumento").val(),
        RazonSocial: $("#txtRazonSocial").val(),
        Activo: $("#ddlEstado").val() === "1"
    };

    $.ajax({
        url: '/Persona/Guardar',
        type: 'POST',
        data: persona,
        success: function (response) {
            if (response.resultado) {
                Swal.fire("Éxito", response.mensaje, "success");
                $("#FormModal").modal("hide");
                $('#tbdata').DataTable().ajax.reload();
            } else {
                Swal.fire("Atención", response.mensaje, "warning");
            }
        },
        error: function () {
            Swal.fire("Error", "Ocurrió un error al guardar.", "error");
        }
    });
}
