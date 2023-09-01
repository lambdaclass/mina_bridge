import { Bool, Field } from "snarkyjs";
import { Add } from "./Add.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");
const keypair = await Add.generateKeypair();

const operand1 = Field(2);
const operand2 = Field(3);
const result = Field(5);

console.log("Proving...");
const additionProof = await Add.prove([], [operand1, operand2, result], keypair);

console.log("Verifying...");
const ok = await Add.verify([operand1, operand2, result], keypair.verificationKey(), additionProof);
console.log("ok?", ok);

console.log("Keypair constraint system:", JSON.stringify(keypair.constraintSystem()));

// ----------------------------------------------------
console.log('Shutting down');
