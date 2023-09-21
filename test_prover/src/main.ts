import { Field, Provable } from "o1js";
import { Addition } from "./Addition.js";

console.log('SnarkyJS loaded');

console.log("Generating test constraint system");
let cs = Provable.constraintSystem(() => {
    let a = Provable.witness(Field, () => Field(3));
    let b = Provable.witness(Field, () => Field(5));
    let c = Provable.witness(Field, () => Field(2));
    let d = Provable.witness(Field, () => Field(16));

    Addition.main(a, b, c, d);
});
console.log("Constraint system:", JSON.stringify(cs));

console.log('Shutting down');
