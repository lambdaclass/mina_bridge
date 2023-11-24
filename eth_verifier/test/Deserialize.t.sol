// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/BN254.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";

contract DeserializeTest is Test {
    // Test to check that the destructuring of the message pack byte array is correct.
    // If we know that g1Deserialize() is correct, then this asserts that the whole
    // deserialization is working.
    function test_deserialize_opening_proof() public {
        // Data was taken from running the circuit_gen crate.

        bytes
            memory opening_proof_serialized = hex"92c42004082c5fa22d4d2bf78f2aa71269510911c1b414b8bedfe41afb3c7147f99325c42017a3bfd724d88bf23ed3d13155cd09c0a4d1d1d520b869599f00958810100621";

        Kimchi.ProverProof memory proof = MsgPk.deserializeOpeningProof(
            opening_proof_serialized
        );

        BN254.G1Point memory expected_quotient = BN254.g1Deserialize(
            0x04082c5fa22d4d2bf78f2aa71269510911c1b414b8bedfe41afb3c7147f99325
        );
        uint256 expected_blinding = 0x17a3bfd724d88bf23ed3d13155cd09c0a4d1d1d520b869599f00958810100621;

        assertEq(
            proof.opening_proof_blinding,
            expected_blinding,
            "wrong blinding"
        );
        assertEq(
            proof.opening_proof_quotient.x,
            expected_quotient.x,
            "wrong quotient x"
        );
        assertEq(
            proof.opening_proof_quotient.y,
            expected_quotient.y,
            "wrong quotient y"
        );
    }

    // Test to check that the destructuring of the message pack byte array is correct.
    // If we know that g1Deserialize() is correct, then this asserts that the whole
    // deserialization is working.
    function test_deserialize_urs() public {
        // Data was taken from running the circuit_gen crate.

        bytes
            memory urs_serialized = hex"92dc0020c4200100000000000000000000000000000000000000000000000000000000000000c42055a8e8d2b2221c2e7641eb8f5b656e352c9e7b5aca91da8ca92fe127e7fb2c21c42003bc09f3825fafdefe1cb25b4a296b60f2129a1c3a90826c3dc2021be421aa8ec4206422698aa4f80a088fd4e0d3a3cd517c2cb1f280cb95c9313823b8f8060f1786c4203558cb03f0cf841ed3a8145a7a8084e182731a9628779ef59d3bc47bae8a1192c4202ac41dd231cb8e97ffc3281b20e6799c0ae18afc13d3de1b4b363a0cd070baa7c420b6205dfa129f52601adfd87829901f06f1fd32e22a71f44b769d674448f05d83c4205d1b9b83cdcba66ff9424c7242c67394d7956dabf5407f4105124b7239d43e80c420e95ffc0999a8997b045430aa564c7bd9a25303e8a5ebbe4a99f6329b7f2a64aac4206cca50f1237f867fee63ac65249d6911494680f42d0e71386b1586be39092f9cc4204b9b17d64b384a65d7c80c8ab0f5fff75c69fd147835599753beea03152a3923c4205c0f706b036ed361e787af70acea3533d6e349869e83368979fdbbf382a4900bc420da6652a81754a6263e677d23a55bd729205f5fb64fa39b6771d9b811e5548bafc4208db1ad69d758362a4ecacff98a6910a95b3c2697e455271b2d7c078f1894eb1fc42010f56f1046a1121b1df5c401969b5acbf80eef8bfd5438270e09243413382788c4200cca37d1a3a721792dc232bb6a95bd14143350b6784bcdd4898a0bb34dd8bd2cc4202b7a1991e05b77d911d15ae590ff6f6ad7d1ed572b34654e3ce92e38e4839425c4201977ca4631e9eea53c7ba59d334c14dac7ee1071d6bf6ebf2ab7450c16975d23c4209eb742379ee8664a8bf9c18a40a534bb2961020bd0077cd0b603d2a8b9fe5a17c4201c50af6002db8dfa5a310ce795dcb06de94ead6687687263fd59acbc8612f180c4205241cbed55fbe1193f366e7ea8ad11bc97742eb35ca39129c4931b9bef64df1ec420646e69eb7d4682ad6bff24d40bf22184694c569246385cc127b3ec4a99875a85c42046b77ed1e120130743344ea9372ea58118604c730800e0d7038f2c80211f4f90c4208f20f3c39a09b5615bd8b2a09eec7dbc11b5ea1f8fe7eb0d5a69c1264412d199c42095f0b87ed771c169a8b6c0a6e21b13ab715407a4e6637a0b8fe0a1e3278f32a7c420a80440e1a07157bad23d7a7d3ddd7445f578021650016fc4bfb3324ed967c82bc4202b94fd0b89e7e2c9d245a4e94a539b14c5db26ed5ba4b3989ef0ba0712d4582ec42068f583079aa73425184a328127be63421eae683a25be94a0aa697ce74b5b972dc4209fa10b770e452852612ea392b8521683999d0a168c5eb85a6925d1ffe21d418ac420826a0976821c9309ed896678a97634a2fb1392a64ab8c59c8380012ffb601189c4203096ba3ed0b597fa29da6caa9000a409702b1f945561e82d02ab77b0cfdb649fc4204a718bc27174d557e036bcbcb9874ce5a6e1a63ccbe491e509d4201bfcb50806c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c250a";

        (BN254.G1Point[] memory g, BN254.G1Point memory h, uint256 _i) = MsgPk
            .deserializeURS(urs_serialized);

        BN254.G1Point[32] memory expected_g = [
            BN254.g1Deserialize(
                0x0100000000000000000000000000000000000000000000000000000000000000
            ),
            BN254.g1Deserialize(
                0x55a8e8d2b2221c2e7641eb8f5b656e352c9e7b5aca91da8ca92fe127e7fb2c21
            ),
            BN254.g1Deserialize(
                0x03bc09f3825fafdefe1cb25b4a296b60f2129a1c3a90826c3dc2021be421aa8e
            ),
            BN254.g1Deserialize(
                0x6422698aa4f80a088fd4e0d3a3cd517c2cb1f280cb95c9313823b8f8060f1786
            ),
            BN254.g1Deserialize(
                0x3558cb03f0cf841ed3a8145a7a8084e182731a9628779ef59d3bc47bae8a1192
            ),
            BN254.g1Deserialize(
                0x2ac41dd231cb8e97ffc3281b20e6799c0ae18afc13d3de1b4b363a0cd070baa7
            ),
            BN254.g1Deserialize(
                0xb6205dfa129f52601adfd87829901f06f1fd32e22a71f44b769d674448f05d83
            ),
            BN254.g1Deserialize(
                0x5d1b9b83cdcba66ff9424c7242c67394d7956dabf5407f4105124b7239d43e80
            ),
            BN254.g1Deserialize(
                0xe95ffc0999a8997b045430aa564c7bd9a25303e8a5ebbe4a99f6329b7f2a64aa
            ),
            BN254.g1Deserialize(
                0x6cca50f1237f867fee63ac65249d6911494680f42d0e71386b1586be39092f9c
            ),
            BN254.g1Deserialize(
                0x4b9b17d64b384a65d7c80c8ab0f5fff75c69fd147835599753beea03152a3923
            ),
            BN254.g1Deserialize(
                0x5c0f706b036ed361e787af70acea3533d6e349869e83368979fdbbf382a4900b
            ),
            BN254.g1Deserialize(
                0xda6652a81754a6263e677d23a55bd729205f5fb64fa39b6771d9b811e5548baf
            ),
            BN254.g1Deserialize(
                0x8db1ad69d758362a4ecacff98a6910a95b3c2697e455271b2d7c078f1894eb1f
            ),
            BN254.g1Deserialize(
                0x10f56f1046a1121b1df5c401969b5acbf80eef8bfd5438270e09243413382788
            ),
            BN254.g1Deserialize(
                0x0cca37d1a3a721792dc232bb6a95bd14143350b6784bcdd4898a0bb34dd8bd2c
            ),
            BN254.g1Deserialize(
                0x2b7a1991e05b77d911d15ae590ff6f6ad7d1ed572b34654e3ce92e38e4839425
            ),
            BN254.g1Deserialize(
                0x1977ca4631e9eea53c7ba59d334c14dac7ee1071d6bf6ebf2ab7450c16975d23
            ),
            BN254.g1Deserialize(
                0x9eb742379ee8664a8bf9c18a40a534bb2961020bd0077cd0b603d2a8b9fe5a17
            ),
            BN254.g1Deserialize(
                0x1c50af6002db8dfa5a310ce795dcb06de94ead6687687263fd59acbc8612f180
            ),
            BN254.g1Deserialize(
                0x5241cbed55fbe1193f366e7ea8ad11bc97742eb35ca39129c4931b9bef64df1e
            ),
            BN254.g1Deserialize(
                0x646e69eb7d4682ad6bff24d40bf22184694c569246385cc127b3ec4a99875a85
            ),
            BN254.g1Deserialize(
                0x46b77ed1e120130743344ea9372ea58118604c730800e0d7038f2c80211f4f90
            ),
            BN254.g1Deserialize(
                0x8f20f3c39a09b5615bd8b2a09eec7dbc11b5ea1f8fe7eb0d5a69c1264412d199
            ),
            BN254.g1Deserialize(
                0x95f0b87ed771c169a8b6c0a6e21b13ab715407a4e6637a0b8fe0a1e3278f32a7
            ),
            BN254.g1Deserialize(
                0xa80440e1a07157bad23d7a7d3ddd7445f578021650016fc4bfb3324ed967c82b
            ),
            BN254.g1Deserialize(
                0x2b94fd0b89e7e2c9d245a4e94a539b14c5db26ed5ba4b3989ef0ba0712d4582e
            ),
            BN254.g1Deserialize(
                0x68f583079aa73425184a328127be63421eae683a25be94a0aa697ce74b5b972d
            ),
            BN254.g1Deserialize(
                0x9fa10b770e452852612ea392b8521683999d0a168c5eb85a6925d1ffe21d418a
            ),
            BN254.g1Deserialize(
                0x826a0976821c9309ed896678a97634a2fb1392a64ab8c59c8380012ffb601189
            ),
            BN254.g1Deserialize(
                0x3096ba3ed0b597fa29da6caa9000a409702b1f945561e82d02ab77b0cfdb649f
            ),
            BN254.g1Deserialize(
                0x4a718bc27174d557e036bcbcb9874ce5a6e1a63ccbe491e509d4201bfcb50806
            )
        ];

        for (uint256 i = 0; i < expected_g.length; i++) {
            assertEq(expected_g[i].x, g[i].x, "g.x not equal");
            assertEq(expected_g[i].y, g[i].y, "g.y not equal");
        }

        BN254.G1Point memory expected_blinding = BN254.g1Deserialize(
            0x723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25
        );

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
        BN254.G1Point memory deserialized = BN254.g1Deserialize(
            0xc15287bf9a0794c64555226a3862bc1aeb39e8aad844581e723b67a802c2d200
        );

        assertEq(p.x, deserialized.x, "x not equal");
        assertEq(p.y, deserialized.y, "y not equal");
    }

    function test_deserialize_verifier_index() public {
        bytes
            memory verifier_index_serialized = hex"de0015a6646f6d61696ec4ac00200000000000000d00000000200000000000000000000000000000000000000000000000000000000000000180604384d657bfc5a27537a9a64a65524ccd53348302b79c969a6d50cb623010d3bd9b8d9ba44a762d3a8ee2f31bd37b66b278c8ea1d0062ae69b849ab6f00c95dd9ab5a200b3bca888197fa74dfc8c8b61c6adb24e1080461acbf58ed7016676666c6d4fbf3e7062d4acae95caea98b56cd337cb5b949aad9135a94525b13ad6d61785f706f6c795f73697a65cd4000a77a6b5f726f777303a67075626c696300af707265765f6368616c6c656e67657300aa7369676d615f636f6d6d9782a9756e7368696674656491c420364315ea1fe73fc3478a9823dc4a927119ff6e633fb41812a5605c9fc0ac72aaa773686966746564c082a9756e7368696674656491c420633a980d5940136aeb4eaa2145aad94dbbc1acd0ee911544ca9d65a8f860a40ca773686966746564c082a9756e7368696674656491c42011230853b13814d3fb7a1c6994c21e23ba083abe94ceaad63feffe686091b49da773686966746564c082a9756e7368696674656491c4201baa6d070773617ef0658e4a622a5a67497fbe8b91b905aacba29ba17f42741ea773686966746564c082a9756e7368696674656491c4208669bcc973be53b864a28e652f04ab5cf72ca20f246819dd6f15ad3d8d51f5a3a773686966746564c082a9756e7368696674656491c4201e3002266069d0191ba82c889749d17c4a22a7f2d85d0487d2df57d8f2a28094a773686966746564c082a9756e7368696674656491c420017b22822869b290ff28ac82a15e68b6003236e4154fe9f8f40fb374dcd5338fa773686966746564c0b1636f656666696369656e74735f636f6d6d9f82a9756e7368696674656491c420f08c0c257c5ec41234224482a6d9b42635b662425b25b86f8a60eddd8b8ccfa5a773686966746564c082a9756e7368696674656491c42078fce52175dd1b6afa55bcf432537240a066e61ccff2b30ebb46e99d5e2c3500a773686966746564c082a9756e7368696674656491c4203c8fecd0515ad1740d07a906080ced3300e0a185eafb7fe48b7f4af017d0e48ea773686966746564c082a9756e7368696674656491c4207c3532ca64a3ec2778fab0ef5b3ed566de2bbb34410bcc7cac35d43ceee62320a773686966746564c082a9756e7368696674656491c420894cf4855baaf3744ecd1251074f05530ba28700a331e659e796bfda9e3b941fa773686966746564c082a9756e7368696674656491c420df8aafd9d21ae04c63f3a70c8ef668b894e938961f5fc2a4451634aa272d7286a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c082a9756e7368696674656491c420434278e55a777606754cee725607035dba64830be1d3852409d80e0b36f71224a773686966746564c082a9756e7368696674656491c420cb201e2a3088fc2a7fe8c8bbcc77548db0df19c7cc053388323998b657a1f886a773686966746564c082a9756e7368696674656491c4208d944ead72329988cc3c56026a8e0f2827c9d9a694441f0fbca64c6c1aed5a84a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c082a9756e7368696674656491c4200000000000000000000000000000000000000000000000000000000000000040a773686966746564c0ac67656e657269635f636f6d6d82a9756e7368696674656491c4201af163363acc703294827809a39e668d2782ebcaf872d06f16576f6b996531a7a773686966746564c0a870736d5f636f6d6d82a9756e7368696674656491c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25a773686966746564c0b1636f6d706c6574655f6164645f636f6d6d82a9756e7368696674656491c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25a773686966746564c0a86d756c5f636f6d6d82a9756e7368696674656491c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25a773686966746564c0a9656d756c5f636f6d6d82a9756e7368696674656491c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25a773686966746564c0b3656e646f6d756c5f7363616c61725f636f6d6d82a9756e7368696674656491c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c25a773686966746564c0b172616e67655f636865636b305f636f6d6d82a9756e7368696674656491c420191418104060244c3c0e4aaa96c0e68a3f09a8319dff7e3909f8f6c8ca62ee8da773686966746564c0b172616e67655f636865636b315f636f6d6d82a9756e7368696674656491c42081542bf55ad01c67c1f5ff901f7e3a55395206e6d1aff8040862052238673d2ba773686966746564c0b6666f726569676e5f6669656c645f6164645f636f6d6d82a9756e7368696674656491c420f41e7e08a4db448418f5596f62f687dcbc6eb7a55a4d93b7cfdea37197027b02a773686966746564c0b6666f726569676e5f6669656c645f6d756c5f636f6d6dc0a8786f725f636f6d6dc0a8726f745f636f6d6dc0a5736869667497c4200100000000000000000000000000000000000000000000000000000000000000c420e3a214e91334d0caf1eb85df5bd7524d73d5eb7aaf742a7eb2d40bfdc8cdb900c4206d0f44339a339fb8a4e49bf1099620aa649918482b95a397ae39b9ec5ad47700c420b40923bd78e619c80a7b39c0f3f11e48005519d2fef16a1f77d40545e5c77700c420f9c95cd6b11b38df7855fd4d2a036329adcad613f100b923109540356a597c00c4205a696526fa309c412c10e86604c3c0ad2cd9443dd85b823203721281cfbf3300c42043423bb307cec19f297c4188deb23acc7b5812719b2eaccbf1b7034ae6ace800ac6c6f6f6b75705f696e64657886b16a6f696e745f6c6f6f6b75705f75736564c2ac6c6f6f6b75705f7461626c659182a9756e7368696674656491c42059149f1484af342fa425e9f230ca246babfab7cdd72d0ff5bc3d1176614cce2da773686966746564c0b06c6f6f6b75705f73656c6563746f727384a3786f72c0a66c6f6f6b7570c0ab72616e67655f636865636b82a9756e7368696674656491c4204f4763225f13070a3c7d728bb86526080c7d75c4a6928ab8940c2c49b1d97c8ca773686966746564c0a566666d756cc0a97461626c655f69647382a9756e7368696674656491c420211e5d946fbeb572bb16898a1a1f8fef49484671f4a1ba7e746898276befff1ea773686966746564c0ab6c6f6f6b75705f696e666f83ab6d61785f7065725f726f7704ae6d61785f6a6f696e745f73697a6501a8666561747572657383a87061747465726e7384a3786f72c2a66c6f6f6b7570c2ab72616e67655f636865636bc3b1666f726569676e5f6669656c645f6d756cc2b16a6f696e745f6c6f6f6b75705f75736564c2b3757365735f72756e74696d655f7461626c6573c2b772756e74696d655f7461626c65735f73656c6563746f72c0";
        MsgPk.deser_verifier_index(MsgPk.from_data(verifier_index_serialized));
    }
}
