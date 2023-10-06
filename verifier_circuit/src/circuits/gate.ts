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

    export function id(arg: ArgumentType): ArgumentTypeID {
        if (arg.kind === "gate") return arg.kind + arg.type;
        return arg.kind;
    }
}

export type ArgumentType =
    | ArgumentType.Gate
    | ArgumentType.Permutation
    | ArgumentType.Lookup

/**
 * This is necessary to use an argument type as a key in a map, as `Map`
 * will compare a key by reference and not by value
 */
export type ArgumentTypeID = string;
