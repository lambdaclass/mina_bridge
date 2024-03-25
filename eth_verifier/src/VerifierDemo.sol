// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Commitment.sol";
import "../lib/Oracles.sol";
import "../lib/Proof.sol";
import "../lib/State.sol";
import "../lib/VerifierIndex.sol";
import "../lib/Constants.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Alphas.sol";
import "../lib/Evaluations.sol";
import "../lib/expr/Expr.sol";
import "../lib/expr/PolishToken.sol";
import "../lib/expr/ExprConstants.sol";

using {BN254.neg, BN254.scale_scalar, BN254.sub} for BN254.G1Point;
using {Scalar.neg, Scalar.mul, Scalar.add, Scalar.inv, Scalar.sub, Scalar.pow} for Scalar.FE;
using {get_alphas} for Alphas;
using {it_next} for AlphasIterator;
using {Polynomial.evaluate} for Polynomial.Dense;
using {sub_polycomms, scale_polycomm} for PolyComm;
using {get_column_eval} for ProofEvaluationsArray;

contract KimchiVerifierDemo {
    State internal state;
    bool state_available;

    /// @notice this is currently deprecated but remains as to not break
    /// @notice the demo.
    function verify_state(bytes calldata state_serialized, bytes calldata proof_serialized) public returns (bool) {
        // 1. Deserialize proof and setup

        // For now, proof consists in the concatenation of the bytes that
        // represent the numerator, quotient and divisor polynomial
        // commitments (G1 and G2 points).

        // BEWARE: quotient must be negated.

        (BN254.G1Point memory numerator, BN254.G1Point memory quotient, BN254.G2Point memory divisor) =
            MsgPk.deserializeFinalCommitments(proof_serialized);

        bool success = BN254.pairingProd2(numerator, BN254.P2(), quotient, divisor);

        // 3. If success, deserialize and store state
        if (success) {
            store_state(state_serialized);
            state_available = true;
        }

        return success;
    }
    /// @notice store a mina state

    function store_state(bytes memory data) internal {
        state = MsgPk.deserializeState(data, 0);
    }

    /// @notice check if state is available
    function is_state_available() public view returns (bool) {
        return state_available;
    }
}
