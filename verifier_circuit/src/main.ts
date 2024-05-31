import { readFileSync, writeFileSync } from "fs";
import { deserOpeningProof } from "./serde/serde_proof.js";
import testInputs from "../test_data/inputs.json" assert { type: "json" };
import { Verifier } from "./verifier/verifier.js";

let inputs;
try {
    inputs = JSON.parse(readFileSync("./src/proof.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = testInputs;
}

let openingProof = deserOpeningProof(inputs.proof.bulletproof);
writeFileSync("./src/opening_proof_fields.json", JSON.stringify(openingProof.toFields()));

// ----------------------------------------------------

console.log("Generating verifier circuit keypair...");

let proofHash = openingProof.hash();
let keypair = await Verifier.generateKeypair();
console.log("Proving...");
let { value } = await Verifier.prove([], [proofHash], keypair);
console.log("Writing proof into file...");
let proof_with_public = (value as string[])[1];
let index = (value as string[])[2];
let srs = (value as string[])[3];
writeFileSync("../kzg_prover/proof_with_public.json", proof_with_public);
writeFileSync("../kzg_prover/index.json", index);
writeFileSync("../kzg_prover/srs.json", srs);

console.log("Writing circuit gates into file...");
let gates = keypair.constraintSystem();
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
