$(document).ready(function () {

    // ── Métodos personalizados ─────────────────────────────
    // Documento: formato según tipo seleccionado (CI o RUC)
    $.validator.addMethod('documentoValido', function (value, element) {
        var tipo = $('#cboTipoDocumento').val();
        value = value.trim();
        if (tipo === 'CI')  return /^\d{6,8}$/.test(value);
        if (tipo === 'RUC') return /^\d{6,8}-\d$/.test(value);
        return true;
    }, function () {
        var tipo = $('#cboTipoDocumento').val();
        return tipo === 'RUC'
            ? 'RUC debe tener formato XXXXXXXX-X (ej: 80012345-1).'
            : 'CI debe tener entre 6 y 8 dígitos numéricos.';
    });

    // Teléfono paraguayo: internacional (+595...) o local (0...), opcional
    $.validator.addMethod('telefonoParaguay', function (value, element) {
        if (this.optional(element)) return true;
        var limpio = value.replace(/\s|-/g, '');
        return /^(\+595\d{6,10}|0\d{8,10})$/.test(limpio);
    }, 'Formato inválido. Ej: +595991234567 o 021123456.');

    // Correo con soporte Unicode (acepta ñ, acentos, etc.)
    $.validator.addMethod('correoUnicode', function (value, element) {
        if (this.optional(element)) return true;
        // Acepta cualquier carácter Unicode antes del @, dominio estándar después
        return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value.trim());
    }, 'Ingresá un correo electrónico válido.');

    $("#form").validate({
        rules: {
            Documento: {
                required: { depends: function (el) { return !$(el).prop('readonly'); } },
                documentoValido: { depends: function (el) { return !$(el).prop('readonly'); } }
            },
            Nombres:      { required: true, minlength: 2, maxlength: 100 },
            Apellidos:    { required: true, minlength: 2, maxlength: 100 },
            RazonSocial:  { required: true, minlength: 2, maxlength: 150 },
            Correo:       { correoUnicode: true, maxlength: 100 },
            Telefono:     { telefonoParaguay: true, maxlength: 20 }
        },
        messages: {
            Documento: { required: "El documento es obligatorio." },
            Nombres:      { required: "El nombre es obligatorio.", minlength: "Debe tener al menos 2 caracteres." },
            Apellidos:    { required: "El apellido es obligatorio.", minlength: "Debe tener al menos 2 caracteres." },
            RazonSocial:  { required: "La razón social es obligatoria.", minlength: "Debe tener al menos 2 caracteres." },
            Correo:       { correoUnicode: "Ingresá un correo electrónico válido." },
            Telefono:     { maxlength: "No puede superar los 20 caracteres." }
        },
        // Los campos deshabilitados (según tipo de persona / modo edición) se ignoran automáticamente.
        errorElement: 'div',
        errorClass: 'invalid-feedback d-block',
        highlight: function (element) { $(element).addClass('is-invalid'); },
        unhighlight: function (element) { $(element).removeClass('is-invalid'); }
    });

    // Revalidar documento al cambiar el tipo (CI ⇄ RUC)
    $('#cboTipoDocumento').on('change', function () {
        if ($('#txtDocumento').val().trim() !== '') $('#txtDocumento').valid();
    });

    // ── DataTable ─────────────────────────────────────────
    var tabla = $('#tbdata').DataTable({
        responsive: true,
        autoWidth: false,
        ajax: { url: $.MisUrls.url._Persona_Obtener, type: 'GET', datatype: 'json' },
        order: [[10, 'desc']],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        columns: [
            { data: 'Nombres', defaultContent: '' },
            { data: 'Apellidos', defaultContent: '' },
            { data: 'RazonSocial', defaultContent: '' },
            { data: 'TipoDocumento', defaultContent: '', width: '80px' },
            { data: 'Documento', defaultContent: '' },
            { data: 'Correo', defaultContent: '' },
            { data: 'Telefono', defaultContent: '' },
            // Dirección — ocultas por defecto, visibles en detalle responsive
            { data: 'Calle1', defaultContent: '', responsivePriority: 10 },
            { data: 'Calle2', defaultContent: '', responsivePriority: 10 },
            { data: 'Ciudad', defaultContent: '', responsivePriority: 10 },
            { data: 'Barrio', defaultContent: '', responsivePriority: 10 },
            {
                data: 'Activo',
                width: '70px',
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">Inactivo</span>';
                }
            },
            {
                data: 'IdPersona',
                orderable: false,
                searchable: false,
                width: '120px',
                render: function (data, type, row) {
                    var btns = '<button class="btn btn-xs btn-info mr-1" onclick=\'verPersona(' + JSON.stringify(row) + ')\' title="Ver detalle">' +
                        '<i class="fa fa-eye"></i></button>';
                    btns += '<button class="btn btn-xs btn-primary mr-1" onclick="abrirPopUpForm(' + data + ')" title="Editar">' +
                        '<i class="fa fa-edit"></i></button>';
                    if (row.Activo) {
                        btns += '<button class="btn btn-xs btn-warning" onclick="CambiarEstado(' + data + ', false)" title="Desactivar">' +
                            '<i class="fa fa-toggle-off"></i></button>';
                    } else {
                        btns += '<button class="btn btn-xs btn-success" onclick="CambiarEstado(' + data + ', true)" title="Activar">' +
                            '<i class="fa fa-check"></i></button>';
                    }
                    return btns;
                }
            }
        ],
        columnDefs: [
            // Prioridades responsive: las más importantes se muestran primero
            { responsivePriority: 1, targets: [0, 3, 4, 12] },   // Nombre, TipoDoc, Doc, Acciones
            { responsivePriority: 2, targets: [1, 2, 5] },        // Apellidos, RazonSocial, Correo
            { responsivePriority: 3, targets: [6] },               // Teléfono
            { responsivePriority: 10, targets: [7, 8, 9, 10] }    // Dirección (colapsa primero
        ]
    });

    // ── Botón agregar ─────────────────────────────────────
    $("#btnAgregarNueva").click(function () {
        abrirPopUpForm(null);
    });

    // ── Botón guardar ─────────────────────────────────────
    $("#btnGuardarPersona").click(function () {
        GuardarPersona();
    });

    // ── Cambio tipo persona ───────────────────────────────
    $("input[name='tipoPersona']").change(function () {
        ajustarCamposPorTipoPersona();
    });

    // ── Teléfono: campo flexible para múltiples formatos ────
    // El campo ahora acepta:
    // - Números locales: 021XXXXXX, 0XXX-XXXXXX, 0XXXXXXXXX
    // - Números internacionales: +595XXXXXXXXX
    // - Campo vacío = teléfono opcional
    // Nota: Sin forzar prefijo +595 para permitir ediciones fluidas

    // ── Hint dinámico según tipo documento ─────────────
    $("#cboTipoDocumento").on("change", function () {
        var tipo = $(this).val();
        if (tipo === "CI") {
            $("#hintDocumento").text("CI: 6-8 dígitos numéricos");
            $("#txtDocumento").attr("placeholder", "Ej: 1234567");
        } else {
            $("#hintDocumento").text("RUC: formato XXXXXXXX-X  (ej: 80012345-1)");
            $("#txtDocumento").attr("placeholder", "Ej: 80012345-1");
        }
        limpiarErrores();
    });

    // ── Documento: solo números para CI ──────────────────
    $("#txtDocumento").on("input", function () {
        var tipo = $("#cboTipoDocumento").val();
        if (tipo === "CI") {
            $(this).val($(this).val().replace(/[^0-9]/g, ''));
        }
    });
});

// ── Ver detalle (solo lectura) ────────────────────────────
function verPersona(json) {
    $("#verTipoDocumento").text(json.TipoDocumento || '—');
    $("#verDocumento").text(json.Documento || '—');
    $("#verNombres").text(json.Nombres || '—');
    $("#verApellidos").text(json.Apellidos || '—');
    $("#verRazonSocial").text(json.RazonSocial || '—');
    $("#verCorreo").text(json.Correo || '—');
    $("#verTelefono").text(json.Telefono || '—');
    $("#verCalle1").text(json.Calle1 || '—');
    $("#verCalle2").text(json.Calle2 || '—');
    $("#verCiudad").text(json.Ciudad || '—');
    $("#verBarrio").text(json.Barrio || '—');
    $("#verEstado").html(json.Activo
        ? '<span class="badge badge-success">Activo</span>'
        : '<span class="badge badge-danger">Inactivo</span>');
    $('#VerModal').modal('show');
}

// ── Cambiar estado activo/inactivo ────────────────────────
function CambiarEstado(id, activar) {
    Swal.fire({
        title: '¿Está seguro?',
        text: 'Desea ' + (activar ? 'activar' : 'desactivar') + ' esta persona?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí',
        cancelButtonText: 'No'
    }).then(function (result) {
        if (result.isConfirmed) {
            $.ajax({
                url: $.MisUrls.url._Persona_CambiarEstado,
                type: 'POST',
                data: { id: id, activo: activar, afectarHijos: true },
                success: function (resp) {
                    if (resp.resultado) {
                        $('#tbdata').DataTable().ajax.reload();
                        if (resp.advertencias && resp.advertencias.length > 0) {
                            // Mostrar éxito y luego lista de alertas por módulo
                            Swal.fire("Desactivado", resp.mensaje, "success").then(function () {
                                var lista = resp.advertencias
                                    .map(function (a) { return '<li style="text-align:left">' + a + '</li>'; })
                                    .join('');
                                Swal.fire({
                                    title: "⚠️ Registros pendientes",
                                    html: '<p style="text-align:left;margin-bottom:8px">Esta persona tenía registros activos en los siguientes módulos. Revisá y reasigná según corresponda:</p><ul style="padding-left:20px">' + lista + '</ul>',
                                    icon: "warning",
                                    confirmButtonText: "Entendido"
                                });
                            });
                        } else {
                            Swal.fire("Éxito", resp.mensaje, "success");
                        }
                    } else {
                        Swal.fire("Error", resp.mensaje || "No se pudo actualizar", "error");
                    }
                },
                error: function () {
                    Swal.fire("Error", "Ocurrió un error de conexión.", "error");
                }
            });
        }
    });
}

// ── Abrir modal ───────────────────────────────────────────
function abrirPopUpForm(idPersona) {
    limpiarErrores();
    $("#form")[0].reset();
    $("#txtTelefono").val("");

    if (idPersona == null) {
        // ── NUEVO ─────────────────────────────────────────
        $("#txtid").val(0);
        $("#ddlEstado").val("1");
        $("#FormModal .modal-title").text("Nueva Persona");

        // Documento editable en alta
        $("#txtDocumento").prop("readonly", false);
        $("#cboTipoDocumento").prop("disabled", false);
        $("input[name='tipoPersona']").prop("disabled", false);

        // Marcar física por defecto
        $("#personaFisica").prop("checked", true);
        ajustarCamposPorTipoPersona();
        $("#FormModal").modal("show");

    } else {
        // ── EDITAR ────────────────────────────────────────
        $.get($.MisUrls.url._Persona_ObtenerPorId, { id: idPersona }, function (data) {
            if (!data) { Swal.fire("Error", "No se encontró la persona.", "error"); return; }

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
            $("#ddlEstado").val(data.Activo ? "1" : "0");

            // Documento e tipo NO se pueden cambiar en edición
            $("#txtDocumento").prop("readonly", true);
            $("#cboTipoDocumento").prop("disabled", true);
            $("input[name='tipoPersona']").prop("disabled", true);

            var tipoRadio = (data.TipoDocumento === "RUC") ? "J" : "F";
            $("input[name='tipoPersona'][value='" + tipoRadio + "']").prop("checked", true);
            ajustarCamposPorTipoPersona();

            $("#FormModal .modal-title").text("Editar Persona");
            $("#FormModal").modal("show");
        });
    }
}

// ── Ajustar campos según tipo de persona ──────────────────
function ajustarCamposPorTipoPersona() {
    var tipo = $("input[name='tipoPersona']:checked").val();
    var esEdicion = $("#txtid").val() > 0;

    if (tipo === "F") {
        $("#txtNombres, #txtApellidos").prop("disabled", false);
        $("#txtRazonSocial").prop("disabled", true).val("");
        if (!esEdicion) {
            $("#cboTipoDocumento").empty()
                .append('<option value="CI">CI</option>')
                .append('<option value="RUC">RUC</option>');
        }
        $("#divNombres, #divApellidos").show();
        $("#divRazonSocial").hide();
    } else {
        $("#txtNombres, #txtApellidos").prop("disabled", true).val("");
        $("#txtRazonSocial").prop("disabled", false);
        if (!esEdicion) {
            $("#cboTipoDocumento").empty()
                .append('<option value="RUC">RUC</option>');
        }
        $("#divNombres, #divApellidos").hide();
        $("#divRazonSocial").show();
    }
}

// ── Validar y guardar ─────────────────────────────────────
function GuardarPersona() {
    if (!$("#form").valid()) return;

    var tipoDoc = $("#cboTipoDocumento").val();
    var doc = $("#txtDocumento").val().trim();
    var correo = $("#txtCorreo").val().trim();
    var tel = $("#txtTelefono").val().trim();

    var persona = {
        IdPersona: $("#txtid").val(),
        Documento: doc,
        Nombres: $("#txtNombres").val().trim(),
        Apellidos: $("#txtApellidos").val().trim(),
        Correo: correo,
        Telefono: tel, // Guardar tal como está, validación ya pasó
        Calle1: $("#txtCallePrincipal").val().trim(),
        Calle2: $("#txtCalleSecundaria").val().trim(),
        Ciudad: $("#txtCiudad").val().trim(),
        Barrio: $("#txtBarrio").val().trim(),
        TipoDocumento: tipoDoc,
        RazonSocial: $("#txtRazonSocial").val().trim(),
        Activo: $("#ddlEstado").val() === "1"
    };

    $.ajax({
        url: $.MisUrls.url._Persona_Guardar,
        type: 'POST',
        data: persona,
        success: function (resp) {
            if (resp.resultado) {
                Swal.fire("Éxito", resp.mensaje, "success");
                $("#FormModal").modal("hide");
                $('#tbdata').DataTable().ajax.reload();
            } else {
                Swal.fire("Atención", resp.mensaje, "warning");
            }
        },
        error: function () {
            Swal.fire("Error", "Ocurrió un error al guardar.", "error");
        }
    });
}

// ── Helper: limpiar estado de validación del formulario ───
function limpiarErrores() {
    if ($("#form").data("validator")) {
        $("#form").validate().resetForm();
    }
    $("#form .is-invalid").removeClass("is-invalid");
}