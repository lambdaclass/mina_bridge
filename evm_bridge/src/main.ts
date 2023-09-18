import { open, readFileSync, writeFileSync } from "fs";
import { Field, Group, Provable } from "o1js";
import { Snarky } from "o1js/dist/node/snarky.js";
import { Verifier } from "./Verifier.js";

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

console.log('SnarkyJS loaded');

// ----------------------------------------------------

console.log("Generating constraint system");
let cs = Provable.constraintSystem(() => {
    let sgX = Provable.witness(Field, () => Field(inputs.sg[0]));
    let sgY = Provable.witness(Field, () => Field(inputs.sg[1]));
    let expected = Provable.witness(Group, () => new Group({ x: inputs.expected[0], y: inputs.expected[1] }));

    Verifier.main(sgX, sgY, BigInt(inputs.z1), expected, false);
});
console.log("public inputs:", cs.publicInputSize);
console.log("Done!");

console.log("Writing constraint system into file");
writeFileSync("../kzg_prover/test_data/constraint_system.json", JSON.stringify(cs.gates));
console.log("Done!");

// ----------------------------------------------------
console.log('Shutting down');
