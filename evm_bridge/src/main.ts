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
    Field,
    Provable,
    MerkleMap,
} from 'snarkyjs';
import { Bridge } from "./Bridge.js";
import { FieldFromHex } from "./utils.js";
import { SRS } from "./SRS.js";

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
let srs = SRS.from(srs_json);
const bridgeTxn = await Mina.transaction(senderAccount, () => {
    // WE NEED TO PASS AN ARRAY AS ARGUMENT, BUT ARRAY IS NOT PROVABLE
    // WE TRIED WITH MERKLEMAP, BUT IT ALSO DOES NOT WORK
    bridgeInstance.bridge(srs, z1, sg);
});
let bridgeProof = (await bridgeTxn.prove())[0] as SelfProof<ZkappPublicInput, undefined>;
let isBridgeProofValid = await verify(bridgeProof.toJSON() as JsonProof, bridgeVerificationKey.data);
Bool(isBridgeProofValid).assertTrue();
console.log('Proof of bridge transaction was verified successfully!');
let signedBridgeTxn = bridgeTxn.sign([senderKey]);
await signedBridgeTxn.send();

// const num2 = addInstance.num.get();
const valid2 = bridgeInstance.isValidProof.get();
console.log('state after txn_bridge:', valid2.toString());

// ----------------------------------------------------
console.log('Shutting down');
