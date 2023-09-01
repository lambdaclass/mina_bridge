import { Bool } from "snarkyjs";
import proof from "../test/proof.json" assert { type: "json" };
import { Bridge } from "./Bridge.js";
import { ProverProof } from "./ProverProof.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");
const keypair = await Bridge.generateKeypair();

const proverProof = ProverProof.createFromJSON(proof.proof);
const isValidProof = Bool(true);

console.log("Proving...");
const verificationProof = await Bridge.prove([proverProof], [isValidProof], keypair);

console.log("Verifying...");
const ok = await Bridge.verify([isValidProof], keypair.verificationKey(), verificationProof);
console.log("ok?", ok);

// ----------------------------------------------------
console.log('Shutting down');
