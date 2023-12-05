// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";

// PolishToken is a tagged union type, whose variants can hold different data types.
// In Rust this can be implemented as an enum, in Typescript as a discriminated union.
//
// Here we'll use a struct, which will hold the `variant` tag as an enum and the
// `data` as bytes. The struct will be discriminated over its `variant` and after
// we can decode the bytes into the corresponding data type.

struct PolishToken {
    PolishTokenVariant variant;
    bytes data;
}

enum PolishTokenVariant {
    Alpha,
    Beta,
    Gamma,
    JointCombiner,
    EndoCoefficient,
    Mds,
    Literal,
    Cell,
    Dup,
    Pow,
    Add,
    Mul,
    Sub,
    VanishesOnZeroKnowledgeAndPreviousRows,
    UnnormalizedLagrangeBasis,
    Store,
    Load,
    /// Skip the given number of tokens if the feature is enabled.
    SkipIf,
    /// Skip the given number of tokens if the feature is disabled.
    SkipIfNot
}

struct PolishTokenMds {
    uint row;
    uint col;
}
type PolishTokenLiteral is Scalar.FE;
type PolishTokenCell is Variable;
type PolishTokenDup is uint;
type PolishTokenUnnormalizedLagrangeBasis is RowOffset;
type PolishTokenLoad is uint;
type PolishTokenSkipIf is uint;

enum Column {
    Placeholder // FIXME:
}

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
    uint offset;
}

// Variants like LookupPattern and TableWidth have data associated to them.
// We will represent them as a contiguous array of `bytes`.
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
