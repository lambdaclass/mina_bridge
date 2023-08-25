import { Add } from "./Add.js";
import {
    Field,
    Mina,
    PrivateKey,
    AccountUpdate,
    verify,
    JsonProof,
    Bool,
} from 'snarkyjs';

console.log('SnarkyJS loaded');
const Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
const { privateKey: deployerKey, publicKey: deployerAccount } = Local.testAccounts[0];
const { privateKey: senderKey, publicKey: senderAccount } = Local.testAccounts[1];
// ----------------------------------------------------
// Create a public/private key pair. The public key is your address and where you deploy the zkApp to
const zkAppPrivateKey = PrivateKey.random();
const zkAppAddress = zkAppPrivateKey.toPublicKey();
// create an instance of Add - and deploy it to zkAppAddress
const zkAppInstance = new Add(zkAppAddress);
const { verificationKey } = await Add.compile();
const deployTxn = await Mina.transaction(deployerAccount, () => {
    AccountUpdate.fundNewAccount(deployerAccount);
    zkAppInstance.deploy();
});
await deployTxn.sign([deployerKey, zkAppPrivateKey]).send();
// get the initial state of Add after deployment
const num0 = zkAppInstance.num.get();
console.log('state after init:', num0.toString());
// ----------------------------------------------------
const txn1 = await Mina.transaction(senderAccount, () => {
    zkAppInstance.update();
});
let proof = (await txn1.prove())[0];
let isValidProof = await verify(proof?.toJSON() as JsonProof, verificationKey.data);
Bool(isValidProof).assertTrue();
console.log('Proof was verified successfully!');
await txn1.sign([senderKey]).send();

const num1 = zkAppInstance.num.get();
console.log('state after txn1:', num1.toString());
// ----------------------------------------------------
console.log('Shutting down');
