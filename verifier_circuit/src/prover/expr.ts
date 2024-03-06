import { Scalar } from "o1js";
import { Constants, PointEvaluations, ProofEvaluations } from "./prover.js";
import { invScalar, powScalar } from "../util/scalar.js";
import { GateType } from "../circuits/gate.js";
import { ForeignScalar } from "../foreign_fields/foreign_scalar.js";

/** A type representing one of the polynomials involved in the PLONK IOP */
export namespace Column {
    export type Witness = {
        kind: "witness"
        index: number
    }

    export type Z = {
        kind: "z"
    }

    export type Index = {
        kind: "index"
        typ: GateType
    }

    export type Coefficient = {
        kind: "coefficient"
        index: number
    }

    export type Permutation = {
        kind: "permutation"
        index: number
    }
}

export type Column =
    | Column.Witness
    | Column.Z
    | Column.Index
    | Column.Coefficient
    | Column.Permutation;

/**
 * A row accessible from a given row, corresponds to the fact that we open all polynomials
 * at `zeta` **and** `omega * zeta`
 */
export enum CurrOrNext {
    Curr,
    Next
}

/**
 * A type representing a variable which can appear in a constraint. It specifies a column
 * and a relative position (Curr or Next)
 */
export class Variable {
    col: Column
    row: CurrOrNext

    constructor(col: Column, row: CurrOrNext) {
        this.col = col;
        this.row = row;
    }

    evaluate(evals: ProofEvaluations<PointEvaluations<ForeignScalar>>): ForeignScalar {
        let point_evaluations: PointEvaluations<ForeignScalar> | undefined = undefined;
        switch (this.col.kind) {
            case "witness": {
                point_evaluations = evals.w[this.col.index];
                break;
            }
            case "z": {
                point_evaluations = evals.z;
                break;
            }
            case "index": {
                switch (this.col.typ) {
                    case GateType.Poseidon: {
                        point_evaluations = evals.poseidonSelector;
                        break;
                    }
                    case GateType.Generic: {
                        point_evaluations = evals.genericSelector;
                        break;
                    }
                    case GateType.CompleteAdd: {
                        point_evaluations = evals.completeAddSelector;
                        break;
                    }
                    case GateType.VarBaseMul: {
                        point_evaluations = evals.mulSelector;
                        break;
                    }
                    case GateType.EndoMul: {
                        point_evaluations = evals.emulSelector;
                        break;
                    }
                    case GateType.EndoMulScalar: {
                        point_evaluations = evals.endomulScalarSelector;
                        break;
                    }
                }
                break;
            }
            case "permutation": {
                point_evaluations = evals.s[this.col.index];
                break;
            }
            case "coefficient": {
                point_evaluations = evals.coefficients[this.col.index];
                break;
            }
        }
        return this.row === CurrOrNext.Curr
            ? point_evaluations!.zeta
            : point_evaluations!.zetaOmega;
    }
}

export namespace PolishToken {
    export type Alpha = {
        kind: "alpha"
    }
    export type Beta = {
        kind: "beta"
    }
    export type Gamma = {
        kind: "gamma"
    }
    export type JointCombiner = {
        kind: "jointcombiner"
    }
    export type EndoCoefficient = {
        kind: "endocoefficient"
    }
    export type Mds = {
        kind: "mds"
        row: number
        col: number
    }
    export type Literal = {
        kind: "literal"
        lit: ForeignScalar
    }
    export type Cell = {
        kind: "cell"
        cell: Variable
    }
    export type Dup = {
        kind: "dup"
    }
    export type Pow = {
        kind: "pow"
        pow: number
    }
    export type Add = {
        kind: "add"
    }
    export type Mul = {
        kind: "mul"
    }
    export type Sub = {
        kind: "sub"
    }
    export type VanishesOnZeroKnowledgeAndPreviousRows = {
        kind: "vanishesonzeroknowledgeandpreviousrows"
    }
    export type UnnormalizedLagrangeBasis = {
        kind: "unnormalizedlagrangebasis"
        index: number
    }
    export type Store = {
        kind: "store"
    }
    export type Load = {
        kind: "load"
        index: number
    }
    /** Skip the given number of tokens if the feature is enabled */
    export type SkipIf = {
        kind: "skipif"
        //feature: FeatureFlag // FIXME: impl
        num: number
    }
    /** Skip the given number of tokens if the feature is disabled */
    export type SkipIfNot = {
        kind: "skipifnot"
        //feature: FeatureFlag // FIXME: impl
        num: number
    }

    /** Evaluates a reverse polish notation expression into a field element */
    export function evaluate(
        toks: PolishToken[],
        pt: ForeignScalar,
        evals: ProofEvaluations<PointEvaluations<ForeignScalar>>,
        domain_gen: ForeignScalar,
        domain_size: number,
        c: Constants<ForeignScalar>
    ): ForeignScalar {
        let stack: ForeignScalar[] = [];
        let cache = [];

        let skip_count = 0;

        for (const t of toks) {
            if (skip_count > 0) {
                skip_count -= 1;
                continue;
            }

            switch (t.kind) {
                case "alpha": {
                    stack.push(c.alpha);
                    break;
                }
                case "beta": {
                    stack.push(c.beta);
                    break;
                }
                case "gamma": {
                    stack.push(c.gamma);
                    break;
                }
                case "jointcombiner": {
                    stack.push(c.joint_combiner!);
                    break;
                }
                case "endocoefficient": {
                    stack.push(c.endo_coefficient);
                    break;
                }
                case "mds": {
                    stack.push(c.mds[t.row][t.col]);
                    break;
                }
                case "vanishesonzeroknowledgeandpreviousrows": {
                    const ZK_ROWS = 3;
                    const w4 = powScalar(domain_gen, domain_size - (ZK_ROWS + 1));
                    const w3 = domain_gen.mul(w4);
                    const w2 = domain_gen.mul(w3);
                    const w1 = domain_gen.mul(w2);

                    stack.push(pt.sub(w1).mul(pt.sub(w2)).mul(pt.sub(w3)).mul(pt.sub(w4)));
                    break;
                }
                case "unnormalizedlagrangebasis": {
                    const omega_i = t.index < 0
                        ? invScalar(powScalar(domain_gen, -t.index))
                        : powScalar(domain_gen, t.index);

                    const vanishing_eval = powScalar(pt, domain_size).sub(Scalar.from(1));
                    const unnormal_lagrange_basis = vanishing_eval.div(pt.sub(omega_i));

                    stack.push(unnormal_lagrange_basis);
                    break;
                }
                case "literal": {
                    stack.push(t.lit);
                    break;
                }
                case "dup": {
                    stack.push(stack[stack.length - 1]);
                    break;
                }
                case "cell": {
                    stack.push(t.cell.evaluate(evals));
                    break;
                }
                case "pow": {
                    const i = stack.length - 1;
                    stack[i] = powScalar(stack[i], t.pow);
                    break;
                }
                case "add": {
                    const y = stack.pop()!;
                    const x = stack.pop()!;

                    stack.push(x.add(y));
                    break;
                }
                case "mul": {
                    const y = stack.pop()!;
                    const x = stack.pop()!;

                    stack.push(x.mul(y));
                    break;
                }
                case "sub": {
                    const y = stack.pop()!;
                    const x = stack.pop()!;

                    stack.push(x.sub(y));
                    break;
                }
                case "store": {
                    const x = stack[stack.length - 1];
                    cache.push(x);
                    break;
                }
                case "load": {
                    stack.push(cache[t.index]);
                    break;
                }
                case "skipif": {
                    // FIXME: implement
                    break;
                }
                case "skipifnot": {
                    // FIXME: implement
                    break;
                }
            }
        }

        return stack[0];
    }
}

export type PolishToken =
    | PolishToken.Alpha
    | PolishToken.Beta
    | PolishToken.Gamma
    | PolishToken.JointCombiner
    | PolishToken.EndoCoefficient
    | PolishToken.Mds
    | PolishToken.Literal
    | PolishToken.Cell
    | PolishToken.Dup
    | PolishToken.Pow
    | PolishToken.Add
    | PolishToken.Mul
    | PolishToken.Sub
    | PolishToken.VanishesOnZeroKnowledgeAndPreviousRows
    | PolishToken.UnnormalizedLagrangeBasis
    | PolishToken.Store
    | PolishToken.Load
    | PolishToken.SkipIf
    | PolishToken.SkipIfNot

/**
 * A linear combination of F coefficients of columns
 */
export class Linearization<F> {
    constant_term: F
    index_terms: [Column, F][]
}
