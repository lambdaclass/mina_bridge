import { ForeignField } from "../src/foreign_fields/foreign_field";
import { fq_sponge_params, ArithmeticSponge, fq_sponge_initial_state } from "../src/verifier/sponge";

test("squeeze_internal", () => {
    let sponge = new ArithmeticSponge(fq_sponge_params());
    sponge.init(fq_sponge_initial_state());

    let digest = sponge.squeeze();
    let expected = 0x2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8n;

    digest.assertEquals(expected);
})

test("absorb_squeeze_internal", () => {
    let sponge = new ArithmeticSponge(fq_sponge_params());
    sponge.init(fq_sponge_initial_state());

    sponge.absorb(ForeignField.from(0x36FB00AD544E073B92B4E700D9C49DE6FC93536CAE0C612C18FBE5F6D8E8EEF2n));

    let digest = sponge.squeeze();
    let expected = 0x3D4F050775295C04619E72176746AD1290D391D73FF4955933F9075CF69259FBn;

    digest.assertEquals(expected);
})
