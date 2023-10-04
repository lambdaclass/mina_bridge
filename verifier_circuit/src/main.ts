import { readFileSync, writeFileSync } from "fs";
import { Field, Group, Scalar } from "o1js";
import { Verifier } from "./verifier/verifier.js";
import { exit } from "process";

let inputs: { sg: bigint[], z1: bigint, expected: bigint[] };
try {
    inputs = JSON.parse(readFileSync("./test/inputs.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = {
        sg:
            [
                974375293919604067421642828992042234838532512369342211368018365361184475186n,
                25355274914870068890116392297762844888825113893841661922182961733548015428069n
            ],
        z1: 8370756341770614687265652169950746150853295615521166276710307557441785774650n,
        expected: [
            23971162515526044551720809934508194276417125006800220692822425564390575025467n,
            27079223568793814179815985351796131117498018732446481340536149855784701006245n
        ]
    };
}

console.log('O1JS loaded');

// ----------------------------------------------------

console.log("Generating keypair...");

// Convert JSON inputs to O1JS inputs so that we can pass them to the circuit
let sg = new Group({ x: inputs.sg[0], y: inputs.sg[1] });
let expected = new Group({ x: inputs.expected[0], y: inputs.expected[1] });
let z1 = Scalar.from(inputs.z1);
let sg_scalar = z1.neg().sub(Scalar.from(1));
let public_input = [sg, sg_scalar, expected];

let keypair = await Verifier.generateKeypair();

console.log("Proving...");
let proof = await Verifier.prove([], public_input, keypair);
console.log("Verifying...");
let isValid = await Verifier.verify(public_input, keypair.verificationKey(), proof);
console.log("Is valid proof:", isValid);

if (!isValid) {
    exit();
}

console.log("Writing proof into file...");

// See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt#use_within_json
const replacer = (_key: string, value: any) =>
    typeof value === "bigint" ? value.toString() : value;

writeFileSync("../proof.json", JSON.stringify(proof, replacer));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
