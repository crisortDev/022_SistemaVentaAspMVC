var tabladata;

$(document).ready(function () {
    activarMenu("Mantenedor");

    // ================== VALIDACIONES ==================
    $("#form").validate({
        rules: {
            Nombres: { required: true, minlength: 2, maxlength: 50 },
            Apellidos: { required: true, minlength: 2, maxlength: 50 },
            CI: { required: true, minlength: 1, maxlength: 15 },
            Correo: { required: true, email: true, maxlength: 50 },
            Clave: {
                required: function () { return $("#txtid").val() == "0"; },
                minlength: 6,
                maxlength: 8
            }
        },
        messages: {
            Nombres: { required: "Ingrese nombres", minlength: "Mínimo 2 caracteres", maxlength: "Máximo 50 caracteres" },
            Apellidos: { required: "Ingrese apellidos", minlength: "Mínimo 2 caracteres", maxlength: "Máximo 50 caracteres" },
            CI: { required: "Ingrese CI", minlength: "Debe tener al menos 1 carácter", maxlength: "Máximo 15 caracteres" },
            Correo: { required: "Ingrese correo", email: "Formato de correo inválido", maxlength: "Máximo 50 caracteres" },
            Clave: { required: "Ingrese contraseña", minlength: "Mínimo 6 caracteres", maxlength: "Máximo 8 caracteres" }
        },
        errorElement: 'span',
        errorPlacement: function (error, element) {
            error.addClass("text-danger ml-2");
            error.insertAfter(element);
        }
    });

    // ================== CARGA DE SELECTS ==================
    cargarSelect("#cboRol", $.MisUrls.url._ObtenerRoles, "Descripcion", "IdRol");
    cargarSelect("#cboTienda", $.MisUrls.url._ObtenerTiendas, "Nombre", "IdTienda");

    // ================== BÚSQUEDA EMPLEADO ==================
    $('#btnBuscarEmpleado').click(function () {
        var ci = $('#txtCIEmpleado').val().trim();
        if (ci === '') return;

        $.ajax({
            url: $.MisUrls.url._BuscarEmpleadoPorCI,
            type: "GET",
            data: { ci: ci },
            dataType: "json",
            success: function (res) {
                if (!res.data || res.data.length === 0) {
                    alert("No se encontraron empleados.");
                    $('#camposUsuario').hide();
                    $('#cboEmpleado').empty().append('<option value="">Seleccione un empleado</option>');
                    return;
                }

                var empleados = res.data;

                // Limpiar y llenar select con todos los resultados
                $('#cboEmpleado').empty();
                empleados.forEach(function (emp) {
                    $('#cboEmpleado').append('<option value="' + emp.IdEmpleado + '">' + emp.CI + ' - ' + emp.Nombres + ' ' + emp.Apellidos + '</option>');
                });

                // Seleccionar el primer empleado por defecto
                var persona = empleados[0];
                $('#cboEmpleado').val(persona.IdEmpleado);

                // Mostrar campos de usuario
                $('#camposUsuario').show();

                // Rellenar campos de usuario
                $('#txtNombres').val(persona.Nombres).prop('required', true);
                $('#txtApellidos').val(persona.Apellidos).prop('required', true);
                $('#txtCI').val(persona.CI);
                $('#txtCorreo').val(persona.Correo || '');
            },
            error: function (err) {
                console.error(err);
                alert("Error al buscar empleado.");
            }
        });
    });


    // ================== DATATABLE ==================
    tabladata = $('#tbdata').DataTable({
        ajax: { url: $.MisUrls.url._ObtenerUsuarios, type: "GET", datatype: "json" },
        columns: [
            { data: "oRol", render: data => data.Descripcion },
            { data: "Nombres" },
            { data: "Apellidos" },
            { data: "Correo" },
            { data: "Activo", render: data => data ? '<span class="badge badge-success">Activo</span>' : '<span class="badge badge-danger">No Activo</span>' },
            {
                data: "IdUsuario", render: (data, type, row) => `
                    <button class='btn btn-primary btn-sm' onclick='abrirPopUpForm(${JSON.stringify(row)})'><i class='fas fa-pen'></i></button>
                    <button class='btn btn-danger btn-sm ml-2' onclick='eliminar(${data})'><i class='fa fa-trash'></i></button>
                `, orderable: false, searchable: false, width: "90px"
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true
    });
});

// ================== FUNCIONES AUXILIARES ==================
function cargarSelect(selector, url, textField, valueField) {
    $.ajax({
        url: url,
        type: "GET",
        dataType: "json",
        success: function (data) {
            $(selector).html("");
            if (data.data) {
                data.data.filter(x => x.Activo).forEach(item => {
                    $("<option>").val(item[valueField]).text(item[textField]).appendTo(selector);
                });
                $(selector).val($(selector + " option:first").val());
            }
        },
        error: function (err) {
            console.error("Error cargando select: ", err);
        }
    });
}

// ================== ABRIR MODAL ==================
function abrirPopUpForm(json) {
    const esEdicion = json != null;

    $("#txtid").val(esEdicion ? json.IdUsuario : 0);
    $("#empleadoGroup").toggle(!esEdicion);
    $("#camposUsuario").toggle(esEdicion);
    $("#claveGroup").toggle(!esEdicion);

    if (esEdicion) {
        $("#txtNombres").val(json.Nombres);
        $("#txtApellidos").val(json.Apellidos);
        $("#txtCI").val(json.CI).prop("readonly", true);
        $("#txtCorreo").val(json.Correo);
        $("#txtClave").val("********").prop("disabled", true);
        $("#cboTienda").val(json.IdTienda);
        $("#cboRol").val(json.IdRol);
        $("#cboEstado").val(json.Activo ? 1 : 0);

        if (json.IdEmpleado) {
            var option = new Option(json.CI + " - " + json.Nombres + " " + json.Apellidos, json.IdEmpleado, true, true);
            $("#cboEmpleado").append(option).trigger('change');
        } else {
            $("#cboEmpleado").val("").trigger('change');
        }
    } else {
        $("#txtNombres, #txtApellidos, #txtCI, #txtCorreo, #txtClave").val("").prop("readonly", false).prop("disabled", false);
        $("#cboTienda, #cboRol").val(function () { return $(this).find("option:first").val(); });
        $("#cboEmpleado").empty().append('<option value="">Seleccione un empleado</option>');
        $("#txtCIEmpleado").val("");
        $("#cboEstado").val(1);
    }

    $('#FormModal').modal('show');
}

// ================== GUARDAR ==================
function Guardar() {
    if (!$("#form").valid()) return;

    let request = {
        IdEmpleado: $("#cboEmpleado").val(),
        Nombres: $("#txtNombres").val(),
        Apellidos: $("#txtApellidos").val(),
        CI: $("#txtCI").val(),
        Correo: $("#txtCorreo").val(),
        IdTienda: $("#cboTienda").val(),
        IdRol: $("#cboRol").val()
    };

    $.ajax({
        url: $.MisUrls.url._CrearUsuarioPendiente,
        type: "POST",
        data: JSON.stringify(request),
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (res) {
            if (res.resultado) {
                swal("Éxito", res.mensaje, "success");
                $('#FormModal').modal('hide');
                tabladata.ajax.reload();
            } else {
                swal("Error", res.mensaje, "warning");
            }
        },
        error: function (xhr, status, error) {
            console.error("Status: ", status);
            console.error("Error: ", error);
            console.error("ResponseText: ", xhr.responseText);
            swal("Error", "Error al guardar usuario: " + error, "error");
        }
    });
}

// ================== ELIMINAR ==================
function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el usuario seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No",
        closeOnConfirm: true
    }, function () {
        $.ajax({
            url: $.MisUrls.url._EliminarUsuario,
            type: "GET",
            data: { id: id },
            dataType: "json",
            success: data => {
                if (data.resultado) tabladata.ajax.reload();
                else swal("Mensaje", "No se pudo eliminar el usuario", "warning");
            },
            error: function (err) {
                console.error("Error eliminando usuario: ", err);
            }
        });
    });
}

// ================== ACTIVAR MENU ==================
function activarMenu(menuactivo) {
    $("ul.navbar-nav li.nav-item").each(function () {
        const a = $(this).find("a.nav-link");
        const div = $(this).find("div.dropdown-menu");

        if (div.length) {
            div.find("a.dropdown-item").each(function () {
                if ($(this).attr("name") === menuactivo) {
                    $(this).closest("li.nav-item").addClass("active");
                    return false;
                }
            });
        } else if (a.attr("name") === menuactivo) {
            $(this).addClass("active");
        }
    });
}
