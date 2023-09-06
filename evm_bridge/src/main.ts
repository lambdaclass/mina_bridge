import { Add } from "./Add.js";
import { PastaField } from "./PastaField.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");
const keypair = await Add.generateKeypair();
console.log("Keypair generated");

const operand1 = new PastaField(2);
const operand2 = new PastaField(3);
const result = new PastaField(5);

console.log("Proving...");
const additionProof = await Add.prove([], [operand1, operand2, result], keypair);

console.log("Verifying...");
const ok = await Add.verify([operand1, operand2, result], keypair.verificationKey(), additionProof);
console.log("ok?", ok);

console.log("Keypair constraint system:", JSON.stringify(keypair.constraintSystem()));

// ----------------------------------------------------
console.log('Shutting down');
