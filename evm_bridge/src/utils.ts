import { Field } from "snarkyjs";

export function FieldFromHex(hex: String) {
    return Field(BigInt("0x" + hex));
}
