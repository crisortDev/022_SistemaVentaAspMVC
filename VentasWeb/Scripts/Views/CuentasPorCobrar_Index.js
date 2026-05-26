// CuentasPorCobrar_Index.js
'use strict';

var dtCXC       = null;
var _montoTotal = 0;   // monto de la factura seleccionada para cobrar

$(function () {
    dtCXC = $('#tbCXC').DataTable({
        data: [],
        columns: [
            { data: 'NumeroCobro' },
            { data: 'NumeroFactura', render: function (v) { return '<code>' + v + '</code>'; } },
            { data: 'NombreCliente' },
            { data: 'NumeroDocumento' },
            { data: 'TelefonoCliente' },
            { data: 'MontoTotal', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'PlazoCredito', render: function (v) { return v ? v + ' días' : '—'; } },
            {
                data: 'FechaVencimiento',
                render: function (v, type, row) {
                    if (!v) return '—';
                    var dias = row.DiasParaVencer;
                    var badge = '';
                    if (dias === null || dias === undefined) {
                        badge = '<span class="badge badge-secondary ml-1">—</span>';
                    } else if (dias < 0) {
                        badge = '<span class="badge badge-danger ml-1">Vencida ' + Math.abs(dias) + 'd</span>';
                    } else if (dias <= 7) {
                        badge = '<span class="badge badge-warning ml-1">Vence en ' + dias + 'd</span>';
                    } else {
                        badge = '<span class="badge badge-success ml-1">' + dias + ' días</span>';
                    }
                    return v + badge;
                }
            },
            {
                data: 'Estado',
                render: function (v) {
                    return v === 'Pendiente'
                        ? '<span class="badge badge-warning">Pendiente</span>'
                        : '<span class="badge badge-success">Cobrado</span>';
                }
            },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            {
                data: null,
                orderable: false,
                className: 'text-center',
                render: function (data, type, row) {
                    return '<button class="btn btn-success btn-sm" onclick="abrirModalCobrar(' +
                        row.IdComprobanteCobro + ',\'' + escapar(row.NumeroFactura) + '\',\'' +
                        escapar(row.NombreCliente) + '\',' + row.MontoTotal + ',\'' +
                        (row.FechaVencimiento || '—') + '\')">' +
                        '<i class="fas fa-dollar-sign"></i> Cobrar</button>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[7, 'asc']]    // primero las más urgentes (vencimiento ascendente)
    });

    buscarCXC();

    // Cambio en filtro "Solo vencidas"
    $('#chkSoloVencidas').on('change', function () { buscarCXC(); });
});

// ─── Buscar / actualizar lista ─────────────────────────────────────────────
function buscarCXC() {
    var soloVencidas = $('#chkSoloVencidas').is(':checked');
    $.get($.MisUrls.url._CC_ObtenerPendientes, { soloVencidas: soloVencidas }, function (r) {
        var lista = r.data || [];
        dtCXC.clear().rows.add(lista).draw();
        actualizarResumen(lista);
    });
}

// ─── Resumen de tarjetas ───────────────────────────────────────────────────
function actualizarResumen(lista) {
    var totalPendiente = 0, totalVencidas = 0, totalPorVencer = 0, totalAlDia = 0;
    lista.forEach(function (r) {
        var monto = r.MontoTotal || 0;
        var dias  = r.DiasParaVencer;
        totalPendiente += monto;
        if (dias !== null && dias !== undefined) {
            if (dias < 0)      totalVencidas  += monto;
            else if (dias <= 7) totalPorVencer += monto;
            else               totalAlDia     += monto;
        }
    });
    $('#lblTotalPendiente').text('Gs. ' + formatGs(totalPendiente));
    $('#lblTotalVencidas').text('Gs. ' + formatGs(totalVencidas));
    $('#lblTotalPorVencer').text('Gs. ' + formatGs(totalPorVencer));
    $('#lblTotalAlDia').text('Gs. ' + formatGs(totalAlDia));
}

// ─── Abrir modal de cobro ─────────────────────────────────────────────────
function abrirModalCobrar(idCompCobro, factura, cliente, montoTotal, vencimiento) {
    _montoTotal = montoTotal;
    $('#hdnIdCompCobro').val(idCompCobro);
    $('#infoNumeroFactura').text(factura);
    $('#infoCliente').text(cliente);
    $('#infoMontoTotal').text('Gs. ' + formatGs(montoTotal));
    $('#infoVencimiento').text(vencimiento);
    $('#ddlFormaCobro').val(0);
    $('#txtMontoRecibido').val('');
    $('#txtObservacion').val('');
    $('#alertCambio').hide();
    $('#modalCobrar').modal('show');
    setTimeout(function () { $('#txtMontoRecibido').focus(); }, 400);
}

// ─── Calcular cambio en tiempo real ───────────────────────────────────────
function calcularCambio() {
    var recibido = parseFloat($('#txtMontoRecibido').val()) || 0;
    var cambio   = recibido - _montoTotal;
    var alert    = $('#alertCambio');
    if (recibido > 0) {
        alert.show();
        if (cambio >= 0) {
            alert.removeClass('alert-danger').addClass('alert-info');
            $('#lblCambio').text('Gs. ' + formatGs(cambio));
        } else {
            alert.removeClass('alert-info').addClass('alert-danger');
            $('#lblCambio').text('Monto insuficiente — faltan Gs. ' + formatGs(Math.abs(cambio)));
        }
    } else {
        alert.hide();
    }
}

// ─── Confirmar cobro ───────────────────────────────────────────────────────
function confirmarCobro() {
    var idCompCobro  = parseInt($('#hdnIdCompCobro').val()) || 0;
    var idFormaCobro = parseInt($('#ddlFormaCobro').val()) || 0;
    var montoRec     = parseFloat($('#txtMontoRecibido').val()) || 0;
    var obs          = $('#txtObservacion').val();

    if (!idCompCobro) { toastr.error('Comprobante no identificado.'); return; }
    if (!idFormaCobro) { toastr.warning('Seleccioná una forma de cobro.'); return; }
    if (montoRec <= 0) { toastr.warning('Ingresá el monto recibido.'); return; }
    if (montoRec < _montoTotal) {
        toastr.warning('El monto recibido es menor al total de la factura (Gs. ' + formatGs(_montoTotal) + ').');
        return;
    }

    Swal.fire({
        title: '¿Confirmar cobro?',
        html:  'Total factura: <strong>Gs. ' + formatGs(_montoTotal) + '</strong><br>' +
               'Recibido: <strong>Gs. ' + formatGs(montoRec) + '</strong><br>' +
               'Cambio: <strong>Gs. ' + formatGs(montoRec - _montoTotal) + '</strong>',
        icon:  'question',
        showCancelButton:  true,
        confirmButtonText: 'Sí, registrar cobro',
        confirmButtonColor: '#28a745',
        cancelButtonText:  'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;

        $.ajax({
            url:    $.MisUrls.url._CC_Cobrar,
            method: 'POST',
            data:   {
                idCompCobro:  idCompCobro,
                idFormaCobro: idFormaCobro,
                montoRecibido: montoRec,
                observacion:  obs
            },
            success: function (res) {
                if (res.resultado) {
                    $('#modalCobrar').modal('hide');
                    toastr.success(res.mensaje);
                    buscarCXC();
                    // Abrir recibo imprimible en nueva pestaña
                    if (res.idCompCobro) {
                        window.open($.MisUrls.url._CC_Documento + '?idCompCobro=' + res.idCompCobro, '_blank');
                    }
                } else {
                    toastr.error(res.mensaje);
                }
            },
            error: function () { toastr.error('Error de conexión.'); }
        });
    });
}

// ─── Helpers ──────────────────────────────────────────────────────────────
function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s)  { return (s || '').replace(/'/g, "\\'"); }
