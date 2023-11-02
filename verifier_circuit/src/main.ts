import { readFileSync, writeFileSync } from "fs";
import { Field, Group, Scalar } from "o1js";
import { Verifier } from "./verifier/verifier.js";
import { exit } from "process";
import { ForeignGroup } from "./foreign_fields/foreign_group.js";
import { ForeignField } from "./foreign_fields/foreign_field.js";
import { ForeignScalar } from "./foreign_fields/foreign_scalar.js";

let inputs: { sg: bigint[], z1: bigint, expected: bigint[] };
try {
    inputs = JSON.parse(readFileSync("./src/inputs.json", "utf-8"));
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
let sg_x = ForeignField.from(inputs.sg[0]);
let sg_y = ForeignField.from(inputs.sg[1]);
let expected_x = ForeignField.from(inputs.expected[0])
let expected_y = ForeignField.from(inputs.expected[1]);
let z1 = ForeignScalar.from(inputs.z1);
let sg_scalar = z1.neg().sub(ForeignScalar.from(1));
let public_input = [sg_x, sg_y, sg_scalar, expected_x, expected_y];

let generator = new ForeignGroup(new ForeignField(Group.generator.x.toBigInt()), new ForeignField(Group.generator.y.toBigInt()));
console.log("ADD");
let native_add = Group({ x: inputs.sg[0], y: inputs.sg[1] }).add(Group.generator);
let foreign_add = new ForeignGroup(sg_x, sg_y).add(new ForeignGroup(generator.x, generator.y));
console.log("native", native_add.x.toBigInt(), native_add.y.toBigInt());
console.log("foreign", foreign_add.x.toBigInt(), foreign_add.y.toBigInt());
console.log("SCALE");
let native_scale = Group({ x: inputs.sg[0], y: inputs.sg[1] }).scale(inputs.z1);
let foreign_scale = new ForeignGroup(sg_x, sg_y).scale(z1);
console.log("native", native_scale.x.toBigInt(), native_scale.y.toBigInt());
console.log("foreign", foreign_scale.x.toBigInt(), foreign_scale.y.toBigInt());

let keypair = await Verifier.generateKeypair();

console.log("Proving with Ethereum backend...");
// let proofKZG = await Verifier.proveKZG([], public_input, keypair);

console.log("Proving with Mina backend...");
let proof = await Verifier.prove([], public_input, keypair);
console.log("Verifying...");
let isValid = await Verifier.verify(public_input, keypair.verificationKey(), proof);
console.log("Is valid proof:", isValid);

if (!isValid) {
    exit();
}

console.log("Writing KZG proof into file...");
// writeFileSync("../proof.mpk", proofKZG);

// ----------------------------------------------------
console.log('Shutting down O1JS...');
