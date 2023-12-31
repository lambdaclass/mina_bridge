import { readFileSync, writeFileSync } from "fs";
import { ForeignGroup, Provable } from "o1js";
import { Verifier } from "./verifier/verifier.js";
import { deserOpeningProof } from "./serde/serde_proof.js";
import { ForeignField } from "./foreign_fields/foreign_field.js";

let inputs;
try {
    inputs = JSON.parse(readFileSync("./src/inputs.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = {
        lr: [
            [
                {
                    x: "1088520968677498461339541222269803063117583329963053890394325610620194639060",
                    y: "14617606017630817215388699956816378841889197144910900205036322057647212700427"
                },
                {
                    x: "22575207499792083543969566675601146718902202065546747543096107882541367860087",
                    y: "20987451900456530149985510456435645678495485801550168619519816617073424255928"
                }
            ]
        ],
        z1: "4397093005605931442646816891053389885546297107331356987745997632505536565365",
        z2: "26957307527185388370609751260493783735849378872213550655291409265619745319075",
        delta: {
            x: "6818234437686631456408547404951248692758677748822343809944584557028269988192",
            y: "12586660565751967274890069769940553942602937113651272542490903970267723360220"
        },
        sg: {
            x: "12368675093154914445558499940566677159678085503548847273105352744110357023892",
            y: "13928325837869340024710380561463559827724328563792462791279614459373822978261"
        },
        expected: {
            x: "5736868798632710640113734962596149556147058590963693818747480745427705446383",
            y: "20393541083676616749487157095022413656498918946278576790740950610414772498695"
        }
    };
}

console.log('O1JS loaded');

// ----------------------------------------------------

ForeignGroup.curve = [
    "0", // a
    "5", // b
    "28948022309329048855892746252171976963363056481941560715954676764349967630337", // modulus
    "1", // gen_x
    "12418654782883325593414442427049395787963493412651469444558597405572177144507", // gen_y
    "28948022309329048855892746252171976963363056481941647379679742748393362948097" // order
];

// Convert JSON inputs to O1JS inputs so that we can pass them to the circuit
let openingProof = deserOpeningProof(inputs);
let expected_x = ForeignField.from(inputs.expected.x);
let expected_y = ForeignField.from(inputs.expected.y);
let expected = new ForeignGroup(expected_x, expected_y);

console.log("Writing circuit into file...");
let { gates } = Provable.constraintSystem(() => Verifier.main(openingProof, expected));
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
