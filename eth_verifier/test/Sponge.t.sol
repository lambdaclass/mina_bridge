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
    KeccakSponge.challenge_base,
    KeccakSponge.absorb_g
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

    function test_absorb_digest_g() public {
        sponge.reinit();
        BN254.G1Point[] memory input = new BN254.G1Point[](1);
        input[0] = BN254.P1();
        sponge.absorb_g(input);

        Scalar.FE digest = sponge.digest_scalar();
        assertEq(
            Scalar.FE.unwrap(digest),
            0x00E90B7BCEB6E7DF5418FB78D8EE546E97C83A08BBCCC01A0644D599CCD2A7C2
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    function test_absorb_absorb_digest_scalar() public {
        sponge.reinit();
        Scalar.FE[2] memory inputs = [Scalar.from(42), Scalar.from(24)];
        sponge.absorb_scalar(inputs[0]);
        sponge.absorb_scalar(inputs[1]);

        Scalar.FE digest = sponge.digest_scalar();
        assertEq(
            Scalar.FE.unwrap(digest),
            0x00DB760B992492E99DAE648DBA78682EB78FAFF3B40E0DB291710EFCB8A7D0D3
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    function test_absorb_challenge_challenge_scalar() public {
        sponge.reinit();
        Scalar.FE input = Scalar.from(42);
        sponge.absorb_scalar(input);

        Scalar.FE[2] memory digests = [sponge.challenge_scalar(), sponge.challenge_scalar()];
        assertEq(
            Scalar.FE.unwrap(digests[0]),
            0x0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D
        );
        assertEq(
            Scalar.FE.unwrap(digests[1]),
            0x0000000000000000000000000000000000964765235251D0E2EACFBC25925D55
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }
    function test_absorb_challenge_absorb_challenge_scalar() public {
        sponge.reinit();
        Scalar.FE[2] memory inputs = [Scalar.from(42), Scalar.from(24)];

        sponge.absorb_scalar(inputs[0]);
        Scalar.FE challenge = sponge.challenge_scalar();
        assertEq(
            Scalar.FE.unwrap(challenge),
            0x0000000000000000000000000000000000BECED09521047D05B8960B7E7BCC1D
        );
        sponge.absorb_scalar(inputs[1]);
        challenge = sponge.challenge_scalar();
        assertEq(
            Scalar.FE.unwrap(challenge),
            0x0000000000000000000000000000000000D9E16B1DA42107514692CD8896E64F
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }
}
