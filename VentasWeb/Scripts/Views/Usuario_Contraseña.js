function GuardarCambio() {
    var claveActual = $("#txtClaveActual").val();
    var claveNueva = $("#txtClaveNueva").val();
    var claveConfirmar = $("#txtClaveConfirmar").val();

    // Validación de campos vacíos
    if (!claveActual || !claveNueva || !claveConfirmar) {
        alert("Todos los campos son obligatorios.");
        return;
    }

    // Validación de que las nuevas contraseñas coincidan
    if (claveNueva !== claveConfirmar) {
        alert("Las contraseñas nuevas no coinciden.");
        return;
    }

    // Obtener ID de usuario desde el input oculto en la vista
    var idUsuario = parseInt($("#UsuarioId").val() || 0);
    if (idUsuario <= 0) {
        alert("Usuario no válido.");
        return;
    }

    // Petición AJAX para cambiar la contraseña
    $.ajax({
        type: "POST",
        url: $.MisUrls.url._CambiarClave, // Definilo en tu layout o config global
        data: { idUsuario: idUsuario, claveActual: claveActual, claveNueva: claveNueva },
        success: function (data) {
            if (data.resultado) {
                alert(data.mensaje);
                $("#formCambioClave")[0].reset(); // Limpia el formulario
            } else {
                alert(data.mensaje || "No se pudo cambiar la contraseña.");
            }
        },
        error: function () {
            alert("Error al procesar la solicitud.");
        }
    });
}
