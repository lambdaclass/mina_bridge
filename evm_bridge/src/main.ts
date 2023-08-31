import proof from "../test/proof.json" assert { type: "json" };
import srs_json from "../test/srs.json" assert {type: "json"};
import {
    Mina,
    PrivateKey,
    AccountUpdate,
    verify,
    JsonProof,
    Bool,
    ZkappPublicInput,
    SelfProof,
} from 'snarkyjs';
import { Bridge } from "./Bridge.js";
import { FieldFromHex } from "./utils.js";
import { SRSWindow } from "./SRS.js";

console.log('SnarkyJS loaded');
const Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
const { privateKey: deployerKey, publicKey: deployerAccount } = Local.testAccounts[0];
const { privateKey: senderKey, publicKey: senderAccount } = Local.testAccounts[1];

// ----------------------------------------------------
// Create a public/private key pair. The public key is your address and where you deploy the bridgeApp to
const bridgeAppPrivateKey = PrivateKey.random();
const bridgeAppAddress = bridgeAppPrivateKey.toPublicKey();
// create an instance of Add - and deploy it to bridgeAppAddress
const bridgeInstance = new Bridge(bridgeAppAddress);

// ----------------------------------------------------
const { verificationKey: bridgeVerificationKey } = await Bridge.compile();
const bridgeDeployTxn = await Mina.transaction(deployerAccount, () => {
    AccountUpdate.fundNewAccount(deployerAccount);
    bridgeInstance.deploy();
});
await bridgeDeployTxn.sign([deployerKey, bridgeAppPrivateKey]).send();
// get the initial state of Bridge after deployment
const valid0 = bridgeInstance.isValidProof.get();
console.log('state after bridgeDeployTxn:', valid0.toString());

// ----------------------------------------------------
const z1 = FieldFromHex(proof.proof.z1);
const sg = FieldFromHex(proof.proof.sg);
const srs = Array.from(Array(srs_json.g.length / 512).keys()).map(i => SRSWindow.from(srs_json, i));
const bridgeTxn = await Mina.transaction(senderAccount, () => {
    for (let i = 0; i < srs.length; i++) {
        console.log(i, "Calling to bridge...")
        bridgeInstance.bridge(srs[i], z1, sg);
    }
});
let signedBridgeTxn = bridgeTxn.sign([senderKey]);
await signedBridgeTxn.send();

// const num2 = addInstance.num.get();
const valid2 = bridgeInstance.isValidProof.get();
console.log('state after txn_bridge:', valid2.toString());

// ----------------------------------------------------
console.log('Shutting down');
