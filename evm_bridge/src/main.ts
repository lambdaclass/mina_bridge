import { Field, Provable } from "o1js";
import { Add } from "./Add.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");
const keypair = await Add.generateKeypair();
console.log("Keypair generated");

const operand1 = Field(2);
const operand2 = Field(3);
const result = Field(5);

console.log("Proving...");
const additionProof = await Add.prove([], [operand1, operand2, result], keypair);

console.log("Verifying...");
const ok = await Add.verify([operand1, operand2, result], keypair.verificationKey(), additionProof);
console.log("ok?", ok);

console.dir(keypair.constraintSystem(), { depth: Infinity });

// ----------------------------------------------------
console.log('Shutting down');
