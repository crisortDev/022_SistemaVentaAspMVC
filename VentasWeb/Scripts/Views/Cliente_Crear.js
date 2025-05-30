var tabladata;
var mapForm = null;
var markerForm = null;

$(document).ready(function () {
    activarMenu("Clientes");

    // Validación del formulario con jQuery Validate
    $("#form").validate({
        rules: {
            numerodocumento: "required",
            nombres: "required",
            direccion: "required",
            telefono: "required"
        },
        messages: {
            numerodocumento: "(*)",
            nombres: "(*)",
            direccion: "(*)",
            telefono: "(*)"
        },
        errorElement: 'span'
    });

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
                swal("Éxito", "Los cambios se guardaron correctamente.", "success");
            } else {
                swal("Mensaje", "No se pudo guardar los cambios", "warning");
            }
        }

    });
}

function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el cliente seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Sí",
        cancelButtonText: "No",
        closeOnConfirm: false
    }, function (isConfirm) {
        if (isConfirm) {
            $.ajax({
                url: $.MisUrls.url._EliminarCliente + "?id=" + id,
                type: "GET",
                dataType: "json",
                success: function (data) {
                    if (data.resultado) {
                        tabladata.ajax.reload();
                        swal("Eliminado!", "El cliente ha sido eliminado.", "success");
                    } else {
                        swal("Error", "No se pudo eliminar el cliente.", "error");
                    }
                },
                error: function (err) {
                    console.log("ERROR:", err);
                    swal("Error", "Ocurrió un error en el servidor.", "error");
                }
            });
        }
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