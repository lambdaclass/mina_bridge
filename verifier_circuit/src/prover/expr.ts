import { Scalar } from "o1js";
import { Constants, PointEvaluations, ProofEvaluations } from "./prover";
import { invScalar, powScalar } from "../util/scalar";

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
    // FIXME: this is lookup related
    //export type JointCombiner = {
        //kind: "jointcombiner"
    //}
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
        lit: Scalar
    }
    export type Cell = {
        kind: "cell"
        //cell: Variable // FIXME: implement
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
    export type VanishesOnLast4Rows = {
        kind: "vanishesonlast4rows"
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
        pt: Scalar,
        evals: ProofEvaluations<PointEvaluations<Scalar>>,
        domain_gen: Scalar,
        domain_size: number,
        c: Constants<Scalar>
    ): Scalar {
        let stack: Scalar[] = [];
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
                case "gamma": {
                    stack.push(c.gamma);
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
                case "vanishesonlast4rows": {
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
                    // FIXME: implement
                    evals; // leave this temporarily so evals isn't unused
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
    | PolishToken.EndoCoefficient
    | PolishToken.Mds
    | PolishToken.Literal
    | PolishToken.Cell
    | PolishToken.Dup
    | PolishToken.Pow
    | PolishToken.Add
    | PolishToken.Mul
    | PolishToken.Sub
    | PolishToken.VanishesOnLast4Rows
    | PolishToken.UnnormalizedLagrangeBasis
    | PolishToken.Store
    | PolishToken.Load
    | PolishToken.SkipIf
    | PolishToken.SkipIfNot
