import { Addition } from "./Addition.ts";
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
// create an instance of Addition - and deploy it to zkAppAddress
const zkAppInstance = new Addition(zkAppAddress);
const { verificationKey } = await Addition.compile();

// create the transaction that deploys the Smart Contract
const deployTxn = await Mina.transaction(deployerAccount, () => {
    AccountUpdate.fundNewAccount(deployerAccount);
    zkAppInstance.deploy();
});
// sign and send the transaction to the local blockchain
await deployTxn.sign([deployerKey, zkAppPrivateKey]).send();

// get the initial state of Addition after deployment
const num0 = zkAppInstance.num.get();
console.log('state after init:', num0.toString());
// ----------------------------------------------------
const txn1 = await Mina.transaction(senderAccount, () => {
    zkAppInstance.update(Field(5));
});

// verify the proof (this is done on the client side)
// it's not necessary to do this on the client side, but it's a good way to test the proof
let proof = (await txn1.prove())[0];
let isValidProof = await verify(proof?.toJSON() as JsonProof, verificationKey.data);
Bool(isValidProof).assertTrue();
console.log('Proof was verified successfully!');

await txn1.sign([senderKey]).send();
console.log('Transaction was sent successfully!');

// get the state of Addition after the transaction
const num1 = zkAppInstance.num.get();
console.log('state after txn1:', num1.toString());
// ----------------------------------------------------
console.log('Shutting down');
