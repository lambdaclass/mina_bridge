function accountForm() {
    //let publicKey = document.forms["account-form"]["public-key"];

    // query server, check account
    // ...
    let success = true;
    let balance = 10;

    if (success) {
        document.getElementById("verified").textContent = "yes!";
        document.getElementById("balance").textContent = balance;
    }
}
