import { Provable } from "o1js";
import { Verifier } from "./verifier/Verifier.js";

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating constraint system");
let cs = Provable.constraintSystem(Verifier.main);
console.log("Constraint system:", cs);

// ----------------------------------------------------
console.log('Shutting down');
