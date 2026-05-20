var tabladata;
var mapForm = null;
var markerForm = null;

$(document).ready(function () {
    activarMenu("Clientes");

    // ── Método: solo letras y espacios ────────────────────────
    $.validator.addMethod('soloLetras', function (value) {
        return /^[a-zA-ZÁÉÍÓÚáéíóúÑñÜü\s]+$/.test(value.trim());
    }, 'Solo se permiten letras y espacios.');

    // ── Método: número de documento según tipo seleccionado ───
    $.validator.addMethod('documentoValido', function (value) {
        var tipo = $('#cboclientetipodocumento').val();
        value = value.trim();
        if (tipo === 'CI')                 return /^\d{6,8}$/.test(value);
        if (tipo === 'RUC')                return /^\d{6,8}-\d$/.test(value);
        if (tipo === 'Carnet Extranjeria') return value.length >= 4;
        return true;
    }, function () {
        var tipo = $('#cboclientetipodocumento').val();
        if (tipo === 'CI')                 return 'CI: ingresá entre 6 y 8 dígitos numéricos.';
        if (tipo === 'RUC')                return 'RUC: formato XXXXXXXX-X (ej: 80012345-1).';
        if (tipo === 'Carnet Extranjeria') return 'Mínimo 4 caracteres.';
        return 'Documento inválido.';
    });

    // ── Método: teléfono paraguayo ────────────────────────────
    $.validator.addMethod('telefonoParaguay', function (value) {
        // Acepta: 0981123456 / 021123456 / 021-123456 / 0981-123456 / +595981123456
        return /^(\+595|0)[\d\-]{7,12}$/.test(value.trim());
    }, 'Ingresá un teléfono válido (ej: 0981-123456 o 021-234567).');

    // ── Validación principal del formulario ───────────────────
    $("#form").validate({
        rules: {
            numerodocumento: { required: true, documentoValido: true },
            nombres:         { required: true, soloLetras: true, minlength: 3 },
            direccion:       { required: true, minlength: 5 },
            telefono:        { required: true, telefonoParaguay: true }
        },
        messages: {
            numerodocumento: { required: 'El número de documento es obligatorio.' },
            nombres:         { required: 'El nombre es obligatorio.', minlength: 'Mínimo 3 caracteres.' },
            direccion:       { required: 'La dirección es obligatoria.', minlength: 'Mínimo 5 caracteres.' },
            telefono:        { required: 'El teléfono es obligatorio.' }
        },
        errorElement: 'small',
        errorClass: 'text-danger d-block',
        highlight: function (element) {
            $(element).addClass('is-invalid').removeClass('is-valid');
        },
        unhighlight: function (element) {
            $(element).addClass('is-valid').removeClass('is-invalid');
        }
    });

    // Revalidar documento al cambiar el tipo (CI → RUC → Carnet)
    $('#cboclientetipodocumento').on('change', function () {
        var $nro = $('#txtNumeroDocumento');
        if ($nro.val().trim() !== '') $nro.valid();

        // Actualizar placeholder según tipo
        var tipo = $(this).val();
        var hint = tipo === 'CI'  ? 'Ej: 1234567'
                 : tipo === 'RUC' ? 'Ej: 80012345-1'
                 :                  'Número de carnet';
        $nro.attr('placeholder', hint);
    }).trigger('change');

    // Inicializar DataTable con scroll horizontal y vertical
    tabladata = $('#tbdata').DataTable({
        ajax: {
            url: $.MisUrls.url._ObtenerClientes,
            type: "GET",
            dataType: "json",
            dataSrc: "data" // Muy importante, porque el JSON viene con estructura { data: [...] }
        },
        columns: [
            { data: "TipoDocumento" },
            { data: "NumeroDocumento" },
            { data: "Nombre" },
            { data: "Direccion" },
            { data: "Telefono" },
            { data: "Ciudad" },
            { data: "Barrio" },
            { data: "Calle" },
            { data: "NumeroCasa" },
            { data: "Referencia" },
            {
                data: "Geolocalizacion",
                render: function (data) {
                    if (data && data.trim() !== "") {
                        return `<button class="btn btn-info btn-sm" onclick="abrirMapaDesdeDataTable('${data}')">Ver Ubicación</button>`;
                    }
                    return "Sin ubicación";
                }
            },
            {
                data: "Activo",
                render: function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            {
                data: "IdCliente",
                render: function (data, type, row) {
                    return "<button class='btn btn-primary btn-sm' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                        "<button class='btn btn-danger btn-sm ml-2' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                },
                orderable: false,
                searchable: false,
                width: "90px"
            }
        ],
        language: {
            url: $.MisUrls.url.Url_datatable_spanish
        },
        scrollX: true,
        scrollY: "400px",
        scrollCollapse: true,
        paging: true
    });

    // Cuando se abre el modal, inicializa el mapa si existe la geolocalización
    $('#FormModal').on('shown.bs.modal', function () {
        abrirMapa();
    });
});

function abrirPopUpForm(json) {
    $("#txtid").val(0);

    if (json != null) {
        $("#txtid").val(json.IdCliente);
        $("#cboclientetipodocumento").val(json.TipoDocumento);
        $("#txtNumeroDocumento").val(json.NumeroDocumento);
        $("#txtNombres").val(json.Nombre);
        $("#txtDireccion").val(json.Direccion);
        $("#txtTelefono").val(json.Telefono);
        $("#txtCiudad").val(json.Ciudad);
        $("#txtBarrio").val(json.Barrio);
        $("#txtCalle").val(json.Calle);
        $("#txtNumeroCasa").val(json.NumeroCasa);
        $("#txtReferencia").val(json.Referencia);
        $("#cboEstado").val(json.Activo ? 1 : 0);
        $("#txtGeolocalizacion").val(json.Geolocalizacion || "");
    } else {
        $("#form")[0].reset();
        $("#cboEstado").val(1);
        $("#txtGeolocalizacion").val("");
        $("#txtBarrio").val("");
        $("#txtCalle").val("");
        $("#txtReferencia").val("");
        $("#txtCiudad").val("");
        $("#txtNumeroCasa").val("");
    }

    $('#FormModal').modal('show');
}

function Guardar() {
    if (!$("#form").valid()) return;

    var request = {
        objeto: {
            IdCliente: parseInt($("#txtid").val()),
            TipoDocumento: $("#cboclientetipodocumento").val(),
            NumeroDocumento: $("#txtNumeroDocumento").val(),
            Nombre: $("#txtNombres").val(),
            Direccion: $("#txtDireccion").val(),
            Telefono: $("#txtTelefono").val(),
            Ciudad: $("#txtCiudad").val(),
            Barrio: $("#txtBarrio").val(),
            Calle: $("#txtCalle").val(),
            NumeroCasa: $("#txtNumeroCasa").val(),
            Referencia: $("#txtReferencia").val(),
            Activo: $("#cboEstado").val() == "1",
            Geolocalizacion: $("#txtGeolocalizacion").val()
        }
    };

    $.ajax({
        url: $.MisUrls.url._GuardarCliente,
        type: "POST",
        data: JSON.stringify(request),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                $('#FormModal').modal('hide');
                toastr.success('Cliente guardado correctamente.');
            } else {
                toastr.error(data.mensaje || 'No se pudo guardar el cliente.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

function eliminar(id) {
    Swal.fire({
        title: '¿Eliminar cliente?',
        text: 'Esta acción no se puede deshacer.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, eliminar',
        confirmButtonColor: '#e74c3c',
        cancelButtonText: 'Cancelar'
    }).then(function (res) {
        if (!res.isConfirmed) return;
        $.ajax({
            url: $.MisUrls.url._EliminarCliente + '?id=' + id,
            type: 'GET',
            dataType: 'json',
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    toastr.success('Cliente eliminado.');
                } else {
                    toastr.error('No se pudo eliminar el cliente.');
                }
            },
            error: function () { toastr.error('Error de conexión.'); }
        });
    });
}


function abrirMapa() {
    $("#mapForm").show();

    if (mapForm !== null) {
        mapForm.remove();
    }

    let geoStr = $("#txtGeolocalizacion").val();
    let lat = -25.2637;   // Asunción default lat
    let lng = -57.5759;   // Asunción default lng

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

    const lat = coords[0];
    const lng = coords[1];

    window.open(`https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=17/${lat}/${lng}`, '_blank');
}