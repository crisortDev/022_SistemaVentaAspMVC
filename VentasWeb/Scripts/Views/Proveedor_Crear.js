let tabladata;
let mapForm = null;
let markerForm = null;

$(document).ready(function () {
    activarMenu("Compras");

    // Método personalizado: solo letras, espacios y caracteres del español
    $.validator.addMethod("soloLetras", function (value, element) {
        return this.optional(element) || /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/.test(value);
    }, "Solo se permiten letras y espacios.");

    // Método personalizado: teléfono (números, espacios, guiones, +)
    $.validator.addMethod("telefonoValido", function (value, element) {
        return this.optional(element) || /^[\d\s\-\+\(\)]+$/.test(value);
    }, "Solo se permiten números, espacios, guiones y paréntesis.");

    // Método personalizado: RUC paraguayo (números y guion opcional)
    $.validator.addMethod("rucValido", function (value, element) {
        return this.optional(element) || /^[\d\-]+$/.test(value);
    }, "El RUC solo puede contener números y guiones.");

    // Validación del formulario
    $("#form").validate({
        rules: {
            RUC: {
                required: true,
                rucValido: true,
                minlength: 5,
                maxlength: 20
            },
            RazonSocial: {
                required: true,
                minlength: 3,
                maxlength: 200
            },
            Telefono: {
                required: true,
                telefonoValido: true,
                minlength: 6,
                maxlength: 20
            },
            Correo: {
                required: true,
                email: true,
                maxlength: 100
            },
            Direccion: {
                required: true,
                minlength: 5,
                maxlength: 200
            },
            Ciudad: {
                required: true,
                soloLetras: true,
                minlength: 3,
                maxlength: 100
            },
            Barrio: {
                maxlength: 100
            },
            Calle: {
                maxlength: 100
            },
            Referencia: {
                maxlength: 200
            }
        },
        messages: {
            RUC: {
                required: "El RUC es obligatorio.",
                rucValido: "Solo se permiten números y guiones (Ej: 80012345-6).",
                minlength: "El RUC debe tener al menos 5 caracteres.",
                maxlength: "El RUC no puede superar los 20 caracteres."
            },
            RazonSocial: {
                required: "La razón social es obligatoria.",
                minlength: "Debe tener al menos 3 caracteres.",
                maxlength: "No puede superar los 200 caracteres."
            },
            Telefono: {
                required: "El teléfono es obligatorio.",
                telefonoValido: "Formato inválido. Solo números, guiones o paréntesis.",
                minlength: "Debe tener al menos 6 dígitos.",
                maxlength: "No puede superar los 20 caracteres."
            },
            Correo: {
                required: "El correo es obligatorio.",
                email: "Ingresá un correo electrónico válido (Ej: nombre@empresa.com).",
                maxlength: "No puede superar los 100 caracteres."
            },
            Direccion: {
                required: "La dirección es obligatoria.",
                minlength: "Debe tener al menos 5 caracteres.",
                maxlength: "No puede superar los 200 caracteres."
            },
            Ciudad: {
                required: "La ciudad es obligatoria.",
                soloLetras: "La ciudad solo puede contener letras y espacios.",
                minlength: "Debe tener al menos 3 caracteres.",
                maxlength: "No puede superar los 100 caracteres."
            },
            Barrio:     { maxlength: "No puede superar los 100 caracteres." },
            Calle:      { maxlength: "No puede superar los 100 caracteres." },
            Referencia: { maxlength: "No puede superar los 200 caracteres." }
        },
        errorElement: 'span',
        errorClass: 'text-danger small',
        highlight: function (element) {
            $(element).addClass('is-invalid');
        },
        unhighlight: function (element) {
            $(element).removeClass('is-invalid');
        }
    });

    tabladata = $('#tbdata').DataTable({
        ajax: {
            url: $.MisUrls.url._ObtenerProveedores,
            type: "GET",
            datatype: "json"
        },
        scrollX: true,
        responsive: false,
        columns: [
            { data: "Ruc" },
            { data: "RazonSocial" },
            { data: "Telefono" },
            { data: "Correo" },
            { data: "Ciudad" },
            {
                data: "Activo",
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                data: "Geolocalizacion",
                render: function (data) {
                    if (!data || !data.includes(','))
                        return '<span class="text-muted">Sin ubicación</span>';
                    return `<button class='btn btn-info btn-sm' onclick='abrirMapaDesdeDataTable("${data}")'>
                                <i class='fas fa-map-marker-alt'></i> Ver Mapa
                            </button>`;
                },
                orderable: false,
                searchable: false
            },
            {
                data: "IdProveedor",
                render: function (data, type, row) {
                    var rowJson = JSON.stringify(row).replace(/'/g, "\\'");
                    var btnReactivar = !row.Activo
                        ? `<button class='btn btn-success btn-sm ml-1' onclick='reactivar(${data})' title='Reactivar'>
                               <i class='fas fa-redo'></i>
                           </button>`
                        : '';
                    // Botón eliminar/desactivar: visible para todos; el server rechaza eliminación física si no es SuperAdmin
                    var btnEliminar = `<button class='btn btn-danger btn-sm ml-1' onclick='eliminar(${data})' title='Eliminar/Desactivar'>
                            <i class='fa fa-trash'></i>
                        </button>`;
                    return `
                        <button class='btn btn-info btn-sm' onclick='verDetalle(${rowJson})' title='Ver detalle'>
                            <i class='fas fa-eye'></i>
                        </button>
                        <button class='btn btn-primary btn-sm ml-1' onclick='abrirPopUpForm(${rowJson})' title='Editar'>
                            <i class='fas fa-pen'></i>
                        </button>
                        ${btnEliminar}
                        ${btnReactivar}`;
                },
                orderable: false,
                searchable: false,
                width: "150px"
            }
        ],
        language: {
            url: $.MisUrls.url.Url_datatable_spanish
        }
    });

    $('#FormModal').on('shown.bs.modal', function () {
        abrirMapa();
    });
});

// ── Ver detalle (solo lectura) ────────────────────────────
function verDetalle(row) {
    $('#detRuc').text(row.Ruc || '-');
    $('#detRazonSocial').text(row.RazonSocial || '-');
    $('#detTelefono').text(row.Telefono || '-');
    $('#detCorreo').text(row.Correo || '-');
    $('#detDireccion').text(row.Direccion || '-');
    $('#detCiudad').text(row.Ciudad || '-');
    $('#detBarrio').text(row.Barrio || '-');
    $('#detCalle').text(row.Calle || '-');
    $('#detReferencia').text(row.Referencia || '-');
    $('#detEstado').html(row.Activo
        ? '<span class="badge badge-success">Activo</span>'
        : '<span class="badge badge-danger">No Activo</span>');

    if (row.Geolocalizacion && row.Geolocalizacion.includes(',')) {
        var partes = row.Geolocalizacion.split(',');
        var lat = partes[0];
        var lng = partes[1];
        $('#detGeo').html(
            `${row.Geolocalizacion} &nbsp;
             <a href='https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=17/${lat}/${lng}'
                target='_blank' class='btn btn-sm btn-outline-info'>
                 <i class='fas fa-map-marker-alt'></i> Ver mapa
             </a>`
        );
    } else {
        $('#detGeo').text('-');
    }

    $('#ModalDetalle').modal('show');
}

// ── Abrir formulario nuevo / editar ──────────────────────
function abrirPopUpForm(json) {
    $("#txtid").val(0);
    $("#form").validate().resetForm();
    $("#form .is-invalid").removeClass("is-invalid");

    if (json != null) {
        $("#txtid").val(json.IdProveedor);
        $("#txtRuc").val(json.Ruc).prop("readonly", true);
        $("#txtRazonSocial").val(json.RazonSocial);
        $("#txtTelefono").val(json.Telefono);
        $("#txtCorreo").val(json.Correo);
        $("#txtDireccion").val(json.Direccion);
        $("#cboEstado").val(json.Activo ? 1 : 0);
        $("#txtCiudad").val(json.Ciudad);
        $("#txtBarrio").val(json.Barrio);
        $("#txtCalle").val(json.Calle);
        $("#txtReferencia").val(json.Referencia);
        $("#txtGeolocalizacion").val(json.Geolocalizacion);
    } else {
        $("#form")[0].reset();
        $("#cboEstado").val(1);
        $("#txtid").val(0);
        $("#txtRuc").prop("readonly", false);
        $("#txtBarrio").val("");
        $("#txtCalle").val("");
        $("#txtReferencia").val("");
        $("#txtGeolocalizacion").val("");
    }

    $('#FormModal').modal('show');
}

// ── Guardar ──────────────────────────────────────────────
function Guardar() {
    if (!$("#form").valid()) return;

    const esNuevo = parseInt($("#txtid").val()) === 0;
    const ruc = $("#txtRuc").val().trim();

    // Validar RUC duplicado solo al crear
    if (esNuevo) {
        $.ajax({
            url: $.MisUrls.url._VerificarRucProveedor + "?ruc=" + encodeURIComponent(ruc),
            type: "GET",
            dataType: "json",
            success: function (resp) {
                if (resp.existe) {
                    Swal.fire('RUC duplicado', 'Ya existe un proveedor registrado con el RUC <strong>' + ruc + '</strong>. Por favor verificá los datos.', 'warning');
                } else {
                    enviarGuardar();
                }
            },
            error: function () { enviarGuardar(); }
        });
    } else {
        enviarGuardar();
    }
}

function enviarGuardar() {
    const request = {
        objeto: {
            IdProveedor: parseInt($("#txtid").val()),
            Ruc: $("#txtRuc").val(),
            RazonSocial: $("#txtRazonSocial").val(),
            Telefono: $("#txtTelefono").val(),
            Correo: $("#txtCorreo").val(),
            Direccion: $("#txtDireccion").val(),
            Activo: $("#cboEstado").val() == "1",
            Ciudad: $("#txtCiudad").val(),
            Barrio: $("#txtBarrio").val(),
            Calle: $("#txtCalle").val(),
            Referencia: $("#txtReferencia").val(),
            Geolocalizacion: $("#txtGeolocalizacion").val()
        }
    };

    $.ajax({
        url: $.MisUrls.url._GuardarProveedor,
        type: "POST",
        data: JSON.stringify(request),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                $('#FormModal').modal('hide');
                Swal.fire('Éxito', 'Proveedor guardado correctamente.', 'success');
            } else {
                Swal.fire('Atención', data.mensaje || 'No se pudo guardar los cambios.', 'warning');
            }
        },
        error: function (err) {
            Swal.fire('Error', 'Ocurrió un error al guardar.', 'error');
        }
    });
}

// ── Eliminar (con verificación de compras) ───────────────
function eliminar(id) {
    // Primero verificar si el proveedor tiene compras registradas
    $.ajax({
        url: $.MisUrls.url._TieneComprasProveedor + "?id=" + id,
        type: "GET",
        dataType: "json",
        success: function (data) {
            if (data.tieneCompras) {
                // Tiene compras — solo se puede desactivar
                Swal.fire({
                    title: 'Proveedor con compras',
                    text: 'Este proveedor tiene compras registradas y no puede eliminarse. ¿Desea desactivarlo?',
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonText: 'Sí, desactivar',
                    confirmButtonColor: '#e0a800',
                    cancelButtonText: 'Cancelar'
                }).then(function (result) {
                    if (result.isConfirmed) {
                        $.ajax({
                            url: $.MisUrls.url._DesactivarProveedor,
                            type: "POST",
                            data: { id: id },
                            dataType: "json",
                            success: function (resp) {
                                if (resp.resultado) {
                                    tabladata.ajax.reload();
                                    Swal.fire('Desactivado', 'El proveedor fue desactivado.', 'success');
                                } else {
                                    Swal.fire('Error', 'No se pudo desactivar el proveedor.', 'error');
                                }
                            }
                        });
                    }
                });
            } else {
                // Sin compras — se puede eliminar
                Swal.fire({
                    title: '¿Eliminar proveedor?',
                    text: 'Esta acción no se puede deshacer.',
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonText: 'Sí, eliminar',
                    confirmButtonColor: '#DD6B55',
                    cancelButtonText: 'Cancelar'
                }).then(function (result) {
                    if (result.isConfirmed) {
                        $.ajax({
                            url: $.MisUrls.url._EliminarProveedor,
                            type: "POST",
                            data: { id: id },
                            dataType: "json",
                            success: function (resp) {
                                if (resp.resultado) {
                                    tabladata.ajax.reload();
                                    Swal.fire('Eliminado', resp.mensaje, 'success');
                                } else {
                                    Swal.fire('No se pudo eliminar', resp.mensaje || 'No tiene permisos para realizar esta acción.', 'warning');
                                }
                            }
                        });
                    }
                });
            }
        },
        error: function () {
            Swal.fire('Error', 'No se pudo verificar el estado del proveedor.', 'error');
        }
    });
}

// ── Reactivar proveedor ──────────────────────────────────
function reactivar(id) {
    Swal.fire({
        title: '¿Reactivar proveedor?',
        text: 'El proveedor volverá a estar disponible en el sistema.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, reactivar',
        confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (result) {
        if (result.isConfirmed) {
            $.ajax({
                url: $.MisUrls.url._ReactivarProveedor,
                type: "POST",
                data: { id: id },
                dataType: "json",
                success: function (resp) {
                    if (resp.resultado) {
                        tabladata.ajax.reload();
                        Swal.fire('Reactivado', 'El proveedor fue reactivado correctamente.', 'success');
                    } else {
                        Swal.fire('Error', 'No se pudo reactivar el proveedor.', 'error');
                    }
                },
                error: function () {
                    Swal.fire('Error', 'Error al conectar con el servidor.', 'error');
                }
            });
        }
    });
}

// ── Mapa dentro del formulario ───────────────────────────
function abrirMapa() {
    if (mapForm !== null) {
        mapForm.remove();
    }

    let geoStr = $("#txtGeolocalizacion").val();
    let lat = -25.2637;
    let lng = -57.5759;

    if (geoStr && geoStr.includes(",")) {
        const parts = geoStr.split(",");
        const latTmp = parseFloat(parts[0]);
        const lngTmp = parseFloat(parts[1]);
        if (!isNaN(latTmp) && !isNaN(lngTmp)) {
            lat = latTmp;
            lng = lngTmp;
        }
    }

    mapForm = L.map('mapForm').setView([lat, lng], 13);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18
    }).addTo(mapForm);

    markerForm = L.marker([lat, lng], { draggable: true }).addTo(mapForm);

    markerForm.on('moveend', function (e) {
        const pos = e.target.getLatLng();
        $("#txtGeolocalizacion").val(`${pos.lat},${pos.lng}`);
    });

    mapForm.on('click', function (e) {
        markerForm.setLatLng(e.latlng);
        $("#txtGeolocalizacion").val(`${e.latlng.lat},${e.latlng.lng}`);
    });

    setTimeout(() => {
        mapForm.invalidateSize();
    }, 300);
}

// ── Abrir mapa externo desde la tabla ───────────────────
function abrirMapaDesdeDataTable(coordenadas) {
    if (!coordenadas || !coordenadas.includes(',')) {
        alert("Coordenadas no disponibles o inválidas.");
        return;
    }

    const coords = coordenadas.trim().split(',').map(parseFloat);

    if (isNaN(coords[0]) || isNaN(coords[1])) {
        alert("Coordenadas no válidas.");
        return;
    }

    window.open(
        `https://www.openstreetmap.org/?mlat=${coords[0]}&mlon=${coords[1]}#map=17/${coords[0]}/${coords[1]}`,
        '_blank'
    );
}