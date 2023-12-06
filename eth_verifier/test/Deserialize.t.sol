// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/BN254.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";

contract DeserializeTest is Test {
    VerifierIndex index;

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
            memory verifier_index_serialized = hex"DE0015A6646F6D61696E82A474797065A6427566666572A464617461DC00AC00400000000000000E00000000400000000000000000000000000000000000000000000000000000000000000140CCB0190CCCE6CC9CCC81CCABCC89CC97CCD87847CCBFCCC65752CCA76A7564CCA937631B66CCA7CCE1CC8C6330CC856E7C61CCC201CCAACCADCCE6CCAA2074CCE13ECCA9CCB4CCA8CCA8CCDC0DCCB8514E1FCC81CCE4CCD9CCCD5156CC962D10CC841C6434CCE9CCEECCF8CCC0717767CCB07609CCF4CC8C6ECC8E55420D6811CCE9CCE9CCE7066F031C28676666CCC6CCD4CCFBCCF3CCE7062D4ACCCACCE95CCCAECCA9CC8B56CCCD337CCCB5CCB949CCAACCD9135ACC94525B13AD6D61785F706F6C795F73697A65CD4000A77A6B5F726F777303A67075626C696300AF707265765F6368616C6C656E67657300AA7369676D615F636F6D6D9782A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC8E6A46CCC4CC9A5B053E3ACCD03ACCCACC896319CCAB43CC88CCAFCC887ECC84CCBC3DCCACCCFB49CCAB67CCDDCC93CC8AA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200F751F4138CC9FCCEFCCCACCC43ACCB9CCA01B0810CCAB2CCCB74C70CCDFCCD8CC9521CCC7CCA0CCCFCCA15019CCDECCA4A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00205CCC903D4275CC90CC98CC987ACCE8CCA0CC946A33CCDACCB8CCBB386052CC93CCDF725A29CCC840CCF4CC87CCD6CCABCC99A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCDD7526CCDDCC86CCA2CC9CCCD6CC8F0ACC937E062E56CCD25E3250CC90CC86CCC958CC84CCE0CCA5CC9701CC99CC8F7BCCA5A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC964300CC855F1C7BCCB37B55CC854C582F48CCC54938CCAB48CC815BCCD64A5ACCC62DCC8C37CCDDCCE403A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCF9322C5458CCD204CCDECC90CCE7CCFBCCED5E5ACCB2CCFC4651CCBA62297E0ACCFCCCF2CCCACCFBCCB0CCA05D0421A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCB3183ECCF8CCF4CC9410CCA465CCA4CCD145CC97CC9A4E5FCCB92FCCEACC81CCD7767434CC99CCC7CCC428CCEBCCBB6819A773686966746564C0B1636F656666696369656E74735F636F6D6D9F82A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C0AC67656E657269635F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A870736D5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B1636F6D706C6574655F6164645F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A86D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A9656D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B3656E646F6D756C5F7363616C61725F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B172616E67655F636865636B305F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020190C1BCC8C2123CC9301CCC0CCCD623DCCA5CC91CC84CCEBCC871B15076BCCF5CCC1CCD7497ACC8ACC99CCC2260ACCA4A773686966746564C0B172616E67655F636865636B315F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCFA37CCB2CCCFCCCB1A44CCE4CCF8204DCCB54FCC852335CCE0075ECC8D6BCC87CCB4CCA3CCB47444185C44CCEDCCAFA773686966746564C0B6666F726569676E5F6669656C645F6164645F636F6D6DC0B6666F726569676E5F6669656C645F6D756C5F636F6D6DC0A8786F725F636F6D6DC0A8726F745F636F6D6DC0A573686966749782A474797065A6427566666572A464617461DC0020010000000000000000000000000000000000000000000000000000000000000082A474797065A6427566666572A464617461DC0020CCE3CCA214CCE91334CCD0CCCACCF1CCEBCC85CCDF5BCCD7524D73CCD5CCEB7ACCAF742A7ECCB2CCD40BCCFDCCC8CCCDCCB90082A474797065A6427566666572A464617461DC00206D0F4433CC9A33CC9FCCB8CCA4CCE4CC9BCCF109CC9620CCAA64CC9918482BCC95CCA3CC97CCAE39CCB9CCEC5ACCD4770082A474797065A6427566666572A464617461DC0020CCB40923CCBD78CCE619CCC80A7B39CCC0CCF3CCF11E48005519CCD2CCFECCF16A1F77CCD40545CCE5CCC7770082A474797065A6427566666572A464617461DC0020CCF9CCC95CCCD6CCB11B38CCDF7855CCFD4D2A036329CCADCCCACCD613CCF100CCB92310CC9540356A597C0082A474797065A6427566666572A464617461DC00205A696526CCFA30CC9C412C10CCE86604CCC3CCC0CCAD2CCCD9443DCCD85BCC8232037212CC81CCCFCCBF330082A474797065A6427566666572A464617461DC002043423BCCB307CCCECCC1CC9F297C41CC88CCDECCB23ACCCC7B581271CC9B2ECCACCCCBCCF1CCB7034ACCE6CCACCCE800AC6C6F6F6B75705F696E64657886B16A6F696E745F6C6F6F6B75705F75736564C2AC6C6F6F6B75705F7461626C659182A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCE6CCA15E7ECCA10ECCD2CC8F0F3361CCC7CCA7CCF45CCCED5E6D382017CC8CCC832CCCFCCCC0CCDF0E343ECCB1CC80A773686966746564C0B06C6F6F6B75705F73656C6563746F727384A3786F72C0A66C6F6F6B7570C0AB72616E67655F636865636B82A9756E736869667465649182A474797065A6427566666572A464617461DC00201B24636044CCD6CCED30CCC611CC85CCD45B2969CC98CCB811CCB754CCA5507C08CCD1CC9124CC9B37CCC01721A773686966746564C0A566666D756CC0A97461626C655F69647382A9756E736869667465649182A474797065A6427566666572A464617461DC00205F28CC8BCCB342CC8034CCA922CCB3CCE618CCEA3ECC811ECCDF61CC81CCB10B7ECCF6CCC859CCFD03CCEA2B39CCA70EA773686966746564C0AB6C6F6F6B75705F696E666F83AB6D61785F7065725F726F7704AE6D61785F6A6F696E745F73697A6501A8666561747572657383A87061747465726E7384A3786F72C2A66C6F6F6B7570C2AB72616E67655F636865636BC3B1666F726569676E5F6669656C645F6D756CC2B16A6F696E745F6C6F6F6B75705F75736564C2B3757365735F72756E74696D655F7461626C6573C2B772756E74696D655F7461626C65735F73656C6563746F72C0";
        MsgPk.deser_verifier_index(
            MsgPk.from_data(verifier_index_serialized),
            index
        );

        assertEq(index.public_len, 0);
        assertEq(index.max_poly_size, 16384);
        assertEq(index.zk_rows, 3);
    }
}
