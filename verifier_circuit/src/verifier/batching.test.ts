import { Field, ForeignGroup, Group, Provable } from "o1js";
import { PolyComm } from "../poly_commitment/commitment.js";
import { deserProverProof } from "../serde/serde_proof.js";
import { SRS } from "../SRS.js";
import { Batch } from "./batch.js";

import proof_json from "../../test/proof.json" assert { type: "json" };
import verifier_index_json from "../../test/verifier_index.json" assert { type: "json" };
import { deserVerifierIndex } from "../serde/serde_index.js";

test("Partial verification integration test", () => {
    ForeignGroup.curve = [
        "0", // a
        "5", // b
        "28948022309329048855892746252171976963363056481941560715954676764349967630337", // modulus
        "1", // gen_x
        "12418654782883325593414442427049395787963493412651469444558597405572177144507", // gen_y
        "28948022309329048855892746252171976963363056481941647379679742748393362948097" // order
    ];

    const srs = SRS.createFromJSON();
    const domain_size = 32; // extracted from test in Rust.
    const vi = deserVerifierIndex(verifier_index_json);
    const proof = deserProverProof(proof_json);

    Provable.runUnchecked(() => {
        Batch.toBatch(vi, proof, []); // upto step 2 implemented.
    });
})
