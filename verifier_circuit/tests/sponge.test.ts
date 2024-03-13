import { ProvableBn254 } from "o1js";
import { ForeignBase } from "../src/foreign_fields/foreign_field";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";
import { ArithmeticSponge, fp_sponge_initial_state, fp_sponge_params, fq_sponge_initial_state, fq_sponge_params, Sponge } from "../src/verifier/sponge";

test("squeeze_internal", () => {
    ProvableBn254.runAndCheck(() => {
        let sponge = new ArithmeticSponge(fp_sponge_params());
        sponge.init(fp_sponge_initial_state());

        let digest = ProvableBn254.witness(ForeignBase.provable, () => {
            return sponge.squeeze();
        });

        digest.assertEquals(0x2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8n);
    });
})

test("fr_squeeze_internal", () => {
    Provable.runAndCheck(() => {
        let sponge = new ArithmeticSponge(fq_sponge_params());
        sponge.init(fq_sponge_initial_state());

        let digest = Provable.witnessBn254(ForeignBase, () => {
            return sponge.squeeze();
        });

        digest.assertEquals(0x3A3374A061464EC0AAC7E0FF04346926C579D542F9D205A670CE4C18C004E5C1n);
    });
})

test("absorb_squeeze_internal", () => {
    ProvableBn254.runAndCheck(() => {
        let sponge = new ArithmeticSponge(fp_sponge_params());
        sponge.init(fp_sponge_initial_state());

        sponge.absorb(ForeignBase.from(0x36FB00AD544E073B92B4E700D9C49DE6FC93536CAE0C612C18FBE5F6D8E8EEF2n));

        let digest = ProvableBn254.witness(ForeignBase.provable, () => {
            return sponge.squeeze();
        });

        digest.assertEquals(0x3D4F050775295C04619E72176746AD1290D391D73FF4955933F9075CF69259FBn);
    });
})

test("fr_absorb_squeeze_internal", () => {
    Provable.runAndCheck(() => {
        let sponge = new ArithmeticSponge(fq_sponge_params());
        sponge.init(fq_sponge_initial_state());

        sponge.absorb(ForeignScalar.from(0x42));

        let digest = Provable.witnessBn254(ForeignScalar, () => {
            return sponge.squeeze();
        });

        digest.assertEquals(0x393DDD2CE7E8CC8F929F9D70F25257B924A085542E3C039DD8B04BEA0E885DCBn);
    });
})

test("digest_scalar", () => {
    ProvableBn254.runAndCheck(() => {
        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());
        let digest = fq_sponge.digest();

        digest.assertEquals(0x2FADBE2852044D028597455BC2ABBD1BC873AF205DFABB8A304600F3E09EEBA8n);
    });
})

test("absorb_digest_scalar", () => {
    ProvableBn254.runAndCheck(() => {
        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());
        fq_sponge.absorbScalar(ForeignScalar.from(42));
        let digest = fq_sponge.digest();

        digest.assertEquals(0x176AFDF43CB26FAE41117BEADDE5BE80E5D06DD18817A7A8C11794A818965500n);
    });
})

test("fr_absorb_digest_scalar", () => {
    Provable.runAndCheck(() => {
        let fr_sponge = new Sponge(fq_sponge_params(), fq_sponge_initial_state());
        fr_sponge.absorb(ForeignScalar.from(42));
        let digest = fr_sponge.digest();

        digest.assertEquals(0x15D31425CD40BB52E708D4E85DF366F62A9194688826F6555035DC65497D5B26n);
    });
})

test("absorb_challenge", () => {
    Provable.runAndCheck(() => {
        let fq_sponge = new Sponge(fp_sponge_params(), fp_sponge_initial_state());
        fq_sponge.absorbScalar(ForeignScalar.from(42));
        let digest = fq_sponge.challenge();

        digest.assertEquals(0x00000000000000000000000000000000E5D06DD18817A7A8C11794A818965500n);
    });
})
