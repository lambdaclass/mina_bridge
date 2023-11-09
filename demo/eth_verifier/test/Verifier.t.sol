// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Verifier.sol";
import "../lib/BN254.sol";
import "../lib/Fields.sol";
import "../lib/msgpack/Deserialize.sol";

contract CounterTest is Test {
    function test_BN254_add_scale() public {
        BN254.G1Point memory g = BN254.P1();

        BN254.G1Point memory g_plus_g = BN254.add(g, g);
        BN254.G1Point memory two_g = BN254.add(g, g);

        assertEq(g_plus_g.x, two_g.x, "g + g should equal 2g");
        assertEq(g_plus_g.y, two_g.y, "g + g should equal 2g");
    }

    function test_pairing_check() public {
        bytes
            memory proof = hex"137B386B60C0B1EACD825BB5D7F8F9A75311C21BEB8A78AD4B1B917429DEB83C081677AECD36470CE9D97D4F7927F35B8D12315EF38A6E7D013866250B59CE892C5318092D9CFD60953C21CEC7596C081C244651BAB13D833D32C994713866320F62347F68390EF9243D355B0D5145E131BB25D9BD5FC198D6851C72CAFA647F1607206363F7EA00E0CE50C0B1DA51BAFE0B76CDCDDBAD364B0A4095CD589A19083C4DA5D257B99D25229FCF3B3885BB6D56FE821E8174C6F8F2B6671517F68B2692D3B51BB5602EEB3B9834B616E57FEE7283D7EA28F22E4263D78D90DB80A5003B6053211EE23338A695E2CFEFB1CE44D5458D0FB783A40F87C6D5C8AD90BE";
        (
            BN254.G1Point memory numerator,
            BN254.G1Point memory quotient,
            BN254.G2Point memory divisor
        ) = MsgPk.deserializeFinalCommitments(proof);

        assert(BN254.pairingProd2(numerator, BN254.P2(), quotient, divisor));
    }
}
