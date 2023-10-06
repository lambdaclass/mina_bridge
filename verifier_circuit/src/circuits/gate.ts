export enum GateType {
    /** Zero gate */
    Zero = "Zero",
    /** Generic arithmetic gate */
    Generic = "Generic",
    /** Poseidon permutation gate */
    Poseidon = "Poseidon",
    /** Complete EC addition in Affine form */
    CompleteAdd = "CompleteAdd",
    /** EC variable base scalar multiplication */
    VarBaseMul = "VarBaseMul",
    /** EC variable base scalar multiplication with group endomorphim optimization */
    EndoMul = "EndoMul",
    /** Gate for computing the scalar corresponding to an endoscaling */
    EndoMulScalar = "EndoMulScalar",
    /** Lookup */
    Lookup = "Lookup",
    // Cairo
    CairoClaim = "CairoClaim",
    CairoInstruction = "CairoInstruction",
    CairoFlags = "CairoFlags",
    CairoTransition = "CairoTransition",
    // Range check
    RangeCheck0 = "RangeCheck0",
    RangeCheck1 = "RangeCheck1",
    ForeignFieldAdd = "ForeignFieldAdd",
    ForeignFieldMul = "ForeignFieldMul",
    // Gates for Keccak
    Xor16 = "Xor16",
    Rot64 = "Rot64",
}

/**
 * A constraint type represents a polynomial that will be part of the final 
 * equation f (the circuit equation) 
 */
export namespace ArgumentType {
    /**
     * Gates in the PLONK constraint system.
     * As gates are mutually exclusive (a single gate is set per row),
     * we can reuse the same powers of alpha across gates.
     */
    export type Gate = {
        kind: "gate",
        type: GateType
    }

    /** The permutation argument */
    export type Permutation = {
        kind: "permutation",
    }

    /** The lookup argument */
    export type Lookup = {
        kind: "lookup",
    }
}

export type ArgumentType =
    | ArgumentType.Gate
    | ArgumentType.Permutation
    | ArgumentType.Lookup
