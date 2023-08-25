import { Add } from "./Add.js";
import {
    Mina,
    PrivateKey,
    AccountUpdate,
    verify,
    JsonProof,
    Bool,
    ZkappPublicInput,
    Proof,
    SelfProof,
} from 'snarkyjs';
import { Bridge } from "./Bridge.js";

console.log('SnarkyJS loaded');
const Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
const { privateKey: deployerKey, publicKey: deployerAccount } = Local.testAccounts[0];
const { privateKey: senderKey, publicKey: senderAccount } = Local.testAccounts[1];

// ----------------------------------------------------
// Create a public/private key pair. The public key is your address and where you deploy the addApp to
const addAppPrivateKey = PrivateKey.random();
const addAppAddress = addAppPrivateKey.toPublicKey();
// create an instance of Add - and deploy it to addAppAddress
const addInstance = new Add(addAppAddress);

// ----------------------------------------------------
// Create a public/private key pair. The public key is your address and where you deploy the bridgeApp to
const bridgeAppPrivateKey = PrivateKey.random();
const bridgeAppAddress = bridgeAppPrivateKey.toPublicKey();
// create an instance of Add - and deploy it to bridgeAppAddress
const bridgeInstance = new Bridge(bridgeAppAddress);

// ----------------------------------------------------
const { verificationKey: addVerificationKey } = await Add.compile();
const addDeployTxn = await Mina.transaction(deployerAccount, () => {
    AccountUpdate.fundNewAccount(deployerAccount);
    addInstance.deploy();
});
await addDeployTxn.sign([deployerKey, addAppPrivateKey]).send();
// get the initial state of Add after deployment
const num0 = addInstance.num.get();
console.log('state after addDeployTxn:', num0.toString());

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
const addTxn = await Mina.transaction(senderAccount, () => {
    addInstance.update();
});
let addProof = (await addTxn.prove())[0] as SelfProof<ZkappPublicInput, undefined>;
let isAddProofValid = await verify(addProof.toJSON() as JsonProof, addVerificationKey.data);
Bool(isAddProofValid).assertTrue();
console.log('Proof of add transaction was verified successfully!');
let signedAddTxn = addTxn.sign([senderKey]);
await signedAddTxn.send();

const num1 = addInstance.num.get();
const valid1 = bridgeInstance.isValidProof.get();
console.log('state after txn_add:', num1.toString(), valid1.toString());

// ----------------------------------------------------
const bridgeTxn = await Mina.transaction(senderAccount, () => {
    bridgeInstance.bridge();
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
