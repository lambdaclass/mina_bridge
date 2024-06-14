function accountForm() {
    //let publicKey = document.forms["account-form"]["public-key"];

    const button = document.getElementById("submit");

    button.addEventListener("click", async (event) => {
        //const publicKey = document.getElementById("public-key").nodeValue;
        const publicKey = "B62qpWKzx7e1mmwVf8dJAPFQPGVpZP9pJaobhvg8iagqU2r1bEyndMa";
        //const response = await fetch("http://5.9.57.89:3000/account_state/".concat(publicKey, "/http%3A%2F%2F5.9.57.89%3A3085%2Fgraphql/https%3A%2F%2Fsepolia.drpc.org/0x698176F675F7e05a751c70bC902Ec18c5D228b8E"));
        //const valid = response.valid
        //const balance = response.balance
        const valid = true;
        const balance = 100;

        if (valid) {
            document.getElementById("verified").textContent = "yes!";
            document.getElementById("balance").textContent = balance;
        }
    });
}

window.onload = accountForm;
