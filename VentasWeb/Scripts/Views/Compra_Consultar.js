var tabladata;

$(document).ready(function () {
    activarMenu("Compras");

    $.datepicker.regional['es'] = {
        closeText: 'Cerrar',
        prevText: '< Ant',
        nextText: 'Sig >',
        currentText: 'Hoy',
        monthNames: ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'],
        monthNamesShort: ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'],
        dayNames: ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'],
        dayNamesShort: ['Dom', 'Lun', 'Mar', 'Mié', 'Juv', 'Vie', 'Sáb'],
        dayNamesMin: ['Do', 'Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá'],
        weekHeader: 'Sm',
        dateFormat: 'dd/mm/yy',
        firstDay: 1,
        isRTL: false,
        showMonthAfterYear: false,
        yearSuffix: ''
    };
    $.datepicker.setDefaults($.datepicker.regional['es']);

    $("#txtFechaInicio").datepicker();
    $("#txtFechaFin").datepicker();
    $("#txtFechaInicio").val(ObtenerFecha());
    $("#txtFechaFin").val(ObtenerFecha());

    // ── Ocultar combo tienda si no es SuperAdmin ──────────
    if (!AppSession.esSuperAdmin) {
        $("#divFiltroTienda").hide();
    }

    // OBTENER PROVEEDORES
    jQuery.ajax({
        url: $.MisUrls.url._ObtenerProveedores,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            $("#cboProveedor").LoadingOverlay("hide");
            $("#cboProveedor").html("");
            $("<option>").attr({ "value": 0 }).text("-- Seleccionar todas--").appendTo("#cboProveedor");
            if (data.data != null)
                $.each(data.data, function (i, item) {
                    if (item.Activo == true) {
                        $("<option>").attr({ "value": item.IdProveedor }).text(item.RazonSocial).appendTo("#cboProveedor");
                    }
                });
        },
        error: function (error) { console.log(error); },
        beforeSend: function () { $("#cboProveedor").LoadingOverlay("show"); }
    });

    // ── Cargar tiendas solo si es SuperAdmin ──────────────
    if (AppSession.esSuperAdmin) {
        jQuery.ajax({
            url: $.MisUrls.url._ObtenerTiendas,
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                $("#cboTienda").LoadingOverlay("hide");
                $("#cboTienda").html("");
                $("<option>").attr({ "value": 0 }).text("-- Seleccionar todas--").appendTo("#cboTienda");
                if (data.data != null)
                    $.each(data.data, function (i, item) {
                        if (item.Activo == true) {
                            $("<option>").attr({ "value": item.IdTienda }).text(item.Nombre).appendTo("#cboTienda");
                        }
                    });
            },
            error: function (error) { console.log(error); },
            beforeSend: function () { $("#cboTienda").LoadingOverlay("show"); }
        });
    }

    // ── Carga inicial de la tabla ─────────────────────────
    var idTiendaInicial = AppSession.esSuperAdmin ? 0 : AppSession.idTienda;

    tabladata = $('#tbCompras').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerCompras +
                "?fechainicio=" + ObtenerFecha() +
                "&fechafin=" + ObtenerFecha() +
                "&idproveedor=0" +
                "&idtienda=" + idTiendaInicial,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdCompra", render: function (data) {
                    return "<button class='btn btn-success btn-sm ml-2' type='button' onclick='Imprimir(" + data + ")'><i class='far fa-clipboard'></i> Ver</button>";
                }
            },
            { "data": "NumeroCompra" },
            {
                "data": "oProveedor", render: function (data) {
                    return data.RazonSocial;
                }
            },
            {
                "data": "oTienda", render: function (data) {
                    return data.Nombre;
                }
            },
            { "data": "FechaCompra" },
            {
                "data": "TotalCosto", render: function (data) {
                    return "G./ " + (data).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,");
                }
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });
});


function buscar() {
    if ($("#txtFechaInicio").val().trim() == "" || $("#txtFechaFin").val().trim() == "") {
        swal("Mensaje", "Debe ingresar fechas", "warning");
        return;
    }

    // ── Si no es SuperAdmin, usar su propia tienda ────────
    var idTienda = AppSession.esSuperAdmin ? $("#cboTienda").val() : AppSession.idTienda;

    tabladata.ajax.url(
        $.MisUrls.url._ObtenerCompras +
        "?fechainicio=" + $("#txtFechaInicio").val().trim() +
        "&fechafin=" + $("#txtFechaFin").val().trim() +
        "&idproveedor=" + $("#cboProveedor").val() +
        "&idtienda=" + idTienda
    ).load();
}

function ObtenerFecha() {
    var d = new Date();
    var month = d.getMonth() + 1;
    var day = d.getDate();
    var output = (('' + day).length < 2 ? '0' : '') + day + '/' +
        (('' + month).length < 2 ? '0' : '') + month + '/' +
        d.getFullYear();
    return output;
}

function Imprimir(id) {
    var texto = $.MisUrls.url._DocumentoCompra + "?idcompra=" + id;
    var w = window.open(texto);
}