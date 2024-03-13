import { readFileSync, writeFileSync } from "fs";
import { Verifier } from "./verifier/verifier.js";
import { deserOpeningProof } from "./serde/serde_proof.js";
import { ForeignField } from "./foreign_fields/foreign_field.js";
import { TestCircuit } from "./test_circuit.js";
import { ForeignPallas } from "./foreign_fields/foreign_pallas.js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";
import testInputs from "../test_data/inputs.json" assert { type: "json" };

let inputs;
try {
    inputs = JSON.parse(readFileSync("./src/inputs.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = testInputs;
}

// console.log('O1JS loaded');

// ----------------------------------------------------

console.log("Generating verifier circuit keypair...");
let openingProof = deserOpeningProof(inputs);
let keypair = await Verifier.generateKeypair();
console.log("Proving...");
let proof = await Verifier.prove([], [openingProof], keypair);
console.log(proof);

console.log("Writing circuit gates into file...");
let gates = keypair.constraintSystem();
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
