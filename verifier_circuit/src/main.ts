import { readFileSync, writeFileSync } from "fs";
import { Provable } from "o1js";
import { Verifier } from "./verifier/verifier.js";
import { ForeignField } from "./foreign_fields/foreign_field.js";

let inputs: { sg: bigint[], expected: bigint[] };
try {
    inputs = JSON.parse(readFileSync("./src/inputs.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = {
        sg:
            [
                12368675093154914445558499940566677159678085503548847273105352744110357023892n,
                13928325837869340024710380561463559827724328563792462791279614459373822978261n
            ],
        expected: [
            26065081609142297706924822385337762030176473849954371733717621265428419437080n,
            25403161885444353082762527911380081866142600044068732571611330580992014688540n
        ]
    };
}

console.log('O1JS loaded');

// ----------------------------------------------------

// Convert JSON inputs to O1JS inputs so that we can pass them to the circuit
let sg_x = ForeignField.from(inputs.sg[0]);
let sg_y = ForeignField.from(inputs.sg[1]);
let expected_x = ForeignField.from(inputs.expected[0])
let expected_y = ForeignField.from(inputs.expected[1]);

console.log("Writing circuit into file...");
let { gates } = Provable.constraintSystem(() => Verifier.main(sg_x, sg_y, expected_x, expected_y));
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
