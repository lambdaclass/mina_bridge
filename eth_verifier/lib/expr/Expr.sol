// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./PolishToken.sol";

struct Column {
    ColumnVariant variant;
    bytes data;
}

enum ColumnVariant {
    Witness,
    Z,
    Index,
    Coefficient,
    Permutation
    // TODO:
    // LookupSorted(usize),
    // LookupAggreg,
    // LookupTable,
    // LookupKindIndex(LookupPattern),
    // LookupRuntimeSelector,
    // LookupRuntimeTable,
}
type ColumnWitness is uint;
//type ColumnIndex is GateType; // can't set an alias for an enum :(
type ColumnCoefficient is uint;
type ColumnPermutation is uint;

enum CurrOrNext {
    Curr,
    Next
}

struct Variable {
    Column col;
    CurrOrNext row;
}

struct RowOffset {
    bool zk_rows;
    int offset;
}

// Variants like LookupPattern and TableWidth have data associated to them.
// We will represent them as a contiguous array of `bytes`.
//
// For more info on this, see docs in PolishToken.sol
struct FeatureFlag {
    FeatureFlagVariant variant;
    bytes data;
}

enum FeatureFlagVariant {
    RangeCheck0,
    RangeCheck1,
    ForeignFieldAdd,
    ForeignFieldMul,
    Xor,
    Rot,
    LookupTables,
    RuntimeLookupTables,
    // TODO: LookupPattern(LookupPattern),
    /// Enabled if the table width is at least the given number
    TableWidth
    /// Enabled if the number of lookups per row is at least the given number
    // TODO: LookupsPerRow(isize)
}
type FeatureFlagTableWidth is uint;

enum GateType {
    // Gate types
    Zero,
    Generic,
    Poseidon,
    CompleteAdd,
    VarBaseMul,
    EndoMul,
    EndoMulScalar,
    Lookup,
    CairoClaim,
    CairoInstruction,
    CairoFlags,
    CairoTransition,
    RangeCheck0,
    RangeCheck1,
    ForeignFieldAdd,
    ForeignFieldMul,
    Xor16,
    Rot64
}

// @notice non-independent term of a linearization
struct LinearTerm {
    Column col;
    PolishToken[] coeff;
}

// @notice a linear combination of coefficients and columns
struct Linearization {
    PolishToken[] constant_term;
    LinearTerm[] index_terms;
}
