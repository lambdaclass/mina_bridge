import { Field, Group, Scalar } from "o1js";
import { PolyComm } from "../poly_commitment/commitment";
import { SRS } from "../SRS";
import { Batch } from "./batching";
import { VerifierIndex } from "./verifier";
import proof_evals_json from "../../test/proof_evals.json" assert { type: "json" };
import { PointEvaluations } from "../prover/prover";
import { deserProofEvals } from "../serde/serde_proof";


test("toBatch() step 1", () => {
    const srs = SRS.createFromJSON();
    const domain_size = 32; // extracted from test in Rust.
    const vi: VerifierIndex = {
        srs: srs,
        domain_size: domain_size,
        public: 0
    };
    const proof_evals = deserProofEvals(proof_evals_json);
    const proof = {
        evals: proof_evals
    };

    let f_comm = Batch.toBatch(vi, proof, []); // upto step 2 implemented.
    let expected_f_comm = new PolyComm<Group>([
        Group({
            x: Field(0x221b959dacd2052aae26193fca36b53279866a4fbbab0d5a2f828b5fd7778201n),
            y: Field(0x058c8f1105cae57f4891eadc9b85c8954e5067190e155e61d66855ace69c16c0n)
        })
    ])
    expect(f_comm).toEqual(expected_f_comm)
})
