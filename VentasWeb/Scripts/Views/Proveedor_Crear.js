
var tabladata;
$(document).ready(function () {
    activarMenu("Compras");

    // Validar el formulario
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
            {
                "data": "Activo",
                "render": function (data) {
                    return data ? '<span class="badge badge-success">Activo</span>' : '<span class="badge badge-danger">No Activo</span>';
                }
            },
            { "data": "Ciudad" }, // Columna Ciudad
            {
                "data": "Geolocalizacion",
                "render": function (data) {
                    // Renderizar el botón que lleva a la ubicación en el mapa
                    return "<button class='btn btn-info btn-sm' onclick='abrirMapaDesdeDataTable(\"" + data + "\")'>Ver en Mapa</button>";
                }
            },
            {
                "data": "IdProveedor",
                "render": function (data, type, row, meta) {
                    return "<button class='btn btn-primary btn-sm' type='button' onclick='abrirPopUpForm(" + JSON.stringify(row) + ")'><i class='fas fa-pen'></i></button>" +
                        "<button class='btn btn-danger btn-sm ml-2' type='button' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>"
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });
})


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
        $("#txtCiudad").val(json.Ciudad); // Cambiar de NuevoCampo a Ciudad
        $("#txtGeolocalizacion").val(json.Geolocalizacion); // Mantener para guardar
    } else {
        $("#txtRuc").val("");
        $("#txtRazonSocial").val("");
        $("#txtTelefono").val("");
        $("#txtCorreo").val("");
        $("#txtDireccion").val("");
        $("#cboEstado").val(1);
        $("#txtCiudad").val("");
        $("#txtGeolocalizacion").val(""); // Mantener para guardar
    }

    $('#FormModal').modal('show');
}


function Guardar() {

    if ($("#form").valid()) {

        var request = {
            objeto: {
                IdProveedor: parseInt($("#txtid").val()),
                Ruc: $("#txtRuc").val(),
                RazonSocial: $("#txtRazonSocial").val(),
                Telefono: $("#txtTelefono").val(),
                Correo: $("#txtCorreo").val(),
                Direccion: $("#txtDireccion").val(),
                Activo: parseInt($("#cboEstado").val()) == 1 ? true : false,
                Ciudad: $("#txtCiudad").val(), // Agregar el nuevo campo aquí
                Geolocalizacion: $("#txtGeolocalizacion").val() // Agregar el nuevo campo aquí
            }
        }

        jQuery.ajax({
            url: $.MisUrls.url._GuardarProveedor,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {

                if (data.resultado) {
                    tabladata.ajax.reload();
                    $('#FormModal').modal('hide');
                } else {

                    swal("Mensaje", "No se pudo guardar los cambios", "warning")
                }
            },
            error: function (error) {
                console.log(error)
            },
            beforeSend: function () {

            },
        });

    }

}


function eliminar($id) {


    swal({
        title: "Mensaje",
        text: "¿Desea eliminar el proveedor seleccionado?",
        type: "warning",
        showCancelButton: true,

        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",

        cancelButtonText: "No",

        closeOnConfirm: true
    },

        function () {
            jQuery.ajax({
                url: $.MisUrls.url._EliminarProveedor + "?id=" + $id,
                type: "GET",
                dataType: "json",
                contentType: "application/json; charset=utf-8",
                success: function (data) {

                    if (data.resultado) {
                        tabladata.ajax.reload();
                    } else {
                        swal("Mensaje", "No se pudo eliminar el proveedor", "warning")
                    }
                },
                error: function (error) {
                    console.log(error)
                },
                beforeSend: function () {

                },
            });
        });

}

function abrirMapa() {
    // Crear un mapa y establecer su vista inicial
    var map = L.map('map').setView([-34.90, -56.18], 13); // Cambia las coordenadas a las que desees

    // Agregar una capa de OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
    }).addTo(map);

    // Agregar un marcador al mapa
    var marker = L.marker([-34.90, -56.18]).addTo(map); // Cambia las coordenadas por defecto

    // Al hacer clic en el mapa, actualizar el marcador y el campo de geolocalización
    map.on('click', function (e) {
        marker.setLatLng(e.latlng);
        document.getElementById('txtGeolocalizacion').value = e.latlng.lat + ',' + e.latlng.lng; // Guardar lat, lng en el campo
    });
}

// Función para abrir el mapa con coordenadas desde DataTable
function abrirMapaDesdeDataTable(coordenadas) {
    if (coordenadas) {
        var coords = coordenadas.split(','); // Suponiendo que las coordenadas están en formato "lat,lng"
        var lat = parseFloat(coords[0]);
        var lng = parseFloat(coords[1]);

        // Redirigir a OpenStreetMap con las coordenadas específicas
        window.open(`https://www.openstreetmap.org/#map=13/${lat}/${lng}`, '_blank');
    } else {
        alert("Coordenadas no disponibles.");
    }
}

$('#mapModal').on('shown.bs.modal', function () {
    // Reinicializar el mapa
    abrirMapaDesdeDataTable(coordenadas);
});
