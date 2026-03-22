var tablaStock;

$(document).ready(function () {
    activarMenu("Stock por Tienda");

    cargarTiendas();
    inicializarTabla();
    buscarStock(); // cargar todo al inicio
});

function cargarTiendas() {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var opts = '<option value="0">-- Todas las tiendas --</option>';
        (data.data || []).forEach(function (t) {
            if (t.Activo)
                opts += `<option value="${t.IdTienda}">${t.Nombre}</option>`;
        });
        $("#cboTienda").html(opts);
    });
}

function inicializarTabla() {
    tablaStock = $('#tbStock').DataTable({
        ajax: {
            url: "/Inventario/ObtenerStock",
            type: "GET",
            data: function () {
                return {
                    idtienda: $("#cboTienda").val() || 0,
                    idproducto: 0
                };
            },
            dataSrc: "data"
        },
        columns: [
            { data: "Codigo" },
            { data: "NombreProducto" },
            { data: "Categoria" },
            { data: "NombreTienda" },
            { data: "Stock", className: "text-center font-weight-bold" },
            { data: "StockMinimo", className: "text-center" },
            { data: "StockMaximo", className: "text-center" },
            {
                data: "EstadoStock",
                className: "text-center",
                render: function (data) {
                    var color = data === "CRITICO" ? "danger" : data === "BAJO" ? "warning" : "success";
                    return `<span class="badge badge-${color}">${data}</span>`;
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true,
        order: [[3, "asc"], [1, "asc"]]
    });
}

function buscarStock() {
    if (tablaStock) tablaStock.ajax.reload();
}