// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/BN254.sol";
import "../lib/bn254/BN256G2.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Proof.sol";
import "../lib/Commitment.sol";

contract MessagePackTest is Test {
    VerifierIndexLib.VerifierIndex index;

    bytes public_inputs_serialized;

    // Reference test to check that g1Deserialize is correct, taking a point from
    // the circuit_gen crate as reference.
    function test_deserialize_g1point() public {
        BN254.G1Point memory p = BN254.G1Point(
            0x00D2C202A8673B721E5844D8AAE839EB1ABC62386A225545C694079ABF8752C1,
            0x0DF10F9AD0DF8AC9D2BDD487B530CF559B8F19F6F4CF1EB99132C12D4AA60C81
        );
        BN254.G1Point memory deserialized =
            BN254.g1Deserialize(0xc15287bf9a0794c64555226a3862bc1aeb39e8aad844581e723b67a802c2d200);

        assertEq(p.x, deserialized.x, "x not equal");
        assertEq(p.y, deserialized.y, "y not equal");
    }

    function test_deserialize_verifier_index() public {
        bytes memory verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        MsgPk.deser_verifier_index(MsgPk.new_stream(verifier_index_serialized), index);
        assertEq(index.public_len, 222);
        assertEq(index.max_poly_size, 8192);
        assertEq(index.zk_rows, 3);
        assertEq(index.domain_size, 8192);
        assertEq(
            Scalar.FE.unwrap(index.domain_gen),
            197302210312744933010843010704445784068657690384188106020011018676818793232
        );
    }

    function test_deserialize_g2point() public {
        // The test point is the first one of the verifier_srs
        bytes memory point_serialized =
            hex"edf692d95cbdde46ddda5ef7d422436779445c5e66006a42761e1f12efde0018c212f3aeb785e49712e7a9353349aaf1255dfb31b7bf60723a480d9293938e19";
        uint256 x0 = 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6ED;
        uint256 x1 = 0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2;
        uint256 y0 = 0x12C85EA5DB8C6DEB4AAB71808DCB408FE3D1E7690C43D37B4CE6CC0166FA7DAA;
        uint256 y1 = 0x090689D0585FF075EC9E99AD690C3395BC4B313370B38EF355ACDADCD122975B;

        BN254.G2Point memory point = BN256G2.G2Deserialize(point_serialized);

        assertEq(point.x0, x0, "x0 is not correct");
        assertEq(point.x1, x1, "x1 is not correct");
        assertEq(point.y0, y0, "y0 is not correct");
        assertEq(point.y1, y1, "y1 is not correct");
    }

    function test_deserialize_scalar() public {
        bytes memory scalar_serialized = hex"550028f667d034768ec0a14ac5f5a24bbcad7117110fc65b7529e003a0708419";
        Scalar.FE scalar = MsgPk.deser_scalar(scalar_serialized);
        assertEq(Scalar.FE.unwrap(scalar), 0x198470A003E029755BC60F111771ADBC4BA2F5C54AA1C08E7634D067F6280055);
    }

    function test_deserialize_public_input() public {
        public_inputs_serialized = vm.readFileBinary("public_inputs.mpk");
        Scalar.FE[] memory public_inputs = MsgPk.deser_public_inputs(public_inputs_serialized);
        assertEq(Scalar.FE.unwrap(public_inputs[2]), 0x000000000000000000000000000000000000000000002149A7476FD365F3E060);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("linearization.mpk");
        MsgPk.deser_linearization(MsgPk.new_stream(linearization_serialized), index);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_decode_linearization_profiling_only() public {
        bytes memory linearization_rlp = vm.readFileBinary("linearization.rlp");
        abi.decode(linearization_rlp, (Linearization));
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_lagrange_bases_profiling_only() public {
        bytes memory lagrange_bases_serialized = vm.readFileBinary("lagrange_bases.mpk");
        MsgPk.deser_lagrange_bases(lagrange_bases_serialized);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_verifier_index_profiling_only() public {
        bytes memory verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        MsgPk.deser_verifier_index(MsgPk.new_stream(verifier_index_serialized), index);
    }

    // INFO: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_public_inputs_profiling_only() public {
        bytes memory public_inputs_serialized = vm.readFileBinary("public_inputs.mpk");
        MsgPk.deser_public_inputs(public_inputs_serialized);
    }
}
