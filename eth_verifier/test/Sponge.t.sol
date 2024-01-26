// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/sponge/Sponge.sol";
import "../lib/bn254/BN254.sol";

using {
    KeccakSponge.reinit,
    KeccakSponge.absorb_scalar,
    KeccakSponge.digest_scalar,
    KeccakSponge.challenge_scalar,
    KeccakSponge.absorb_base,
    KeccakSponge.digest_base,
    KeccakSponge.challenge_base
} for Sponge;

contract KeccakSpongeTest is Test {
    Sponge sponge;

    function test_absorb_digest_scalar() public {
        sponge.reinit();
        Scalar.FE input = Scalar.from(42);
        sponge.absorb_scalar(input);

        Scalar.FE digest = sponge.digest_scalar();
        assertEq(
            Scalar.FE.unwrap(digest),
            0x00BECED09521047D05B8960B7E7BCC1D1292CF3E4B2A6B63F48335CBDE5F7545
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    function test_absorb_challenge_scalar() public {
        sponge.reinit();
        Scalar.FE input = Scalar.from(42);
        sponge.absorb_scalar(input);

        Scalar.FE digest = sponge.challenge_scalar();
        assertEq(
            Scalar.FE.unwrap(digest),
            0x0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    // INFO: absorb_x_base tests are the same as absorb_x_scalar ones.
    function test_absorb_digest_base() public {
        sponge.reinit();
        Base.FE input = Base.from(42);
        sponge.absorb_base(input);

        Base.FE digest = sponge.digest_base();
        assertEq(
            Base.FE.unwrap(digest),
            0x00BECED09521047D05B8960B7E7BCC1D1292CF3E4B2A6B63F48335CBDE5F7545
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    // INFO: absorb_x_base tests are the same as absorb_x_scalar ones.
    function test_absorb_challenge_base() public {
        sponge.reinit();
        Base.FE input = Base.from(42);
        sponge.absorb_base(input);

        Base.FE digest = sponge.challenge_base();
        assertEq(
            Base.FE.unwrap(digest),
            0x0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }
}