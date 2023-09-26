import { Field, Group } from "o1js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { deserProofEvals } from "../serde/serde_proof.js";
import { SRS } from "../SRS.js";
import { Batch } from "./batch.js";
import { VerifierIndex } from "./verifier.js";

import proof_evals_json from "../../test/proof_evals.json" assert { type: "json" };
import verifier_index_json from "../../test/verifier_index.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";
import { ProverProof } from "../prover/prover.js";

test("toBatch() step 1 and 2", () => {
    const srs = SRS.createFromJSON();
    const domain_size = 32; // extracted from test in Rust.
    const vi = deserVerifierIndex(verifier_index_json);
    const proof = new ProverProof(
        deserProofEvals(proof_evals_json),
        [],
        commitments,
    );

    let f_comm = Batch.toBatch(vi, proof, []); // upto step 2 implemented.
    let expected_f_comm = new PolyComm<Group>([
        Group({
            x: Field(0x221b959dacd2052aae26193fca36b53279866a4fbbab0d5a2f828b5fd7778201n),
            y: Field(0x058c8f1105cae57f4891eadc9b85c8954e5067190e155e61d66855ace69c16c0n)
        })
    ])
    expect(f_comm).toEqual(expected_f_comm)
})
