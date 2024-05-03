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
} for KeccakSponge.Sponge;

contract KeccakSpongeTest is Test {
    function test_absorb_digest_scalar() public {
        KeccakSponge.Sponge memory sponge;
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

    function test_digest_scalar() public {
        KeccakSponge.Sponge memory sponge;
        sponge.reinit();
        Scalar.FE digest = sponge.digest_scalar();

        assertEq(
            Scalar.FE.unwrap(digest),
            0x00C5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A4
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }

    function test_absorb_challenge_scalar() public {
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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
        KeccakSponge.Sponge memory sponge;
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

    function test_challenge_challenge_scalar() public {
        KeccakSponge.Sponge memory sponge;
        sponge.reinit();

        Scalar.FE challenge = sponge.challenge_scalar();
        assertEq(
            Scalar.FE.unwrap(challenge),
            0x0000000000000000000000000000000000C5D2460186F7233C927E7DB2DCC703
        );
        challenge = sponge.challenge_scalar();
        assertEq(
            Scalar.FE.unwrap(challenge),
            0x000000000000000000000000000000000010CA3EFF73EBEC87D2394FC58560AF
        );
        // INFO: reference value taken from analogous test in kzg_prover/sponge_tests.rs
    }
}
