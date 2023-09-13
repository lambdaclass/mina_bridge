import { Provable } from "o1js";
import { Verifier } from "./Verifier.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Running circuit...");
Verifier.main();
console.log("Done!");

// console.log("Generating constraint system");
// let cs = Provable.constraintSystem(Verifier.main);
// console.log("Constraint system:", cs);

// ----------------------------------------------------
console.log('Shutting down');
