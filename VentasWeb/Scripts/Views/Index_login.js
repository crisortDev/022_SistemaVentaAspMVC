// ── Utilidades de UI ──────────────────────────────────────
function mostrarPanel(id) {
    $('.panel').removeClass('active');
    $('#' + id).addClass('active');
}

function mostrarError(idDiv, msg) {
    $('#' + idDiv).text(msg).show();
}

function ocultarError(idDiv) {
    $('#' + idDiv).text('').hide();
}

function setLoading(btnId, loading) {
    var $btn = $('#' + btnId);
    $btn.find('.spinner').toggle(loading);
    $btn.prop('disabled', loading);
}

function toggleVis(fieldId, btn) {
    var $f = $('#' + fieldId);
    var esPassword = $f.attr('type') === 'password';
    $f.attr('type', esPassword ? 'text' : 'password');
    $(btn).text(esPassword ? '🙈' : '👁');
}

// ── Fortaleza de contraseña ───────────────────────────────
function evalStrength(val) {
    var checks = {
        reqLen: val.length >= 8,
        reqUpper: /[A-Z]/.test(val),
        reqNum: /[0-9]/.test(val),
        reqSpecial: /[^A-Za-z0-9]/.test(val)
    };

    var score = Object.values(checks).filter(Boolean).length;

    // Requisitos visuales
    Object.keys(checks).forEach(function (id) {
        var $li = $('#' + id);
        var $dot = $li.find('.dot');
        if (checks[id]) {
            $li.addClass('met');
            $dot.text('✓ ');
        } else {
            $li.removeClass('met');
            $dot.text('');
        }
    });

    // Barra de segmentos
    var colors = ['', '#e74c3c', '#e67e22', '#f1c40f', '#27ae60'];
    var labels = ['', 'Muy débil', 'Débil', 'Aceptable', 'Fuerte'];
    for (var i = 1; i <= 4; i++) {
        $('#seg' + i).css('background', i <= score ? colors[score] : '#e0dbd3');
    }
    $('#strengthLabel').text(val ? labels[score] : 'Ingresa una contraseña');

    checkMatch();
    habilitarBoton();
}

// ── Verificar coincidencia ────────────────────────────────
function checkMatch() {
    var nueva = $('#nuevaClave').val();
    var confirmar = $('#confirmarClave').val();
    var $hint = $('#matchHint');

    if (!confirmar) { $hint.text('').removeClass('ok error'); return; }

    if (nueva === confirmar) {
        $hint.text('✓ Las contraseñas coinciden').removeClass('error').addClass('ok');
    } else {
        $hint.text('✗ No coinciden').removeClass('ok').addClass('error');
    }
    habilitarBoton();
}

// ── Habilitar botón solo si todo está OK ──────────────────
function habilitarBoton() {
    var nueva = $('#nuevaClave').val();
    var confirmar = $('#confirmarClave').val();
    var valida = nueva.length >= 8 &&
        /[A-Z]/.test(nueva) &&
        /[0-9]/.test(nueva) &&
        /[^A-Za-z0-9]/.test(nueva) &&
        nueva === confirmar;
    $('#btnGuardar').prop('disabled', !valida);
}

// ── Guardar nueva contraseña ──────────────────────────────
function guardarClave() {
    var nuevaClave = $('#nuevaClave').val();

    ocultarError('cambioError');
    setLoading('btnGuardar', true);

    $.post('/Login/CambiarPassword', { nuevaClave: nuevaClave }, function (resp) {
        setLoading('btnGuardar', false);

        if (resp.success) {
            $('#cambioOk').text('✓ Contraseña guardada. Redirigiendo...').show();
            setTimeout(function () {
                window.location.href = '/Home';
            }, 1500);
        } else {
            mostrarError('cambioError', '⚠️ ' + resp.mensaje);
            // Limpiar campos para que ingrese una nueva
            $('#nuevaClave').val('');
            $('#confirmarClave').val('');
            $('#matchHint').text('').removeClass('ok error');
            evalStrength('');
        }
    }).fail(function () {
        setLoading('btnGuardar', false);
        mostrarError('cambioError', '⚠️ Error de conexión. Intentá de nuevo.');
    });
}

// ── Document Ready ────────────────────────────────────────
$(document).ready(function () {

    // Ocultar alertas al inicio
    $('#loginError, #cambioError, #cambioOk, #olvideError, #olvideOk').hide();

    // ── LOGIN ─────────────────────────────────────────────
    $('#formLogin').submit(function (e) {
        e.preventDefault();
        ocultarError('loginError');
        setLoading('btnLogin', true);

        var correo = $('#correo').val();
        var clave = $('#clave').val();

        $.post($(this).attr('action'), { correo: correo, clave: clave }, function (resp) {
            setLoading('btnLogin', false);

            if (resp.success) {
                if (resp.requiereCambio) {
                    // Primer acceso o contraseña expirada
                    var esPrimerAcceso = resp.motivo !== 'expiracion';
                    $('#panelTitle').text('Cambiar contraseña');
                    $('#panelSubtitle').text(
                        esPrimerAcceso
                            ? 'Primer acceso — establecé tu contraseña personal'
                            : '⚠ Tu contraseña expiró — debés establecer una nueva para continuar'
                    );
                    mostrarPanel('panelCambio');
                } else {
                    // Login exitoso — redirigir a Home
                    window.location.href = '/Home';
                }
            } else {
                mostrarError('loginError', resp.mensaje);
            }

        }).fail(function () {
            setLoading('btnLogin', false);
            mostrarError('loginError', 'Error de conexión. Intentá de nuevo.');
        });
    });

    // ── OLVIDÉ CONTRASEÑA ─────────────────────────────────
    $('#linkOlvide').click(function (e) {
        e.preventDefault();
        $('#panelTitle').text('Recuperar acceso');
        $('#panelSubtitle').text('Te enviamos una contraseña temporal');
        mostrarPanel('panelOlvide');
    });

    $('#btnVolverLogin').click(function () {
        $('#panelTitle').text('Iniciar sesión');
        $('#panelSubtitle').text('Ingresa tus credenciales para continuar');
        mostrarPanel('panelLogin');
    });

    $('#formOlvide').submit(function (e) {
        e.preventDefault();
        var correo = $('#correoReset').val().trim();
        if (!correo) {
            mostrarError('olvideError', 'Ingresá tu correo.');
            return;
        }
        ocultarError('olvideError');
        setLoading('btnEnviarReset', true);

        $.post('/Login/RecuperarPassword', { correo: correo }, function (resp) {
            setLoading('btnEnviarReset', false);
            if (resp.success) {
                $('#olvideOk').text('✓ ' + resp.mensaje).show();
                $('#correoReset').val('');
            } else {
                mostrarError('olvideError', resp.mensaje);
            }
        }).fail(function () {
            setLoading('btnEnviarReset', false);
            mostrarError('olvideError', 'Error de conexión.');
        });
    });

});