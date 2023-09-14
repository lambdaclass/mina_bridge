import { readFileSync } from "fs";
import { Group, Provable } from "o1js";
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
    let sg = Provable.witness(Group, () => new Group({ x: inputs.sg[0], y: inputs.sg[1] }));
    let expected = Provable.witness(Group, () => new Group({ x: inputs.expected[0], y: inputs.expected[1] }));

    Verifier.main(sg, BigInt(inputs.z1), expected, false);
});
console.log("Constraint system:", cs);

// ----------------------------------------------------
console.log('Shutting down');
