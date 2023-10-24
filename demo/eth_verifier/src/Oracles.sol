// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./primitives/Fields.sol";

library Oracles {
    using { to_field } for ScalarChallenge;

    function fiat_shamir() public view {
        // We'll skip the use of a sponge and generate challenges from pseudo-random numbers

        // Sample beta and gamma from the sponge
        Scalar.FE beta = challenge();
        Scalar.FE gamma = challenge();

        // Sample alpha prime
        ScalarChallenge memory alpha_chal = scalar_chal();
        // Derive alpha using the endomorphism
        Scalar.FE alpha = alpha_chal.to_field();
    }

    /// @notice creates a challenge frm hashing the current block timestamp.
    /// @notice this function is only going to be used for the demo and never in
    /// @notice a serious environment. DO NOT use this in any other case.
    function challenge() internal view returns (Scalar.FE) {
        Scalar.from(keccak256(abi.encode(block.timestamp)));
    }

    /// @notice creates a `ScaharChallenge` using `challenge()`.
    function scalar_chal() internal view returns (ScalarChallenge memory) {
        return ScalarChallenge(challenge());
    }

    struct ScalarChallenge {
        Scalar.FE chal;
    }

    function to_field(ScalarChallenge memory sc) public pure returns (Scalar.FE) {

    }
}
