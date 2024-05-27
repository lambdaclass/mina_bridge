import { ScalarChallenge } from "../src/verifier/scalar_challenge.js";
import { ForeignScalar } from "../src/foreign_fields/foreign_scalar";
import { test, expect } from "@jest/globals";
import { PointEvaluations, ProofEvaluations } from "../src/prover/prover.js";
import { stringifyWithBigInt } from "./helpers.js";
import { PolyComm } from "../src/poly_commitment/commitment.js";
import { ForeignPallas } from "../src/foreign_fields/foreign_pallas.js";

// This test has a twin in the 'verifier_circuit_tests' Rust crate.
test("toFieldWithLength", () => {
    const chal = new ScalarChallenge(ForeignScalar.from("0x123456789"));
    const endo_coeff = ForeignScalar.from(
        "0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1"
    );
    const length_in_bits = 10;

    const result = chal.toFieldWithLength(length_in_bits, endo_coeff);
    expect(result.toBigInt().toString()).toEqual(
        ForeignScalar.from("0x388fcbe4fef56d15d1e08ce81471cd60b753819eae172506b7c7afb1f1801665").toBigInt().toString()
    );
})

test("pointEvaluationsToFields", () => {
    const original = createPointEvaluations();

    const deserialized = PointEvaluations.fromFields(original.toFields());

    expect(stringifyWithBigInt(deserialized)).toEqual(stringifyWithBigInt(original));
});

test("proofEvaluationsWithNullsToFields", () => {
    const w = createPointEvaluationsArray(15);
    const z = createPointEvaluations();
    const s = createPointEvaluationsArray(6);
    const coefficients = createPointEvaluationsArray(15);
    const genericSelector = createPointEvaluations();
    const poseidonSelector = createPointEvaluations();
    const completeAddSelector = createPointEvaluations();
    const mulSelector = createPointEvaluations();
    const emulSelector = createPointEvaluations();
    const endomulScalarSelector = createPointEvaluations();

    const original = new ProofEvaluations(w,
        z,
        s,
        coefficients,
        genericSelector,
        poseidonSelector,
        completeAddSelector,
        mulSelector,
        emulSelector,
        endomulScalarSelector
    );

    const deserialized = ProofEvaluations.fromFields(original.toFields());

    expect(stringifyWithBigInt(deserialized)).toEqual(stringifyWithBigInt(original));
});

test("polyCommToFields", () => {
    const original = new PolyComm([ForeignPallas.generator as ForeignPallas]);

    const deserialized = PolyComm.fromFields(original.toFields(), 1);

    expect(stringifyWithBigInt(deserialized)).toEqual(stringifyWithBigInt(original));
})

function createPointEvaluations() {
    const zeta = ForeignScalar.from(42).assertAlmostReduced();
    const zetaOmega = ForeignScalar.from(80).assertAlmostReduced();
    return new PointEvaluations(zeta, zetaOmega);
}

function createPointEvaluationsArray(length: number): PointEvaluations[] {
    return Array(length).fill(createPointEvaluations());
}
