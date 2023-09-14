import { Field } from "o1js"

export enum GateType {
    /** Zero gate */
    Zero,
    /** Generic arithmetic gate */
    Generic,
    /** Poseidon permutation gate */
    Poseidon,
    /** Complete EC addition in Affine form */
    CompleteAdd,
    /** EC variable base scalar multiplication */
    VarBaseMul,
    /** EC variable base scalar multiplication with group endomorphim optimization */
    EndoMul,
    /** Gate for computing the scalar corresponding to an endoscaling */
    EndoMulScalar,
    /** Lookup */
    Lookup,
    // Cairo
    CairoClaim,
    CairoInstruction,
    CairoFlags,
    CairoTransition,
    // Range check
    RangeCheck0,
    RangeCheck1,
    ForeignFieldAdd,
    ForeignFieldMul,
    // Gates for Keccak
    Xor16,
    Rot64,
}

/**
 * Wire documents the other cell that is wired to this one.
 * If the cell represents an internal wire, an input to the circuit,
 * or a final output of the circuit, the cell references itself.
 */
export class Wire {
    static readonly PERMUTS = 7

    row: number
    col: number

    static for_row(row: number): GateWires {
        return Array<Wire>(this.PERMUTS)
            .map((_, col) => { return { row: row, col: col }; });
    }
}

export namespace GenericGateSpec {
    export type Add = {
        kind: "add";
        left_coeff?: Field;
        right_coeff?: Field;
        output_coeff?: Field
    };
    export type Mul = {
        kind: "mul";
        output_coeff?: Field;
        mul_coeff?: Field
    };
    export type Const = {
        kind: "const";
        cst: Field
    };
    export type Pub = {
        kind: "pub"
    };
    export type Plus = {
        kind: "plus";
        cst: Field
    };
}
/**
 * The different type of computation that are possible with a generic gate.
 * This type is useful to create a generic gate via the [`CircuitGate::create_generic_gadget`] function.
 */
type GenericGateSpec =
    | GenericGateSpec.Add
    | GenericGateSpec.Mul
    | GenericGateSpec.Const
    | GenericGateSpec.Pub
    | GenericGateSpec.Plus;

/**
 * `GateWires` document the wiring of a gate. More specifically, each value either
 *  represents the same cell (row and column) or a different cell in another row.
 *  (This is to help the permutation argument.)
 */
type GateWires = Array<Wire>

export class CircuitGate {
    static readonly GENERIC_COEFFS = 5;

    /** type of the gate */
    typ: GateType
    /** gate wiring (for each cell, what cell it is wired to) */
    wires: GateWires
    /** public selector polynomials that can used as handy coefficients in gates */
    coeffs: Array<Field>

    /**
     * This allows you to create two generic gates that will fit in one row, 
     * check [`Self::create_generic_gadget`] for a better to way to create these gates.
     */
    static create_generic(wires: GateWires, coeffs: Array<Field>): CircuitGate {
        return { typ: GateType.Generic, wires: wires, coeffs: coeffs };
    }

    /** This allows you to create two generic gates from GenericGateSpec. */
    static create_generic_gadget(wires: GateWires, gate1: GenericGateSpec, gate2?: GenericGateSpec): CircuitGate {
        let coeffs = Array<Field>(CircuitGate.GENERIC_COEFFS * 2).fill(Field.from(0));
        let gate_spec_map = (gate: GenericGateSpec) => {
            const one = Field.from(1);
            const zero = Field.from(0);
            switch (gate.kind) {
                case "add":
                    coeffs[0] = gate.left_coeff ?? one;
                    coeffs[1] = gate.right_coeff ?? one;
                    coeffs[2] = gate.output_coeff ?? one.neg();
                    break;
                case "mul":
                    coeffs[2] = gate.output_coeff ?? one.neg();
                    coeffs[3] = gate.mul_coeff ?? one;
                    break;
                case "const":
                    coeffs[0] = one;
                    coeffs[4] = Field.from(-gate.cst)
                    break;
                case "pub":
                    coeffs[0] = one;
                    break;
                case "plus":
                    coeffs[0] = one;
                    coeffs[1] = zero;
                    coeffs[2] = one.neg();
                    coeffs[3] = zero;
                    coeffs[4] = Field.from(gate.cst)
            }
        }
        gate_spec_map(gate1);
        if (gate2) gate_spec_map(gate2);
        return this.create_generic(wires, coeffs);
    }
}
