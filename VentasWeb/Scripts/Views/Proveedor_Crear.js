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
        ajax: {
            url: $.MisUrls.url._ObtenerProveedores,
            type: "GET",
            datatype: "json"
        },
        scrollX: true,
        responsive: false,
        fixedColumns: {
            leftColumns: 1,   // RUC siempre visible a la izquierda
            rightColumns: 1   // Acciones siempre visible a la derecha
        },
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
                    return `
                        <button class='btn btn-info btn-sm' onclick='verDetalle(${rowJson})' title='Ver detalle'>
                            <i class='fas fa-eye'></i>
                        </button>
                        <button class='btn btn-primary btn-sm ml-1' onclick='abrirPopUpForm(${rowJson})' title='Editar'>
                            <i class='fas fa-pen'></i>
                        </button>
                        <button class='btn btn-danger btn-sm ml-1' onclick='eliminar(${data})' title='Eliminar'>
                            <i class='fa fa-trash'></i>
                        </button>`;
                },
                orderable: false,
                searchable: false,
                width: "120px"
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
        $("#txtGeolocalizacion").val("");
    }

    $('#FormModal').modal('show');
}

// ── Guardar ──────────────────────────────────────────────
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

// ── Eliminar ─────────────────────────────────────────────
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