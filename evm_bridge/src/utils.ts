import { Field } from "snarkyjs";

export function fieldFromHex(hex: String) {
    return Field(BigInt("0x" + hex));
}
