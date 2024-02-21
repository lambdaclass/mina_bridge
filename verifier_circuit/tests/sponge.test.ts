import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";
import { Sponge } from "../src/verifier/sponge";

test("absorb_digest_scalar", () => {
    let sponge = new Sponge();
    let input = ForeignScalar.from(42);
    sponge.absorbScalar(input);
    let digest = sponge.digest();

    digest.assertEquals(ForeignScalar.from(0x176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500n));
})
