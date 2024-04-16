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
    VerifierIndex index;

    bytes public_inputs_serialized;

    // Test to check that the destructuring of the message pack byte array is correct.
    // If we know that g1Deserialize() is correct, then this asserts that the whole
    // deserialization is working.
    function test_deserialize_urs() public {
        // Data was taken from running the circuit_gen crate.

        bytes memory urs_serialized =
            hex"92dc0020c4200100000000000000000000000000000000000000000000000000000000000000c42055a8e8d2b2221c2e7641eb8f5b656e352c9e7b5aca91da8ca92fe127e7fb2c21c42003bc09f3825fafdefe1cb25b4a296b60f2129a1c3a90826c3dc2021be421aa8ec4206422698aa4f80a088fd4e0d3a3cd517c2cb1f280cb95c9313823b8f8060f1786c4203558cb03f0cf841ed3a8145a7a8084e182731a9628779ef59d3bc47bae8a1192c4202ac41dd231cb8e97ffc3281b20e6799c0ae18afc13d3de1b4b363a0cd070baa7c420b6205dfa129f52601adfd87829901f06f1fd32e22a71f44b769d674448f05d83c4205d1b9b83cdcba66ff9424c7242c67394d7956dabf5407f4105124b7239d43e80c420e95ffc0999a8997b045430aa564c7bd9a25303e8a5ebbe4a99f6329b7f2a64aac4206cca50f1237f867fee63ac65249d6911494680f42d0e71386b1586be39092f9cc4204b9b17d64b384a65d7c80c8ab0f5fff75c69fd147835599753beea03152a3923c4205c0f706b036ed361e787af70acea3533d6e349869e83368979fdbbf382a4900bc420da6652a81754a6263e677d23a55bd729205f5fb64fa39b6771d9b811e5548bafc4208db1ad69d758362a4ecacff98a6910a95b3c2697e455271b2d7c078f1894eb1fc42010f56f1046a1121b1df5c401969b5acbf80eef8bfd5438270e09243413382788c4200cca37d1a3a721792dc232bb6a95bd14143350b6784bcdd4898a0bb34dd8bd2cc4202b7a1991e05b77d911d15ae590ff6f6ad7d1ed572b34654e3ce92e38e4839425c4201977ca4631e9eea53c7ba59d334c14dac7ee1071d6bf6ebf2ab7450c16975d23c4209eb742379ee8664a8bf9c18a40a534bb2961020bd0077cd0b603d2a8b9fe5a17c4201c50af6002db8dfa5a310ce795dcb06de94ead6687687263fd59acbc8612f180c4205241cbed55fbe1193f366e7ea8ad11bc97742eb35ca39129c4931b9bef64df1ec420646e69eb7d4682ad6bff24d40bf22184694c569246385cc127b3ec4a99875a85c42046b77ed1e120130743344ea9372ea58118604c730800e0d7038f2c80211f4f90c4208f20f3c39a09b5615bd8b2a09eec7dbc11b5ea1f8fe7eb0d5a69c1264412d199c42095f0b87ed771c169a8b6c0a6e21b13ab715407a4e6637a0b8fe0a1e3278f32a7c420a80440e1a07157bad23d7a7d3ddd7445f578021650016fc4bfb3324ed967c82bc4202b94fd0b89e7e2c9d245a4e94a539b14c5db26ed5ba4b3989ef0ba0712d4582ec42068f583079aa73425184a328127be63421eae683a25be94a0aa697ce74b5b972dc4209fa10b770e452852612ea392b8521683999d0a168c5eb85a6925d1ffe21d418ac420826a0976821c9309ed896678a97634a2fb1392a64ab8c59c8380012ffb601189c4203096ba3ed0b597fa29da6caa9000a409702b1f945561e82d02ab77b0cfdb649fc4204a718bc27174d557e036bcbcb9874ce5a6e1a63ccbe491e509d4201bfcb50806c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c250a";

        (BN254.G1Point[] memory g, BN254.G1Point memory h, uint256 _i) = MsgPk.deserializeURS(urs_serialized);

        BN254.G1Point[32] memory expected_g = [
            BN254.g1Deserialize(0x0100000000000000000000000000000000000000000000000000000000000000),
            BN254.g1Deserialize(0x55a8e8d2b2221c2e7641eb8f5b656e352c9e7b5aca91da8ca92fe127e7fb2c21),
            BN254.g1Deserialize(0x03bc09f3825fafdefe1cb25b4a296b60f2129a1c3a90826c3dc2021be421aa8e),
            BN254.g1Deserialize(0x6422698aa4f80a088fd4e0d3a3cd517c2cb1f280cb95c9313823b8f8060f1786),
            BN254.g1Deserialize(0x3558cb03f0cf841ed3a8145a7a8084e182731a9628779ef59d3bc47bae8a1192),
            BN254.g1Deserialize(0x2ac41dd231cb8e97ffc3281b20e6799c0ae18afc13d3de1b4b363a0cd070baa7),
            BN254.g1Deserialize(0xb6205dfa129f52601adfd87829901f06f1fd32e22a71f44b769d674448f05d83),
            BN254.g1Deserialize(0x5d1b9b83cdcba66ff9424c7242c67394d7956dabf5407f4105124b7239d43e80),
            BN254.g1Deserialize(0xe95ffc0999a8997b045430aa564c7bd9a25303e8a5ebbe4a99f6329b7f2a64aa),
            BN254.g1Deserialize(0x6cca50f1237f867fee63ac65249d6911494680f42d0e71386b1586be39092f9c),
            BN254.g1Deserialize(0x4b9b17d64b384a65d7c80c8ab0f5fff75c69fd147835599753beea03152a3923),
            BN254.g1Deserialize(0x5c0f706b036ed361e787af70acea3533d6e349869e83368979fdbbf382a4900b),
            BN254.g1Deserialize(0xda6652a81754a6263e677d23a55bd729205f5fb64fa39b6771d9b811e5548baf),
            BN254.g1Deserialize(0x8db1ad69d758362a4ecacff98a6910a95b3c2697e455271b2d7c078f1894eb1f),
            BN254.g1Deserialize(0x10f56f1046a1121b1df5c401969b5acbf80eef8bfd5438270e09243413382788),
            BN254.g1Deserialize(0x0cca37d1a3a721792dc232bb6a95bd14143350b6784bcdd4898a0bb34dd8bd2c),
            BN254.g1Deserialize(0x2b7a1991e05b77d911d15ae590ff6f6ad7d1ed572b34654e3ce92e38e4839425),
            BN254.g1Deserialize(0x1977ca4631e9eea53c7ba59d334c14dac7ee1071d6bf6ebf2ab7450c16975d23),
            BN254.g1Deserialize(0x9eb742379ee8664a8bf9c18a40a534bb2961020bd0077cd0b603d2a8b9fe5a17),
            BN254.g1Deserialize(0x1c50af6002db8dfa5a310ce795dcb06de94ead6687687263fd59acbc8612f180),
            BN254.g1Deserialize(0x5241cbed55fbe1193f366e7ea8ad11bc97742eb35ca39129c4931b9bef64df1e),
            BN254.g1Deserialize(0x646e69eb7d4682ad6bff24d40bf22184694c569246385cc127b3ec4a99875a85),
            BN254.g1Deserialize(0x46b77ed1e120130743344ea9372ea58118604c730800e0d7038f2c80211f4f90),
            BN254.g1Deserialize(0x8f20f3c39a09b5615bd8b2a09eec7dbc11b5ea1f8fe7eb0d5a69c1264412d199),
            BN254.g1Deserialize(0x95f0b87ed771c169a8b6c0a6e21b13ab715407a4e6637a0b8fe0a1e3278f32a7),
            BN254.g1Deserialize(0xa80440e1a07157bad23d7a7d3ddd7445f578021650016fc4bfb3324ed967c82b),
            BN254.g1Deserialize(0x2b94fd0b89e7e2c9d245a4e94a539b14c5db26ed5ba4b3989ef0ba0712d4582e),
            BN254.g1Deserialize(0x68f583079aa73425184a328127be63421eae683a25be94a0aa697ce74b5b972d),
            BN254.g1Deserialize(0x9fa10b770e452852612ea392b8521683999d0a168c5eb85a6925d1ffe21d418a),
            BN254.g1Deserialize(0x826a0976821c9309ed896678a97634a2fb1392a64ab8c59c8380012ffb601189),
            BN254.g1Deserialize(0x3096ba3ed0b597fa29da6caa9000a409702b1f945561e82d02ab77b0cfdb649f),
            BN254.g1Deserialize(0x4a718bc27174d557e036bcbcb9874ce5a6e1a63ccbe491e509d4201bfcb50806)
        ];

        for (uint256 i = 0; i < expected_g.length; i++) {
            assertEq(expected_g[i].x, g[i].x, "g.x not equal");
            assertEq(expected_g[i].y, g[i].y, "g.y not equal");
        }

        BN254.G1Point memory expected_blinding =
            BN254.g1Deserialize(0x723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25);

        assertEq(expected_blinding.x, h.x, "blinding x not equal");
        assertEq(expected_blinding.y, h.y, "blinding y not equal");
    }

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
    function test_deserialize_verifier_index_profiling_only() public {
        bytes memory verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        deser_verifier_index(verifier_index_serialized, index);
    }
}
