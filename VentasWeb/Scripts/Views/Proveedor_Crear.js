let tabladata;
let mapForm = null;
let markerForm = null;

$(document).ready(function () {
    activarMenu("Compras");

    // Validación del formulario
    $("#form").validate({
        rules: {
            RUC: "required",
            RazonSocial: "required",
            Telefono: "required",
            Correo: "required",
            Direccion: "required",
            Ciudad: "required"
        },
        messages: {
            RUC: "(*)",
            RazonSocial: "(*)",
            Telefono: "(*)",
            Correo: "(*)",
            Direccion: "(*)",
            Ciudad: "(*)"
        },
        errorElement: 'span'
    });

    tabladata = $('#tbdata').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProveedores,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "Ruc" },
            { "data": "RazonSocial" },
            { "data": "Telefono" },
            { "data": "Correo" },
            { "data": "Direccion" },
            { "data": "Barrio" },
            { "data": "Calle" },
            { "data": "Referencia" },
            {
                "data": "Activo",
                "render": function (data) {
                    return data
                        ? '<span class="badge badge-success">Activo</span>'
                        : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            { "data": "Ciudad" },
            {
                "data": "Geolocalizacion",
                "render": function (data) {
                    return `<button class='btn btn-info btn-sm' onclick='abrirMapaDesdeDataTable("${data}")'>Ver en Mapa</button>`;
                }
            },
            {
                "data": "IdProveedor",
                "render": function (data, type, row) {
                    return `
                    <button class='btn btn-primary btn-sm' onclick='abrirPopUpForm(${JSON.stringify(row)})'>
                        <i class='fas fa-pen'></i>
                    </button>
                    <button class='btn btn-danger btn-sm ml-2' onclick='eliminar(${data})'>
                        <i class='fa fa-trash'></i>
                    </button>`;
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        scrollX: true,   // Habilitar scroll horizontal
        responsive: false
    });



    $('#FormModal').on('shown.bs.modal', function () {
        abrirMapa();
    });
});

function abrirPopUpForm(json) {
    $("#txtid").val(0);

    if (json != null) {
        $("#txtid").val(json.IdProveedor);
        $("#txtRuc").val(json.Ruc);
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
        $("#txtBarrio").val("");
        $("#txtCalle").val("");
        $("#txtReferencia").val("");
        $("#txtGeolocalizacion").val("");  // Limpia ubicación si es nuevo
    }

    $('#FormModal').modal('show');
}


function Guardar() {
    if (!$("#form").valid()) return;

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
            } else {
                swal("Mensaje", "No se pudo guardar los cambios", "warning");
            }
        },
        error: function (err) {
            console.log("ERROR:", err);
        }
    });
}

function eliminar(id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el proveedor seleccionado?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No"
    }, function () {
        $.ajax({
            url: $.MisUrls.url._EliminarProveedor + "?id=" + id,
            type: "GET",
            dataType: "json",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                } else {
                    swal("Mensaje", "No se pudo eliminar el proveedor", "warning");
                }
            },
            error: function (err) {
                console.log("ERROR:", err);
            }
        });
    });
}

function abrirMapa() {
    if (mapForm !== null) {
        mapForm.remove();
    }

    // Obtener coordenadas guardadas o establecer valores por defecto
    let geoStr = $("#txtGeolocalizacion").val();
    let lat = -25.2637;   // default Lat (Asunción Paraguay)
    let lng = -57.5759;   // default Lng

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

    // Actualizar coordenadas al mover el marcador
    markerForm.on('moveend', function (e) {
        const pos = e.target.getLatLng();
        $("#txtGeolocalizacion").val(`${pos.lat},${pos.lng}`);
    });

    // También permitir seleccionar ubicación con click en el mapa
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

function geolocalizarDireccion(direccion) {
    const apiKey = "66a0018652cf42cb97c4f2e3909abb1d";
    const url = `https://api.opencagedata.com/geocode/v1/json?q=${encodeURIComponent(direccion)}&key=${apiKey}`;

    $.getJSON(url, function (data) {
        if (data.results.length > 0) {
            const latlng = data.results[0].geometry;
            $("#txtGeolocalizacion").val(`${latlng.lat},${latlng.lng}`);
        } else {
            alert("No se pudo obtener la ubicación.");
        }
    });
}
