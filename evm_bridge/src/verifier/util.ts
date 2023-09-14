import { Field } from "o1js";
import { CircuitGate, Wire, GenericGateSpec } from "../circuits/gate";

export class Util {
    create_circuit(start_row: number, public_count: number): Array<CircuitGate> {
        const add_mul_count = 10;
        const const_count = 10;
        let gates = Array<CircuitGate>(public_count + add_mul_count + const_count);
        let r = start_row;

        // public input
        for (let _ = 0; _ < public_count; _++) {
            gates.push(CircuitGate.create_generic_gadget(
                Wire.for_row(r),
                { kind: "pub" }
            ));
            r++;
        }

        // add and mul
        for (let _ = 0; _ < add_mul_count; _++) {
            const g1: GenericGateSpec.Add = {
                kind: "add",
                right_coeff: Field.from(3)
            }
            const g2: GenericGateSpec.Mul = {
                kind: "mul",
                mul_coeff: Field.from(2)
            }
            gates.push(CircuitGate.create_generic_gadget(
                Wire.for_row(r),
                g1,
                g2
            ));
            r++
        }

        // two consts
        for (let _ = 0; _ < const_count; _++) {
            const g1: GenericGateSpec.Const = {
                kind: "const",
                cst: Field.from(3)
            }
            const g2: GenericGateSpec.Const = {
                kind: "const",
                cst: Field.from(5)
            }
            gates.push(CircuitGate.create_generic_gadget(
                Wire.for_row(r),
                g1,
                g2
            ))
        }

        return gates;
    }
}
