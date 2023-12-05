// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

enum Column {
    Placeholder // FIXME:
    // Witness(usize),
    // Z,
    // LookupSorted(usize),
    // LookupAggreg,
    // LookupTable,
    // LookupKindIndex(LookupPattern),
    // LookupRuntimeSelector,
    // LookupRuntimeTable,
    // Index(GateType),
    // Coefficient(usize),
    // Permutation(usize),
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
