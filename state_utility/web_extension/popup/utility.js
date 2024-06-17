function accountForm() {
    //let publicKey = document.forms["account-form"]["public-key"];

    const button = document.getElementById("submit");

    button.addEventListener("click", async (event) => {
        const publicKey = document.getElementById("public-key").value;
        //const response = fetch("http://mina-builder:3000/account_state/".concat(publicKey, "/http%3A%2F%2F5.9.57.89%3A3085%2Fgraphql/https%3A%2F%2Fsepolia.drpc.org/0x698176F675F7e05a751c70bC902Ec18c5D228b8E"))
        //    .then(() => { alert("http://5.9.57.89:3000/account_state/".concat(publicKey, "/http%3A%2F%2F5.9.57.89%3A3085%2Fgraphql/https%3A%2F%2Fsepolia.drpc.org/0x698176F675F7e05a751c70bC902Ec18c5D228b8E")); })
        //    .catch((err) => { document.getElementById("error").textContent = err; });
        //let valid = response.valid
        //let balance = response.balance

        let valid = false;
        let balance = "?";

        if (publicKey === "verified") {
            valid = true;
            balance = 87.4
        }

        if (valid) {
            document.getElementById("balance").textContent = balance;
            document.getElementById("verified").classList.remove("hidden");
            document.getElementById("notverified").classList.add("hidden");
        } else {
            document.getElementById("balance").textContent = balance;
            document.getElementById("verified").classList.add("hidden");
            document.getElementById("notverified").classList.remove("hidden");
        }
    });
}

window.onload = accountForm;
