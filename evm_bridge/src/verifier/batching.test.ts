import { Field, Group } from "o1js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { deserProverProof } from "../serde/serde_proof.js";
import { SRS } from "../SRS.js";
import { Batch } from "./batch.js";

import proof_json from "../../test/proof.json" assert { type: "json" };
import verifier_index_json from "../../test/verifier_index.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";

test("toBatch() step 1 and 2", () => {
    const srs = SRS.createFromJSON();
    const domain_size = 32; // extracted from test in Rust.
    console.log("deser verifier_index")
    const vi = deserVerifierIndex(verifier_index_json);
    console.log("deser verifier_index");
    const proof = deserProverProof(proof_json);

    let f_comm = Batch.toBatch(vi, proof, []); // upto step 2 implemented.
    let expected_f_comm = new PolyComm<Group>([
        Group({
            x: Field(0x221b959dacd2052aae26193fca36b53279866a4fbbab0d5a2f828b5fd7778201n),
            y: Field(0x058c8f1105cae57f4891eadc9b85c8954e5067190e155e61d66855ace69c16c0n)
        })
    ])
    expect(f_comm).toEqual(expected_f_comm)
})
