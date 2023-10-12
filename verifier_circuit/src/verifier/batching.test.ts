import { Field, Group } from "o1js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { deserProverProof } from "../serde/serde_proof.js";
import { SRS } from "../SRS.js";
import { Batch } from "./batch.js";

import proof_json from "../../test/proof.json" assert { type: "json" };
import verifier_index_json from "../../test/verifier_index.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";

test("Partial verification integration test", () => {
    const srs = SRS.createFromJSON();
    const domain_size = 32; // extracted from test in Rust.
    const vi = deserVerifierIndex(verifier_index_json);
    const proof = deserProverProof(proof_json);

    Batch.toBatch(vi, proof, []); // upto step 2 implemented.
})
