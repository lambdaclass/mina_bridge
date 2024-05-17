import { ForeignCurveBn254, Group, Scalar } from "o1js"
import { PolyComm } from "../poly_commitment/commitment.js"
import { LookupVerifierIndex, VerifierIndex } from "../verifier/verifier.js"
import { deserHexScalar } from "./serde_proof.js"
import { PolishToken, CurrOrNext, Variable, Column, Linearization } from "../prover/expr.js"
import { ArgumentType, GateType } from "../circuits/gate.js"
import { Polynomial } from "../polynomial.js"
import { Alphas } from "../alphas.js"
import { ForeignPallas } from "../foreign_fields/foreign_pallas.js"
import { LookupFeatures, LookupInfo, LookupPatterns, LookupSelectors } from "../lookups/lookups.js"

export interface PolyCommJSON {
    unshifted: GroupJSON[]
    shifted: null
}

export interface AlphasJSON {

}

export type PolynomialJSON = string[];
export type GateTypeJSON = string;
export type CurrOrNextJSON = string;

export namespace ColumnJSON {
    export type Z = string;

    export type Witness = number

    export type Index = GateTypeJSON

    export type Coefficient = number

    export type Permutation = number
}

export type ColumnJSON = {
    Witness?: ColumnJSON.Witness
    Index?: ColumnJSON.Index
    Coefficient?: ColumnJSON.Coefficient
    Permutation?: ColumnJSON.Permutation
}

export type VariableJSON = {
    col: ColumnJSON
    row: CurrOrNextJSON
}

export namespace PolishTokenJSON {
    export type UnitVariant = string
    export type Literal = string // Scalar
    export type Cell = VariableJSON
    export type Pow = number
    export type Mds = {
        row: number
        col: number
    }
    export type UnnormalizedLagrangeBasis = number
    export type Load = number
    export type SkipIf = number
    export type SkipIfNot = number
}

export type PolishTokenJSON =
    | PolishTokenJSON.UnitVariant
    | {
        Literal?: PolishTokenJSON.Literal
        Cell?: PolishTokenJSON.Cell
        Pow?: PolishTokenJSON.Pow
        Mds?: PolishTokenJSON.Mds
        UnnormalizedLagrangeBasis?: PolishTokenJSON.UnnormalizedLagrangeBasis
        Load?: PolishTokenJSON.Load
        SkipIf?: PolishTokenJSON.SkipIf
        SkipIfNot?: PolishTokenJSON.SkipIfNot
    }

interface LinearizationJSON {
    constant_term: PolishTokenJSON[]
    index_terms: [ColumnJSON, PolishTokenJSON[]][]
}

interface VerifierIndexJSON {
    domain_size: number,
    domain_gen: string,
    public_size: number,
    max_poly_size: number
    zk_rows: number

    sigma_comm: PolyCommJSON[]
    coefficients_comm: PolyCommJSON[]
    generic_comm: PolyCommJSON

    psm_comm: PolyCommJSON

    complete_add_comm: PolyCommJSON
    mul_comm: PolyCommJSON
    emul_comm: PolyCommJSON
    endomul_scalar_comm: PolyCommJSON

    range_check0_comm: PolyCommJSON | null
    range_check1_comm: PolyCommJSON | null,
    foreign_field_add_comm: PolyCommJSON | null,
    foreign_field_mul_comm: PolyCommJSON | null,
    xor_comm: PolyCommJSON | null,
    rot_comm: PolyCommJSON | null,

    //powers_of_alpha: AlphasJSON
    shift: string[]
    permutation_vanishing_polynomial_m: PolynomialJSON
    w: string
    endo: string
    lookup_index: LookupVerifierIndexJSON | null,
    linearization: LinearizationJSON,
}

export interface LookupVerifierIndexJSON {
    joint_lookup_used: boolean,
    lookup_table: PolyCommJSON[],
    lookup_selectors: LookupSelectorsJSON

    table_ids: PolyCommJSON | null,

    lookup_info: LookupInfoJSON,

    runtime_tables_selector: PolyCommJSON | null
}

export interface LookupSelectorsJSON {
    xor: PolyCommJSON | null,
    lookup: PolyCommJSON | null,
    range_check: PolyCommJSON | null,
    ffmul: PolyCommJSON | null
}

export interface LookupInfoJSON {
    max_per_row: number,
    max_joint_size: number,
    features: LookupFeaturesJSON
}

export interface LookupFeaturesJSON {
    patterns: LookupPatternsJSON,
    joint_lookup_used: boolean,
    uses_runtime_tables: boolean
}

export interface LookupPatternsJSON {
    xor: boolean,
    lookup: boolean,
    range_check: boolean,
    foreign_field_mul: boolean,
}

export type GroupJSON = string[];

export function deserGroup(json: GroupJSON): ForeignCurveBn254 {
    if (json[0] === "0" && json[1] === "1") {
        return ForeignPallas.generator.add(ForeignPallas.generator.negate());
    } else {
        return new ForeignPallas({ x: BigInt(json[0]), y: BigInt(json[1]) });
    }
}

export function deserPolyComm(json: PolyCommJSON): PolyComm<ForeignCurveBn254> {
    const unshifted = json.unshifted.map(deserGroup);
    let shifted = undefined;
    if (json.shifted != null) {
        shifted = json.shifted;
    }
    return new PolyComm<ForeignCurveBn254>(unshifted, shifted);
}

export function deserGateType(json: GateTypeJSON): GateType {
    return GateType[json as keyof typeof GateType];
}

export function deserColumn(json: ColumnJSON): Column | undefined {
    if (json.Witness != null) return { kind: "witness", index: json.Witness };
    if (json.Index != null) return { kind: "index", typ: deserGateType(json.Index) };
    if (json.Coefficient != null) return { kind: "coefficient", index: json.Coefficient };
    if (json.Permutation != null) return { kind: "permutation", index: json.Permutation };
    return undefined;
}

export function deserCurrOrNext(json: CurrOrNextJSON): CurrOrNext {
    return CurrOrNext[json as keyof typeof CurrOrNext];
}

export function deserVariable(json: VariableJSON): Variable {
    return new Variable(deserColumn(json.col)!, deserCurrOrNext(json.row));
}

export function deserPolynomial(json: PolynomialJSON): Polynomial {
    return new Polynomial(json.map(deserHexScalar));
}

export function deserPolishToken(json: PolishTokenJSON): PolishToken | undefined {
    if (typeof json === "string") { // unit variant
        switch (json) {
            case "Alpha": return { kind: "alpha" }
            case "Beta": return { kind: "beta" }
            case "Gamma": return { kind: "gamma" }
            case "JointCombiner": return { kind: "jointcombiner" }
            case "EndoCoefficient": return { kind: "endocoefficient" }
            case "Dup": return { kind: "dup" }
            case "Add": return { kind: "add" }
            case "Mul": return { kind: "mul" }
            case "Sub": return { kind: "sub" }
            case "VanishesOnZeroKnowledgeAndPreviousRows": return { kind: "vanishesonzeroknowledgeandpreviousrows" }
            case "Store": return { kind: "store" }
        }
    } else {
        if (json.Literal != null) return { kind: "literal", lit: deserHexScalar(json.Literal) };
        if (json.Cell != null) {
            return { kind: "cell", cell: deserVariable(json.Cell) };
        }
        if (json.UnnormalizedLagrangeBasis != null)
            return { kind: "unnormalizedlagrangebasis", index: json.UnnormalizedLagrangeBasis };
        if (json.Mds != null) return { kind: "mds", row: json.Mds.row, col: json.Mds.col };
        if (json.Load != null) return { kind: "load", index: json.Load };
        if (json.Pow != null) return { kind: "pow", pow: json.Pow };
        if (json.SkipIf != null) return { kind: "skipif", num: json.SkipIf };
        if (json.SkipIfNot != null) return { kind: "skipifnot", num: json.SkipIfNot };
    }
    return undefined;
}

export function deserLinearization(json: LinearizationJSON): Linearization<PolishToken[]> {
    const constant_term = json.constant_term.map((t) => deserPolishToken(t)!);
    const index_terms = json.index_terms.map(([col, coeff]) =>
        [deserColumn(col), coeff.map((t) => deserPolishToken(t)!)] as [Column, PolishToken[]]);
    return { constant_term, index_terms };
}

export function deserVerifierIndex(json: VerifierIndexJSON): VerifierIndex {
    const {
        domain_size,
        domain_gen,
        max_poly_size,
        zk_rows,
        public_size,
        sigma_comm,
        coefficients_comm,
        generic_comm,
        psm_comm,
        complete_add_comm,
        mul_comm,
        emul_comm,
        endomul_scalar_comm,
        range_check0_comm,
        range_check1_comm,
        foreign_field_add_comm,
        foreign_field_mul_comm,
        xor_comm,
        rot_comm,
        //powers_of_alpha,
        shift,
        permutation_vanishing_polynomial_m,
        w,
        endo,
        linearization,
    } = json;

    let lookup_index: LookupVerifierIndex | undefined = undefined;
    if (json.lookup_index) {
        const patterns: LookupPatterns = json.lookup_index.lookup_info.features.patterns;
        const features: LookupFeatures = {
            ...json.lookup_index.lookup_info.features,
            patterns
        };
        const lookup_info: LookupInfo = {
            ...json.lookup_index.lookup_info,
            features
        };

        const json_selectors = json.lookup_index.lookup_selectors;
        const lookup_selectors: LookupSelectors = {
            xor: json_selectors.xor ? deserPolyComm(json_selectors.xor) : undefined,
            lookup: json_selectors.lookup ? deserPolyComm(json_selectors.lookup) : undefined,
            range_check: json_selectors.range_check ? deserPolyComm(json_selectors.range_check) : undefined,
            ffmul: json_selectors.ffmul ? deserPolyComm(json_selectors.ffmul) : undefined,
        }

        const lookup_table = json.lookup_index.lookup_table.map(deserPolyComm);
        const table_ids = json.lookup_index.table_ids
            ? deserPolyComm(json.lookup_index.table_ids)
            : undefined;
        const runtime_tables_selector = json.lookup_index.runtime_tables_selector
            ? deserPolyComm(json.lookup_index.runtime_tables_selector)
            : undefined;

        lookup_index = {
            ...json.lookup_index,
            lookup_table,
            lookup_selectors,
            table_ids,
            lookup_info,
            runtime_tables_selector
        };
    }

    // FIXME: hardcoded because of the difficulty of serializing this in Rust.
    // Alphas { next_power: 24, mapping: {Gate(Zero): (0, 21), Permutation: (21, 3)}, alphas: None }
    // this was generated from the verifier_circuit_tests/ crate.
    const powers_of_alpha = new Alphas(
        24,
        new Map([
            [ArgumentType.id({ kind: "gate", type: GateType.Zero }), [0, 21]],
            [ArgumentType.id({ kind: "permutation" }), [21, 3]]
        ]
        ));

    return new VerifierIndex(
        domain_size,
        deserHexScalar(domain_gen),
        max_poly_size,
        zk_rows,
        public_size,
        sigma_comm.map(deserPolyComm),
        coefficients_comm.map(deserPolyComm),
        deserPolyComm(generic_comm),
        deserPolyComm(psm_comm),
        deserPolyComm(complete_add_comm),
        deserPolyComm(mul_comm),
        deserPolyComm(emul_comm),
        deserPolyComm(endomul_scalar_comm),
        powers_of_alpha,
        shift.map(deserHexScalar),
        deserPolynomial(permutation_vanishing_polynomial_m),
        deserHexScalar(w),
        deserHexScalar(endo),
        deserLinearization(linearization),
        range_check0_comm ? deserPolyComm(range_check0_comm) : undefined,
        range_check1_comm ? deserPolyComm(range_check1_comm!) : undefined,
        foreign_field_add_comm ? deserPolyComm(foreign_field_add_comm) : undefined,
        foreign_field_mul_comm ? deserPolyComm(foreign_field_mul_comm) : undefined,
        xor_comm ? deserPolyComm(xor_comm) : undefined,
        rot_comm ? deserPolyComm(rot_comm) : undefined,
        lookup_index
    );
}
