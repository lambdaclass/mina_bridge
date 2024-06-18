function accountForm() {
    //let publicKey = document.forms["account-form"]["public-key"];

    const button = document.getElementById("submit");

    const show_valid_account = (balance) => {
        document.getElementById("balance").textContent = balance * (10**-9);
        document.getElementById("verified").classList.remove("hidden");
        document.getElementById("notverified").classList.add("hidden");
    }

    const show_invalid_account = () => {
        document.getElementById("verified").classList.add("hidden");
        document.getElementById("notverified").classList.remove("hidden");
        document.getElementById("errormsg").classList.add("hidden");
    }

    const show_error = () => {
        document.getElementById("balance").textContent = "?";
        document.getElementById("verified").classList.add("hidden");
        document.getElementById("notverified").classList.add("hidden");
        document.getElementById("errormsg").classList.remove("hidden");
    }

    async function request() {
        const publicKey = document.getElementById("public-key").value;
        const string = "http://5.9.57.89:3000/account_state/".concat(publicKey, "/http%3A%2F%2F5.9.57.89%3A3085%2Fgraphql/https%3A%2F%2Fsepolia.drpc.org/0x698176F675F7e05a751c70bC902Ec18c5D228b8E");
        try {
            const response = await fetch(string);
            try {
                const response_json = await response.json();
                let valid = response_json.valid
                if (valid) {
                    let balance = response_json.balance
                    show_valid_account(balance)
                } else {
                    show_invalid_account();
                }
            } catch {
                show_error();
            }
        } catch {
            show_error();
        }
    }

    button.addEventListener("click", request);
}

window.onload = accountForm;
