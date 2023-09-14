import { Field } from "o1js"

export enum GateType {
    /// Zero gate
    Zero,
    /// Generic arithmetic gate
    Generic,
    /// Poseidon permutation gate
    Poseidon,
    /// Complete EC addition in Affine form
    CompleteAdd,
    /// EC variable base scalar multiplication
    VarBaseMul,
    /// EC variable base scalar multiplication with group endomorphim optimization
    EndoMul,
    /// Gate for computing the scalar corresponding to an endoscaling
    EndoMulScalar,
    // Lookup
    Lookup,
    /// Cairo
    CairoClaim,
    CairoInstruction,
    CairoFlags,
    CairoTransition,
    /// Range check
    RangeCheck0,
    RangeCheck1,
    ForeignFieldAdd,
    ForeignFieldMul,
    // Gates for Keccak
    Xor16,
    Rot64,
}

/// Wire documents the other cell that is wired to this one.
/// If the cell represents an internal wire, an input to the circuit,
/// or a final output of the circuit, the cell references itself.
export class Wire {
    row: number
    col: number
}

/// `GateWires` document the wiring of a gate. More specifically, each value either
/// represents the same cell (row and column) or a different cell in another row.
/// (This is to help the permutation argument.)
type GateWires = Array<Wire>

export class CircuitGate {
    static readonly GENERIC_COEFFS = 5;

    /// type of the gate
    typ: GateType
    /// gate wiring (for each cell, what cell it is wired to)
    wires: GateWires
    /// public selector polynomials that can used as handy coefficients in gates
    coeffs: Array<Field>

    /// This allows you to create two generic gates that will fit in one row, check [`Self::create_generic_gadget`] for a better to way to create these gates.
    static create_generic(wires: GateWires, coeffs: Array<Field>): CircuitGate {
        return { typ: GateType.Generic, wires: wires, coeffs: coeffs};
    }

    /// This allows you to create a generic public gate.
    static create_generic_gadget_pub_spec(wires: GateWires) {
        let coeffs = Array<Field>(CircuitGate.GENERIC_COEFFS * 2).fill(Field.from(0));
        coeffs[0] = Field.from(1); // public spec
        this.create_generic(wires, coeffs);
    }
}
