// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/sponge/Sponge.sol";
import "../lib/bn254/BN254.sol";

using {
    KeccakSponge.reinit,
    KeccakSponge.absorb_scalar,
    KeccakSponge.digest_scalar
} for Sponge;

contract KeccakSpongeTest is Test {
    Sponge sponge;

    function test_absorb_basefield() public {
        sponge.reinit();
        Scalar.FE input = Scalar.from(42);
        sponge.absorb_scalar(input);

        // TODO: assert sponge state

        Scalar.FE digest = sponge.digest_scalar();
        assertEq(
            Scalar.FE.unwrap(digest),
            0x00BECED09521047D05B8960B7E7BCC1D1292CF3E4B2A6B63F48335CBDE5F7545
        );
    }
}
