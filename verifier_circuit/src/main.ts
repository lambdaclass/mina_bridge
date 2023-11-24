import { readFileSync, writeFileSync } from "fs";
import { ForeignGroup, Provable } from "o1js";
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

ForeignGroup.curve = [
    "0", // a
    "5", // b
    "28948022309329048855892746252171976963363056481941560715954676764349967630337", // modulus
    "1", // gen_x
    "12418654782883325593414442427049395787963493412651469444558597405572177144507", // gen_y
    "28948022309329048855892746252171976963363056481941647379679742748393362948097" // order
];
let sg = new ForeignGroup(sg_x, sg_y);
let expected = new ForeignGroup(expected_x, expected_y);

console.log("Writing circuit into file...");
let { gates } = Provable.constraintSystem(() => Verifier.main(sg, expected));
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
