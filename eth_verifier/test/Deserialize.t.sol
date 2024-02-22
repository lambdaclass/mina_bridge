// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/BN254.sol";
import "../lib/bn254/BN256G2.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Proof.sol";
import "../lib/Commitment.sol";

contract DeserializeTest is Test {
    VerifierIndex index;
    ProverProof prover_proof;

    PairingURS test_urs;

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
            memory verifier_index_serialized = vm.readFileBinary("verifier_index.mpk");
        MsgPk.deser_verifier_index(
            MsgPk.new_stream(verifier_index_serialized),
            index
        );
        assertEq(index.public_len, 0);
        assertEq(index.max_poly_size, 16384);
        assertEq(index.zk_rows, 3);
        assertEq(index.domain_size, 16384);
        assertEq(
            Scalar.FE.unwrap(index.domain_gen),
            20619701001583904760601357484951574588621083236087856586626117568842480512645
        );
    }

    function test_deserialize_prover_proof() public {
        // The serialized proof was manually modified to make `public_evals`
        // equal to 256.
        bytes memory prover_proof_serialized =
            hex"85ab636f6d6d69746d656e747384a6775f636f6d6d9f82a9756e7368696674656491c4206935ae9e140addfe95e028f9bf1620729a0e18389ab148ae0735c9c4e75c9984a773686966746564c082a9756e7368696674656491c4206789d2d0b670c01845699306a6db91175fd8cd1a3b58d55a2dc3317adcc5dc83a773686966746564c082a9756e7368696674656491c420c882feb297262b0171e7936928aa59ea51a05dfbf604ddf786f21d971f83539fa773686966746564c082a9756e7368696674656491c420fa0c22ad5966d5f122b8e59e2b4cca8e4e0e1be46cd12f9b4a36e085a064050fa773686966746564c082a9756e7368696674656491c420ec88ff12baf48b783b3c678ca89910699b3f21cdbb98e20447164f1b702f8680a773686966746564c082a9756e7368696674656491c420e2c3896e3decacc5c38bb547b6fdbdfadaf8c527716837103bee3660b31ca787a773686966746564c082a9756e7368696674656491c4209a19d062e3484422d72079a99accded4253e6ed6ab5a2d460670fc66408e548da773686966746564c082a9756e7368696674656491c4208c6caac3b1da0c39ac9fc08a9fd72ef6c91ec2ca1e3d8483214271b854adb9a6a773686966746564c082a9756e7368696674656491c420b12ddb3439761649daf866cd46ef2e66497f004c37c3677bff35d4e2bf23b615a773686966746564c082a9756e7368696674656491c420e5306c4845cc2f8416f7479911f48f6f7e4273d4ddef09a7faaa919753d8b4a4a773686966746564c082a9756e7368696674656491c4207343fef815f29c8f41b49300213c841ad5e5a03fe35313c568c1f96cc391d812a773686966746564c082a9756e7368696674656491c420923578448c30581853193b5707675afb34a3861a849e208b21136566c840c991a773686966746564c082a9756e7368696674656491c420f1b89c0f9a5cb31f5e0e575a06eadee9d3e9f04bf178367f10cf0e668648b022a773686966746564c082a9756e7368696674656491c420d9fe0d6bfc2f4a58fa556bcbe7da579f1cfae8f52be4583bbe723ecbdb227196a773686966746564c082a9756e7368696674656491c420fe9910b396f321ea32bbe563d405b6f8b039138800e144514c8fcf4439581f98a773686966746564c0a67a5f636f6d6d82a9756e7368696674656491c420ff243bbda9f7012c3b5ba4aa817cba4d65120e59d69e2be0093da124829b4385a773686966746564c0a6745f636f6d6d82a9756e7368696674656497c4201ee14120df34e5fdbd80d88b4e6c55e9a9964def37bfe10c7cac34a24807e486c42084ff50302d19048886516ffac31415d101121c7169f9cf60c0f01a3779c71e28c4206a45051b7dd1183c7a7a14a46bc8b84265e08d3f5fe5e44dd8eeb5f8419c7fa1c42023d03c0e40233dd0596f9fd48aea02907fca14e0a9e26f6bc5da55efd2cff02ac4204d178913ecd692fd8576b8725e356f069bde26f594b9d4b87612ceaa7d259ca0c420b65b75106639788de613f6f60e95fd845ba6191f8b489a0f2bf8619157137c2bc420fd11c9d9de7e0b6b4bfbe96c4b7a1ad008b2269e477f08b684515d044ceb5a13a773686966746564c0a66c6f6f6b757083a6736f727465649582a9756e7368696674656491c4200dd84e666f8c7bf563006f398704b8f098753a05ad7f742800a86a58332665a1a773686966746564c082a9756e7368696674656491c420930db5d930835fabf6395f81dee7be5ca57168f00cafad5cdfc087f370cb2384a773686966746564c082a9756e7368696674656491c420252be6fdff90d3674e15ce344e774e762b237d593ee1beacf4d77cd73bdae629a773686966746564c082a9756e7368696674656491c4208a7abf577cbd09cff4a5c72b7631f54250b9e27ea806a6927e529b83f2178b9fa773686966746564c082a9756e7368696674656491c420e64dae24ad63c160adbb38753e0258f37b4fe762bbcd0a5eb71fc888ba0fda04a773686966746564c0a661676772656782a9756e7368696674656491c420d4b5482db0accf6afcca5965c5b1c46be67eac803ac8c6d234888b6eeba74d29a773686966746564c0a772756e74696d65c0a570726f6f6682a871756f7469656e74c420e998807cf1c4cd728e98de8f65cacb705e08f21f3991576dd4b92097ff4b1204a8626c696e64696e67c4203e1c424b8a056420adf81ce3b2ada534b95a591331c3e3ff24de8e21e5d60107a56576616c73de001aa67075626c696382a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000a1779f82a47a65746191c420bc97fe06e7783528d63920d43f5a92f6bd0d5180f8e2b11bbda6c976a3fedd2faa7a6574615f6f6d65676191c42035fed3c3989e995a2fd0cf760285eb7d6d3d3ce41e74b7151af6ef39b57e091e82a47a65746191c420cc73112ce2f1092a9333b51e8bf1afb7839af457b80b267d3be22f6d04c4850daa7a6574615f6f6d65676191c420d4c6b22f0f6da9d06dd231a6bd0b13766cb7a7a9bfefd5e67c4f04a4a381581282a47a65746191c4204dfbe1983238a810816000f7f0cbe2a094197884e86c7afbddd00eae700fdb20aa7a6574615f6f6d65676191c4202c39cedb698ce3afdc42a7cefc01a7aa76381f651f7913148a10d484f057d60b82a47a65746191c4205c5c257ee02c055357898b7d7213d6f887c4f9c0b88493cd67f2b0227ebe9700aa7a6574615f6f6d65676191c42055eebae9237958438ba13fcb94fd7ae32f4dc30403f4aa7ebf81fd2b3a2ab22682a47a65746191c4205cc0af7c97be7dfa1c37551fda5a9174e89936783391028dd36313e35fdbaa1caa7a6574615f6f6d65676191c42014050891924b28e67670fea22df1fb024090c72f5884660092830627144d6a1682a47a65746191c42088881086560e8576c992de73bdcb57068c864a2baee67f259bf93265e347d924aa7a6574615f6f6d65676191c4203abab358dce1e579c61b9687cc322416525604575b5c770b4df99a6ffe9f3d0982a47a65746191c420b1492c7d158676a3339521274d90b59e6291248e8db7a710c0279a3f7712981daa7a6574615f6f6d65676191c420a02725fcd27f8252d5d27fd38f84a36dacdd86c43ca62f26bffed88cb378af1382a47a65746191c420dc4fdeeca67ae8093c6eddf883fe3a14778cd90e1f39146a193600ed3b474e14aa7a6574615f6f6d65676191c4203206480022dcf87594a7e29f0b84e507ee1b5078d05a403c0e50d70b1193190f82a47a65746191c4204d1ae5f86ca1bc7162aff7fb96423352817c2f10fabc8d263984ff5657c63d0caa7a6574615f6f6d65676191c4206e225f51ed452dd65fc95a8a3f9c8b3d674ebf3aedf939f820802125e492192e82a47a65746191c42061f157833a4a893898b7d711adfd65a54b090cbec68d2254a918a36ec4dc2420aa7a6574615f6f6d65676191c4200c3c0cfa1cb99c96d3d0ca82045528a0ce015a6960cadaa948d495ab88bc5b1c82a47a65746191c420ebc13fdb1662e6ca6ca52baab3a291c2fa5a39fa4c52f1985fb675363ee7de21aa7a6574615f6f6d65676191c42074d4e49b2ec668d4c1dc9c1ae0cd0542c43b33e11468bfce17d6755e6c6bad0482a47a65746191c4205be292942e6a5eedaf12dd7ebbe7650ad9bce9bbfd303a91f1eb9555998ded1faa7a6574615f6f6d65676191c420a94c29b8359f603e203e44e7cfb6145a8ed37bd026ef8e0e1498778268e74c2182a47a65746191c420cd1ec3d1733487206be37b55f4e83c5abd503078ea3d24c75732ca2660618d23aa7a6574615f6f6d65676191c42012af82c7750cd0f034cdbce36b701d937712134363e80277dac3f9ac73ed751682a47a65746191c4204b118fab9c7e426df32ed9d14103980121cf35e6d5ab06bfef205d5ca4a50121aa7a6574615f6f6d65676191c420f4742710b138c09409766f7f554fe189b202ecb96898f8e13898192c5f1f3d1c82a47a65746191c42052c688d6f0aed2b4024153f725e6943b3cd5225d946b838f99ab078b79cdc90baa7a6574615f6f6d65676191c42077d2d3057eaabb2a5de47dec5d626e42e8456e06eb1faf6547da6470a91f7c29a17a82a47a65746191c4203104b53af3a9f1379a6771f881b276ba87427f79abee1970e747562122b13b0caa7a6574615f6f6d65676191c420d47aa1f86bdbaa76f25be2189736fc30f6ba9114bc2ff2b748fefde906454612a1739682a47a65746191c42062012fa0ab130dd2d3ab16cd84ba197d6040bd3f1b09f3c9ca161031b6eb4b1baa7a6574615f6f6d65676191c42081e7a64f810604d6a2581ccf30e98b0bde23ea2bceb64c048c820a94d9caa51782a47a65746191c4202eecc3e7c447befc1fb49918d42c90172619b5119d1be924ae7fb1104491640daa7a6574615f6f6d65676191c420441351923f868c4946e8da6d88858a108664c61c31fd247ecb260e4078d7162e82a47a65746191c420f52dbcb18124dd0d8a70dbf4b04995017578b0c129b39adc1a92f7914df83211aa7a6574615f6f6d65676191c420207a97d7d275fa178be35f4ff1c3f1fff8c667de2992be74472438bffccd3d2d82a47a65746191c420261504d94d05664587440ec38edec7890bd1509ee387492a5f0716b2bdfb4408aa7a6574615f6f6d65676191c42065187880a4baaacb0459086c961754bee157f1df32e801cf739530eaaeb8a70a82a47a65746191c420e5b790019e04cf3fee75f33037c81f8644a6cfece4bb6ba16c79ac07ce3da320aa7a6574615f6f6d65676191c420eefe7feaa6d2dd3ed9c9d26725e1e1e3a98a9dd327de38da81a2f9dc97a8dc0f82a47a65746191c420e8f351672051c5ca776aec4d3b1fcc3aa3d8330ac43b2ea2bbc6a4c59f07a503aa7a6574615f6f6d65676191c4206c53ac2da4d51af59c61160b1b93643c1dd770f60fce02a002ebd6207a68382cac636f656666696369656e74739f82a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c420000000000000000000000000000000000000000000000000000000000000000082a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000b067656e657269635f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000b1706f736569646f6e5f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000b5636f6d706c6574655f6164645f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000ac6d756c5f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000ad656d756c5f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000b7656e646f6d756c5f7363616c61725f73656c6563746f7282a47a65746191c4200000000000000000000000000000000000000000000000000000000000000000aa7a6574615f6f6d65676191c4200000000000000000000000000000000000000000000000000000000000000000b572616e67655f636865636b305f73656c6563746f7282a47a65746191c420f3f70bd2769f3a0d8f0b2231b1a564acb1f299de4999f78f9183cc7a7ca57504aa7a6574615f6f6d65676191c4203834661a99441a2cb6520aba2cfaba3009a4c64f97446265dd7a039b29ce2720b572616e67655f636865636b315f73656c6563746f7282a47a65746191c42010ef15a91f17bdab56cb555664085be8634acfd2af9803cb2740c58b80e6d80caa7a6574615f6f6d65676191c420db0022ab464e121e9b051a1d1164b870863380a2411802835617d73ea5996b25ba666f726569676e5f6669656c645f6164645f73656c6563746f72c0ba666f726569676e5f6669656c645f6d756c5f73656c6563746f72c0ac786f725f73656c6563746f72c0ac726f745f73656c6563746f72c0b26c6f6f6b75705f6167677265676174696f6e82a47a65746191c420fc7abb225fe0d418d4353732bb8627a31db3cd5bcd95eb43626ecb841079c61faa7a6574615f6f6d65676191c42079d07c4163feaa2573b437bbfcef217ab013e74abd8d145816dfe84f0a265a28ac6c6f6f6b75705f7461626c6582a47a65746191c42091694f1de3627d4b87e9e79f02854752fb2bdc19384680cc99845f4d2e9cf319aa7a6574615f6f6d65676191c420e0266130e428ce5e5dbfb15192ebbe48df87b5ea2150ff15455cc3b475518a22ad6c6f6f6b75705f736f727465649582a47a65746191c42079d6a2ce34b4accf35779f217e851dae6fda9c1a9b95d938263bd34314f5a515aa7a6574615f6f6d65676191c4202de79af84b4218353ff988ed948cd8af45d6329dd5ae4c3e29d4d67ce8f73a1b82a47a65746191c420379fc04d0cc5e6ebfb617a42c2406c4be7f21ac25ef4d21fd4514cb53466e21caa7a6574615f6f6d65676191c42089f21132e71fb38b64651891238a31784a508fd4c30c8b7fe4c2fa9af873c10182a47a65746191c4204eea855e112d7059e4d3c38c89932f6dd813f2d13ff4dc27efb4bfadcb83221faa7a6574615f6f6d65676191c420a11892def190bb5c53bdd13fedc7da9707cac2708467808d28e2d7520d9a020082a47a65746191c42031ed4c9f814b6b314096ddb3b53d9d3955fc76c759fc82e3e2afe1bb23f5721faa7a6574615f6f6d65676191c420e0d1269db43a33a5c5e77497ef4522e2bbb83b4ab29707b2b85386c153b80f0482a47a65746191c420e8fc0057a0cee221d521e16983bff803a067b63d5e0acb49f2dafeb07b4a9b17aa7a6574615f6f6d65676191c4209dc7e7fdd2e6359f3da1912299971bdd469b5d32d985d8cc05ecfe80fe2b2910b472756e74696d655f6c6f6f6b75705f7461626c65c0bd72756e74696d655f6c6f6f6b75705f7461626c655f73656c6563746f72c0b3786f725f6c6f6f6b75705f73656c6563746f72c0bb6c6f6f6b75705f676174655f6c6f6f6b75705f73656c6563746f72c0bb72616e67655f636865636b5f6c6f6f6b75705f73656c6563746f7282a47a65746191c420517e8a23ec132ac7a7d5fa5639a2d0a5bba51a3eba6eacf3367811dc088eeb13aa7a6574615f6f6d65676191c42022249e7e6bb407b216b3c0b3597e9a6196c99443d2af17fb31326e84dcff0722d921666f726569676e5f6669656c645f6d756c5f6c6f6f6b75705f73656c6563746f72c0a866745f6576616c31c42079026db760b0ccc05c2024fadd23abc5a3850d8abd637ed8bc60a1d187834a1caf707265765f6368616c6c656e676573900a";
        MsgPk.deser_prover_proof(
            MsgPk.new_stream(prover_proof_serialized),
            prover_proof
        );

        assertEq(
            Scalar.FE.unwrap(prover_proof.evals.public_evals.zeta[0]),
            0
        );
        assertEq(
            Scalar.FE.unwrap(prover_proof.evals.z.zeta[0]),
            5533220689073489467242585629359101481453882954673496142211507198539584570417
        );
    }

    function test_deserialize_g2point() public {
        // The test point is the first one of the verifier_srs
        bytes
            memory point_serialized = hex"edf692d95cbdde46ddda5ef7d422436779445c5e66006a42761e1f12efde0018c212f3aeb785e49712e7a9353349aaf1255dfb31b7bf60723a480d9293938e19";
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

    function test_deserialize_pairing_urs() public {
        bytes memory urs_serialized = vm.readFileBinary("urs.mpk");

        MsgPk.deser_pairing_urs(MsgPk.new_stream(urs_serialized), test_urs);

        // first point
        assertEq(test_urs.verifier_urs.g[0].x0, 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6ED, "x0 point 0");
        assertEq(test_urs.verifier_urs.g[0].x1, 0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2, "x1 point 0");
        assertEq(test_urs.verifier_urs.g[0].y0, 0x12C85EA5DB8C6DEB4AAB71808DCB408FE3D1E7690C43D37B4CE6CC0166FA7DAA, "y0 point 0");
        assertEq(test_urs.verifier_urs.g[0].y1, 0x090689D0585FF075EC9E99AD690C3395BC4B313370B38EF355ACDADCD122975B, "y1 point 0");

        // second point
        assertEq(test_urs.verifier_urs.g[1].x0, 0x116DA8C89A0D090F3D8644ADA33A5F1C8013BA7204AECA62D66D931B99AFE6E7, "x0 point 1");
        assertEq(test_urs.verifier_urs.g[1].x1, 0x12740934BA9615B77B6A49B06FCCE83CE90D67B1D0E2A530069E3A7306569A91, "x1 point 1");
        assertEq(test_urs.verifier_urs.g[1].y0, 0x076441042E77B6309644B56251F059CF14BEFC72AC8A6157D30924E58DC4C172, "y0 point 1");
        assertEq(test_urs.verifier_urs.g[1].y1, 0x25222D9816E5F86B4A7DEDD00D04ACC5C979C18BD22B834EA8C6D07C0BA441DB, "y1 point 1");

        // third point
        assertEq(test_urs.verifier_urs.g[2].x0, 0x1F3C07CB202A4703327B7AA545EBD51936CC75A927E5EA44900FDA7212F20DA5, "x0 point 2");
        assertEq(test_urs.verifier_urs.g[2].x1, 0x0A4292251D61B69443EF8D46761F92C88FF566B5FA90D261E3BEBD5706F94FF7, "x1 point 2");
        assertEq(test_urs.verifier_urs.g[2].y0, 0x227496FC46FCD4887801FE92F5D62804B7B26EAB126B4F4E7A5F255FAE7089E4, "y0 point 2");
        assertEq(test_urs.verifier_urs.g[2].y1, 0x1DAE1514DF395BF6B03BD82FE153C56D7419845B00D9592E637660BA8F4F339D, "y1 point 2");
    }

    // WARN: this doesn't assert anything, it only executes this deserialization
    // for gas profiling.
    function test_deserialize_linearization_profiling_only() public {
        bytes memory linearization_serialized = vm.readFileBinary("unit_test_data/linearization.mpk");
        MsgPk.deser_linearization(MsgPk.new_stream(linearization_serialized), index);
    }

    function test_deserialize_scalar() public {
        bytes memory scalar_serialized = hex"550028f667d034768ec0a14ac5f5a24bbcad7117110fc65b7529e003a0708419";
        Scalar.FE scalar = MsgPk.deser_scalar(scalar_serialized);
        assertEq(Scalar.FE.unwrap(scalar), 0x198470A003E029755BC60F111771ADBC4BA2F5C54AA1C08E7634D067F6280055);
    }
}
