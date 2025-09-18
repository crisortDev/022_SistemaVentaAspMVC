document.addEventListener("DOMContentLoaded", function () {
    var errorMessage = document.getElementById("errorMessage");

    if (errorMessage && errorMessage.value) {
        Swal.fire({
            icon: 'error',
            title: 'Oops...',
            text: errorMessage.value
        });
    }
});
