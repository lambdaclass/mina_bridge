use ark_ec::short_weierstrass_jacobian::GroupAffine;
use kimchi::{circuits::polynomials::generic::testing::create_circuit, prover_index::testing::new_index_for_test};

type Curve = GroupAffine<ark_bn254::g1::Parameters>;

/// Will create a KZG proof over a test circuit and serialize it into JSON.
/// This crate is based on `verifier_circuit_tests/` and the Kimchi test
/// "test_generic_gate_pairing".
fn main() {
    // Create test circuit
    let gates = create_circuit(0, 0);
    let num_gates = gates.len();

    let prover_index = new_index_for_test::<Curve>(gates, 0);
}
