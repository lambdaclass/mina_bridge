import { ForeignPallas } from "../foreign_fields/foreign_pallas.js";
import { PolyComm } from "../poly_commitment/commitment.js";

/**
* Flags for each of the hard-coded lookup patterns.
*/
export class LookupPatterns {
    xor: boolean
    lookup: boolean
    range_check: boolean
    foreign_field_mul: boolean
}

export class LookupFeatures {
    /// A single lookup constraint is a vector of lookup constraints to be applied at a row.
    patterns: LookupPatterns
    /// Whether joint lookups are used
    joint_lookup_used: boolean
    /// True if runtime lookup tables are used.
    uses_runtime_tables: boolean
}

/**
* Describes the desired lookup configuration.
*/
export class LookupInfo {
    /// The maximum length of an element of `kinds`. This can be computed from `kinds`.
    max_per_row: number
    /// The maximum joint size of any joint lookup in a constraint in `kinds`. This can be computed from `kinds`.
    max_joint_size: number
    /// The features enabled for this lookup configuration
    features: LookupFeatures
}

export enum LookupPattern {
    Xor,
    Lookup,
    RangeCheck,
    ForeignFieldMul
}

export class LookupSelectors {
    xor?: PolyComm<ForeignPallas>
    lookup?: PolyComm<ForeignPallas>
    range_check?: PolyComm<ForeignPallas>
    ffmul?: PolyComm<ForeignPallas>
}
