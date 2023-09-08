import { Field, Struct } from "o1js";

export class Point extends Struct({
    x: Field,
    y: Field
}) { }
