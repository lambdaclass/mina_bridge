import { ForeignPallas } from "../src/foreign_fields/foreign_pallas";
import { PolyComm } from "../src/poly_commitment/commitment";

export function stringifyWithBigInt(input: any) {
    return JSON.stringify(input, (_key, value) => typeof value === "bigint" ? value.toString() : value);
}

export function createPolyComm(length: number) {
    return new PolyComm(Array(length).fill(ForeignPallas.generator as ForeignPallas));
}
