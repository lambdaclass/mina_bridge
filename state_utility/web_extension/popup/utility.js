function accountForm() {
    //let publicKey = document.forms["account-form"]["public-key"];

    const button = document.getElementById("submit");

    button.addEventListener("click", (event) => {
        const verified = document.getElementById("verified");
        // query server, check account
        // ...
        // here we put the code!
        let success = true;
        let balance = 10;

        if (success) {
            document.getElementById("verified").textContent = "yes!";
            document.getElementById("balance").textContent = balance;
        }
    });
}

window.onload = accountForm;
