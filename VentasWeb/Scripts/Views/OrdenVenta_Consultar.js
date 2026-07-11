// OrdenVenta_Consultar.js
var dtOV = null;

$(function () {
    var hoy = new Date();
    var hace30 = new Date(); hace30.setDate(hoy.getDate() - 30);
    $('#txtFechaInicio').val(formatFecha(hace30));
    $('#txtFechaFin').val(formatFecha(hoy));
    iniciarTabla();
    buscarOV();
});

function iniciarTabla() {
    dtOV = $('#tbOV').DataTable({
        data: [],
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var puedeFacturar = $('#hdnPuedeFacturar').val() === '1';
                    var puedeAnular = $('#hdnPuedeAnular').val() === '1';
                    var btns = '';
                    // Botón Ver Detalle — disponible para todos los roles
                    btns += '<button class="btn btn-info btn-sm mr-1" title="Ver productos" onclick="verDetalleOV(' + d.IdOrdenVenta + ',\'' + escapar(d.NumeroOV) + '\')"><i class="fas fa-eye"></i></button>';
                    if (d.Estado === 'Pendiente') {
                        if (puedeFacturar) {
                            btns += '<a href="' + $.MisUrls.url._OV_UrlFacturar + '?idOrdenVenta=' + d.IdOrdenVenta +
                                '" class="btn btn-primary btn-sm mr-1" title="Facturar"><i class="fas fa-file-invoice-dollar"></i></a>';
                        } else {
                            btns += '<button class="btn btn-secondary btn-sm mr-1" disabled title="Tu rol (Repositor) no puede facturar. Solicitá a un Cajero."><i class="fas fa-file-invoice-dollar"></i></button>';
                        }
                        if (puedeAnular) {
                            btns += '<button class="btn btn-danger btn-sm" title="Anular" onclick="abrirAnular(' + d.IdOrdenVenta + ',\'' + escapar(d.NumeroOV) + '\')"><i class="fas fa-ban"></i></button>';
                        }
                    }
                    return btns || '—';
                }
            },
            { data: 'NumeroOV' },
            { data: 'NombreCliente', defaultContent: 'Sin cliente' },
            { data: 'TotalEstimado', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'NombreUsuario' },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            {
                data: null, render: function (d) {
                    var clase = d.AlertaVencimiento === 'VENCIDA' ? 'text-danger' : d.AlertaVencimiento === 'VENCE HOY' ? 'text-warning' : '';
                    var badge = d.AlertaVencimiento ? ' <span class="badge badge-' + (d.AlertaVencimiento === 'VENCIDA' ? 'danger' : 'warning') + '">' + d.AlertaVencimiento + '</span>' : '';
                    return '<span class="' + clase + '">' + d.FechaVencimiento + badge + '</span>';
                }
            },
            {
                data: 'Estado', render: function (v) {
                    var c = { 'Pendiente': 'warning', 'Facturada': 'success', 'Anulada': 'danger' };
                    return '<span class="badge badge-' + (c[v] || 'secondary') + '">' + v + '</span>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[6, 'asc']]   // orden de carga: más antigua primero
    });
}

function buscarOV() {
    var params = {
        fechainicio: $('#txtFechaInicio').val(),
        fechafin: $('#txtFechaFin').val(),
        estado: $('#cboEstado').val(),
        numerooV: $('#txtNumeroOV').val(),
        cliente: $('#txtCliente').val()
    };
    $.get($.MisUrls.url._OV_Obtener, params, function (r) {
        dtOV.clear().rows.add(r.data || []).draw();
    });
}

function abrirAnular(id, numero) {
    $('#hdnIdOVAnular').val(id);
    $('#lblOVAnular').text(numero);
    $('#txtMotivoAnulacion').val('');
    $('#modalAnular').modal('show');
}

function confirmarAnular() {
    var motivo = $('#txtMotivoAnulacion').val().trim();
    if (!motivo) { toastr.warning('Ingrese el motivo.'); return; }
    $.post($.MisUrls.url._OV_Anular, { idOrdenVenta: $('#hdnIdOVAnular').val(), motivo: motivo }, function (r) {
        if (r.resultado) {
            toastr.success('Pre-venta anulada.');
            $('#modalAnular').modal('hide');
            buscarOV();
        } else {
            toastr.error(r.mensaje || 'Error al anular.');
        }
    });
}

// ─── VER DETALLE DE PRODUCTOS ─────────────────────────────────────────────────
function verDetalleOV(idOrdenVenta, numeroOV) {
    $('#lblNumeroOVDetalle').text(numeroOV);
    $('#tbodyDetalleOV').html('<tr><td colspan="5" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');
    $('#tdTotalDetalleOV').text('');
    $('#modalDetalleOV').modal('show');

    $.get($.MisUrls.url._OV_Detalle, { idOrdenVenta: idOrdenVenta }, function (r) {
        var tbody = $('#tbodyDetalleOV').empty();
        // Respuesta: { resultado: true, datos: { oDetalle: [...], TotalEstimado: X } }
        var ov     = (r && r.datos) ? r.datos : r;
        var lineas = ov.oDetalle || ov.oListaDetalle || [];

        if (!lineas.length) {
            tbody.html('<tr><td colspan="5" class="text-center text-muted">Sin productos.</td></tr>');
            return;
        }
        var sumaTotal = 0;
        lineas.forEach(function (item) {
            var precio = item.PrecioUnidad || item.PrecioVenta || 0;
            var linea  = item.TotalLinea || Math.round(item.Cantidad * precio);
            sumaTotal += linea;
            tbody.append(
                '<tr>' +
                '<td>' + (item.NombreProducto || '') + '</td>' +
                '<td class="text-center">' + item.Cantidad + '</td>' +
                '<td class="text-right">Gs. ' + formatGs(precio) + '</td>' +
                '<td class="text-center">' + (item.IvaPorcentaje || 0) + '%</td>' +
                '<td class="text-right">Gs. ' + formatGs(linea) + '</td>' +
                '</tr>'
            );
        });
        $('#tdTotalDetalleOV').text('Gs. ' + formatGs(ov.TotalEstimado || sumaTotal));
    }).fail(function () {
        $('#tbodyDetalleOV').html('<tr><td colspan="5" class="text-center text-danger">Error al cargar detalle.</td></tr>');
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFecha(d) { return ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear(); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
