import { Scalar } from "o1js";

export namespace SerdeJSON {
    export function deserScalars(strs: string[]): Scalar[] {
        return strs.map(Scalar.from);
    }
}
