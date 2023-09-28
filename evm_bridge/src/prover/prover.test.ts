import { Scalar } from "o1js";
import { ScalarChallenge } from "./prover"

// This test has a twin in the 'verify_circuit_tests' Rust crate.
test("toFieldWithLength", () => {
    const chal = new ScalarChallenge(Scalar.from("0x123456789"));
    const endo_coeff = Scalar.from(
        "0x397e65a7d7c1ad71aee24b27e308f0a61259527ec1d4752e619d1840af55f1b1"
    );
    const length_in_bits = 10;

    const result = chal.toFieldWithLength(length_in_bits, endo_coeff);
    expect(result).toEqual(
        Scalar.from("0x388fcbe4fef56d15d1e08ce81471cd60b753819eae172506b7c7afb1f1801665")
    );
})
