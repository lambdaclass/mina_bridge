import { ForeignField } from "../src/foreign_fields/foreign_field";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";
import { ArithmeticSponge, fp_sponge_initial_state, fp_sponge_params, fq_sponge_initial_state, fq_sponge_params, Sponge } from "../src/verifier/sponge";

test("squeeze_internal", () => {
    let sponge = new ArithmeticSponge(fp_sponge_params());
    sponge.init(fp_sponge_initial_state());

    let digest = sponge.squeeze();
    let expected = 0x2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8n;

    digest.assertEquals(expected);
})

test("absorb_squeeze_internal", () => {
    let sponge = new ArithmeticSponge(fp_sponge_params());
    sponge.init(fp_sponge_initial_state());

    sponge.absorb(ForeignField.from(0x36FB00AD544E073B92B4E700D9C49DE6FC93536CAE0C612C18FBE5F6D8E8EEF2n));

    let digest = sponge.squeeze();
    let expected = 0x3D4F050775295C04619E72176746AD1290D391D73FF4955933F9075CF69259FBn;

    digest.assertEquals(expected);
})

test("absorb_digest_scalar", () => {
    let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());
    fq_sponge.absorbScalar(ForeignScalar.from(42));
    let digest = fq_sponge.digest();

    digest.assertEquals(0x176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500n);
})
