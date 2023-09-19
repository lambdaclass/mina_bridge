import { Scalar } from "o1js"
import { PointEvaluations } from "../prover/prover"

namespace SerdeJSON {
    interface PointEvalsJSON {
        zeta: string[]
        zeta_omega: string[]
    }
    interface LookupEvaluationsJSON {
        sorted: PointEvalsJSON[]
        aggreg: PointEvalsJSON
        table: PointEvalsJSON
        runtime?: PointEvalsJSON
    }
    interface ProofEvalsJSON {
        w: PointEvalsJSON[] // of size 15, total num of registers (columns)
        z: PointEvalsJSON
        s: PointEvalsJSON[] // of size 7 - 1, total num of wirable registers minus one
        coefficients: PointEvalsJSON[] // of size 15, total num of registers (columns)
        lookup?: LookupEvaluationsJSON
        generic_selector: PointEvalsJSON
        poseidon_selector: PointEvalsJSON
    }

    type Evals = PointEvaluations<Scalar[]>;
    function deserPointEval(json: PointEvalsJSON): PointEvaluations {
        const zeta = SerdeJSON.deserScalars(json.zeta);
        const zeta_omega = SerdeJSON.deserScalars(json.zeta_omega);
    }
    function deserProofEvals(evals: ProofEvalsJSON): Evals {

    }
}
