import { Verifier } from "./Verifier.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");
const keypair = await Verifier.generateKeypair();
console.log("Keypair generated");

console.log("Proving...");
const verificationProof = await Verifier.prove([], [], keypair);

console.log("Verifying...");
const ok = await Verifier.verify([], keypair.verificationKey(), verificationProof);
console.log("ok?", ok);

console.dir(keypair.constraintSystem(), { depth: Infinity });

// ----------------------------------------------------
console.log('Shutting down');
