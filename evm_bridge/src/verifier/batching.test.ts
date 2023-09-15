import { SRS } from "../SRS";
import { Batch, VerifierIndex } from "./Batching";

test("to_batch() step 1", () => {
    const srs = SRS.createFromJSON();
    console.log(srs.lagrange_bases.size);
    const domain_size = 32; // extracted from test in Rust.
    const vi: VerifierIndex = {
        srs: srs,
        domain_size: 1,
        public: 0
    };

    Batch.to_batch(vi, []);
})
