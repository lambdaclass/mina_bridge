// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {KimchiVerifier} from "../src/Verifier.sol";
import "forge-std/console.sol";

contract Verify is Script {
    bytes verifier_index_serialized =
        hex"DE0015A6646F6D61696E82A474797065A6427566666572A464617461DC00AC00400000000000000E00000000400000000000000000000000000000000000000000000000000000000000000140CCB0190CCCE6CC9CCC81CCABCC89CC97CCD87847CCBFCCC65752CCA76A7564CCA937631B66CCA7CCE1CC8C6330CC856E7C61CCC201CCAACCADCCE6CCAA2074CCE13ECCA9CCB4CCA8CCA8CCDC0DCCB8514E1FCC81CCE4CCD9CCCD5156CC962D10CC841C6434CCE9CCEECCF8CCC0717767CCB07609CCF4CC8C6ECC8E55420D6811CCE9CCE9CCE7066F031C28676666CCC6CCD4CCFBCCF3CCE7062D4ACCCACCE95CCCAECCA9CC8B56CCCD337CCCB5CCB949CCAACCD9135ACC94525B13AD6D61785F706F6C795F73697A65CD4000A77A6B5F726F777303A67075626C696300AF707265765F6368616C6C656E67657300AA7369676D615F636F6D6D9782A9756E736869667465649182A474797065A6427566666572A464617461DC0020343FCC9B2FCC88177D5317CCC5CCE46D58775535CCFBCCF727CCAECCFDCC9ACC8F7CCCD71FCC97CCB65DCCF3CC88CC89A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002023CCF6CCC24D796DCCB1CC9CCCF34A55CCB42ECCFFCC9622CCEC131A17CCC77ECCED1ECCF615CCB51B77CCA2CCA727A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCA318CC805ACC9B2A0DCCD6CCF3CCDDCCBCCC87CCA8CCD9CCBBCCD8CCB057CCA2CCB04C171A56CCEFCCD9CC95CCB658CC8FCC9DCC8CA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC83CCB4CCD87413CCCBCC8460CCF7CCE5CCE6CCC7CCA7CCE66E04CCCA37052DCC8A2616CCD2CCB536CC8857CCA154CCC01BA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00202CCCFB36CCC12B283DCCEBCCE1CC9ECC897B7ACC9503CCE71F0A285257CCA2CCC0CC9DCCF5CCC060CCF1CCB638CCB2CCA9A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00206279CCCA3F690052CCE84B191FCCEB56CCCB18CCE51814CCE3CCEE473040CC8ACCA9CCECCC9F0CCC87CCA3CCB6CC87A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCE320265164CC8FCCCFCC98CCA9CC9322CC874C246DCCEBCCFFCCBB67796E184E50171ACCA43E54413D2BA773686966746564C0B1636F656666696369656E74735F636F6D6D9F82A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C0AC67656E657269635F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A870736D5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B1636F6D706C6574655F6164645F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A86D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A9656D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B3656E646F6D756C5F7363616C61725F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B172616E67655F636865636B305F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC00206FCCA61A22CC83CCA1061BCCF23F57CC92CCB4CCDCCCABCC94CCB7CCA62E2F612FCCAC28CC9006CCF54ECCE007CCA02CA773686966746564C0B172616E67655F636865636B315F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCBD4ECCFDCCF0CC984E25CCA1CCC0CC81CCCECCEFCCD1CC83CCEECCD03BCCC44FCC8F50CC97CCA308CCFBCCC420CCC24F5B25CCA1A773686966746564C0B6666F726569676E5F6669656C645F6164645F636F6D6DC0B6666F726569676E5F6669656C645F6D756C5F636F6D6DC0A8786F725F636F6D6DC0A8726F745F636F6D6DC0A573686966749782A474797065A6427566666572A464617461DC0020010000000000000000000000000000000000000000000000000000000000000082A474797065A6427566666572A464617461DC0020CCE3CCA214CCE91334CCD0CCCACCF1CCEBCC85CCDF5BCCD7524D73CCD5CCEB7ACCAF742A7ECCB2CCD40BCCFDCCC8CCCDCCB90082A474797065A6427566666572A464617461DC00206D0F4433CC9A33CC9FCCB8CCA4CCE4CC9BCCF109CC9620CCAA64CC9918482BCC95CCA3CC97CCAE39CCB9CCEC5ACCD4770082A474797065A6427566666572A464617461DC0020CCB40923CCBD78CCE619CCC80A7B39CCC0CCF3CCF11E48005519CCD2CCFECCF16A1F77CCD40545CCE5CCC7770082A474797065A6427566666572A464617461DC0020CCF9CCC95CCCD6CCB11B38CCDF7855CCFD4D2A036329CCADCCCACCD613CCF100CCB92310CC9540356A597C0082A474797065A6427566666572A464617461DC00205A696526CCFA30CC9C412C10CCE86604CCC3CCC0CCAD2CCCD9443DCCD85BCC8232037212CC81CCCFCCBF330082A474797065A6427566666572A464617461DC002043423BCCB307CCCECCC1CC9F297C41CC88CCDECCB23ACCCC7B581271CC9B2ECCACCCCBCCF1CCB7034ACCE6CCACCCE800AC6C6F6F6B75705F696E64657886B16A6F696E745F6C6F6F6B75705F75736564C2AC6C6F6F6B75705F7461626C659182A9756E736869667465649182A474797065A6427566666572A464617461DC002076776ACC8074CCC4CC8F7FCCEDCC96CCC7CCD2CCEFCC84CCF1CCB2CC90CC8E3CCCE46ACC93CCE0CCA86E2A68CCEF7B705620A773686966746564C0B06C6F6F6B75705F73656C6563746F727384A3786F72C0A66C6F6F6B7570C0AB72616E67655F636865636B82A9756E736869667465649182A474797065A6427566666572A464617461DC002065CC96CCFFCC867604CCDD1A633CCCFECC914ACCF177CCAACCE5124239CCD9CCC8CCC80D36512FCCF764CCBE01CC97A773686966746564C0A566666D756CC0A97461626C655F69647382A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCAD24CC87CCD4CCBF401CCC97CCB4CC95CCB215CCDECC95051CCC861A795F3ECC8204695D14515ACCFECC8CCCC8CC9FA773686966746564C0AB6C6F6F6B75705F696E666F83AB6D61785F7065725F726F7704AE6D61785F6A6F696E745F73697A6501A8666561747572657383A87061747465726E7384A3786F72C2A66C6F6F6B7570C2AB72616E67655F636865636BC3B1666F726569676E5F6669656C645F6D756CC2B16A6F696E745F6C6F6F6B75705F75736564C2B3757365735F72756E74696D655F7461626C6573C2B772756E74696D655F7461626C65735F73656C6563746F72C0";
    bytes prover_proof_serialized =
        hex"85AB636F6D6D69746D656E747384A6775F636F6D6D9F82A9756E736869667465649182A474797065A6427566666572A464617461DC00200F55CCD0CCA2CCA2CCDE74CC96CCB3602BCCC065CC9259102A2D51CCE3CC95CCC2CCA73D5B65CCE8CCD67C0B76CCA4A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC8E4E3FCC8B3ACCF80A2ACCAC38CCE33849CC89CC8459197F690ACC9C2B2FCC94CCC8CC84CC8A6F6E29CCDC18A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200ACCD2CCDFCCF8CCD41E01CCA443484502231A533ACC9D725C1B7ACCD8CC944027CCA3CCEF620A144BCC97A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002074CC8D69795C2472CCEACC9BCCE65B33CCF5CCC9337ECC94627FCCF4230D0D5BCC98CCF94C63CCB64ACCEE2DA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCCB78CC82CC84CCBF08CC8FCCDA1238CCF0CCE02825CC8C3E3149CCB4CCAA5F1CCCBA10CCB2CCBBCCB670CC82012C1BA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002066391F7BCCB6CCABCCBECCB75F4170CC9C2D05CCD9CCD7CC9E1726641E331ECCD2CCE5CC8B06CC8DCC89CCEE0421A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002040CC8548CCF436CCBE427C6B22CC99255E3DCCF44DCCABCCD562CCD860CCA0727D2F65CC8BCCFD060B08CCA8A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00204040CCD55C3640CC92CC8DCCA717CC8CCC9ACCAA20CCE9CC9F61CCBF72CCB174CC962DCC8DCC8ECCB1CCC7CCE6CC9F6E1506A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCA2CCA22B4CCCFE64CC95CCF9CCFCCCCB1CCCA1CC957F0C1F49CCF34531CCB166CCCDCCACCCBB760748CC8CCC811917A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC80CCC7CCE8656563CCAB2448CC98CCD5CCDA6B5DCCC25DCC88CCEF33CC8C151FCC9168CC80CCA1CCBDCCFE44CCA41213A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCA657CCF8CCF3CCA96D321E3E6301CC8741CCD6CC84CC94CC97CCE321CCE9CCE426027CCCF17514CCFF3E374622A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCBD20170F0C2622CCCFCC8B7B42CCD4CCC541CCFBCC99CCA2CCD2CCDE2240667B63CC9BCCEDCC91CCB30C51CCE5CCA7A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCA43ACCE21C4C1305CCA85124CCB1CCCCCCB53CCCBECCCCCC8530CCB00242CCF3CCE8CC89CCF40E33CCE9CCA460501DA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC81CCBB51082F55741FCCF12ACCEA61CCE3CCD2CCA25ECCDE4A797C3965CCFA38CC92CCFD5A1C26CCB4CCB8CC99A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC93122221510DCC94CC98CC97CCD55A725E2F417A426CCCCECC9B57CCBCCCE760CCE5CCFA633BCCE72B300DA773686966746564C0A67A5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC002066CCE001CC911DCCE40CCC93CCF6CCB941CC8436CCCACCA5CCDF104646CC95CCB1CCE620CC9739CCFC2BCCF4CCCBCCDC7FCC8BA773686966746564C0A6745F636F6D6D82A9756E736869667465649782A474797065A6427566666572A464617461DC0020082BCCFB673BCCE254CCCC23CCF97ECCDB6C1D4279CCB7CCF146CCB50B5ECCB6537BCCC02ACCBCCC94315DCCAB82A474797065A6427566666572A464617461DC002070CCD5CCB7CCC6CCAC1B042A24CC8871CC8B624B401E157B4F1ACCCFCCD23177CCB9CC93CC9858732DCC9ACC8E82A474797065A6427566666572A464617461DC00200ECCE009CCCA374218752DCC94CCE46F0CCC9BCCCE196FCC954A01CCA853646D2CCC8F0DCCE0CCEBCCB5421F82A474797065A6427566666572A464617461DC00203ACC9351CC9402CCD100CC9D11072F6037CC94CC8BCC852CCCBDCCBF73224D5ECCCBCCB44B05CCC74433CCA72482A474797065A6427566666572A464617461DC00200FCCD8CCDA24CC8DCCB63ECCDCCCCF57CC906B0FCCE4CC91CCDC7DCC84CCB27A47403DCC8B7C115DCCA6CCE9CCFDCC82CC9782A474797065A6427566666572A464617461DC0020140D4C1FCCE7CCDECCCE081A31CCAF0D23CCC1CCDF1ECCD856CC91CC8CCCAF6BCCB766CCF7CCFECCADCC9204CC88CCEDCCAF82A474797065A6427566666572A464617461DC0020CCA8CCD03CCC86CCE8CCDF6CCCABCC8134CC9BCCA3CCF175CC85CCA3CCBD550DCC9C40CCDECCAFCC98CCA7CCD807263FCCAA4C0BA773686966746564C0A66C6F6F6B757083A6736F727465649582A9756E736869667465649182A474797065A6427566666572A464617461DC00204E32021BCCEFCCEF79CCF55F15CCD4CCCBCCC65A32CC8D2F5871CC8FCC87CCE2CCFE6932562DCCEFCC88CCF7CCD412A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC876ACCC1CC8A0241487E634BCCC063CCD3CC8424CCDFCCC8CC8A4745CC8ACCBF2CCCC110CCDBCCF5393FCC9F6719A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCB01DCC9BCCF9CCA0CC8C7CCCD028CCC454CC9ACCD63FCCBACC8E41CCC16B223D62CC9D12CCA25519CC9BCC9DCCE3CCB217A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00202233CC9376CCB8CC93CCDACCC44FCCB6CCDBCCBB416A14CC9B1CCCBDCCBBCCA56E59CCFACCC9CCDECCCC62046FCCFC4C05A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00207266CCF919CCD340CC9CCCCF120738592BCCD3CC8242CCDACC89CC9D1FCCF9CCBFCCA946CCFECC8DCCDFCCF95FCCF74E25A773686966746564C0A661676772656782A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCF9CCE955CCF8CC9516CCCE7060CCB7CCB5CCDF54CCEC033121CCEA69CCDDCC9C142ACCBACCF1CC9D2DCCCB0ACCC702CCA7A773686966746564C0A772756E74696D65C0A570726F6F6682A871756F7469656E7482A474797065A6427566666572A464617461DC00201D14CCB9CC9ECCB378CCD173446E10CCB4CCBE68CCCCCCDF766658CCF5CCB8CCABCCC82ECCA85ECC94CCF9CCF4CCFFCCF720A8626C696E64696E6782A474797065A6427566666572A464617461DC0020CCD1CC9B0D4530CC9DCCC3CCC96FCCB344CCBCCCC8004B1664CCB4CCC03C0BCCB9CC91CCDBCCA92917CCB7CC82396307A56576616C73DE001AA67075626C696382A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000A1779F82A47A6574619182A474797065A6427566666572A464617461DC0020CCCFCCD10A721D543A6D0561CCE80ACCCFCCA9601CCC842A72CCD90A145D6ECCEACCBDCCF6CC9B28084819AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCA33BCCDE4536596C20CCEECCDD7ACC89CCE8CCD4CC8F626DCCF4CCD0CCC10CCC8DCCF93CCCF27269CCF2CC862ACCF20082A47A6574619182A474797065A6427566666572A464617461DC0020CC9207CC9ACCA955CC9FCCE5CC8A76CCA3754309CC9FCCAF007628CCEA2F69CCAA23CCE356CC90CCF126CCD700CCE924AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002023CCB513CCC966CCDECCA079CCB6227A4DCC920A501CCCC2CCC9CCCD4BCCE3CCCACCF2CCE61660CCCBCCBA08014A0C82A47A6574619182A474797065A6427566666572A464617461DC0020005D2D3C5B5F3DCCEACCF56D25CCB032CCF43F79CCA012CC932B502FCCA5CC896ACCE0CC80CCABCCCC42CC9813AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002079CCF1CCE65A24CC86CC8D063B2F450463513D14CC93CCC7CCF5CC836733CCC8CC9ACCBDCC83CCC8680157CCBB1282A47A6574619182A474797065A6427566666572A464617461DC0020393ACCD5CC8B061A517E6E24CCFF47CCC1326B6ACCAA46CC833E451ACCC0CCE32B7B12CCB7CCB53D1800AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCCECC8C696C4855CCAE7071135ECCAB6DCCDBCCF23B1ECCF431CC8ACCA3CC8B2B3DCC8DCCA25F511DCCDF0D2F82A47A6574619182A474797065A6427566666572A464617461DC002071CCE17ACCB40A22CCD3CC9B7D66CCBE0C10CC8558CCD859CCA448CCBECCAE03CCEBCC8A0C3ACCDF246FCCEDCC910DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD95D1FCC82CCE24410CC8CCCCF35CCC306CC914865CCD7CCDC1320CCB847CCB7CC8F2E2671CCE6CCB665CCF5531382A47A6574619182A474797065A6427566666572A464617461DC002072CC95CCE0CCC073CCB3CC88CC9CCCAC706E602BCC865A47CCC6CCDFCCE93F24604CCCDFCCCC24CC8CCC9CCCA8CCD97802AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCFDCC8DCC9ECCCCCCFA1FCC8E5C6BCC83CCE6CC8401CCB3CCADCCAD16CCB36101CCC8CCFC3C25CCE3CCF2CCE53DCCFF13672A82A47A6574619182A474797065A6427566666572A464617461DC0020CCB200CC9F0706CCE7CCAECCCFCC8CCCB1CCC12CCCADCCBECCC67C7DCCABCC94CC9DCCD2CCF5126DCC9DCCF8CC925CCC8523CCD307AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020793271CCACCC981716CCBE0E5A23CC8470CCA6CCC3CC97CCD5CC86CC9D4F4731CC9F4F46CCBF04CCAACCCDCCBCCCCE2E82A47A6574619182A474797065A6427566666572A464617461DC0020CCC6CCA04BCCCF200CCCE65A76CCB6CCF9CCFECCAECC932D524A36CC80CCC2CCAC26CCDCCCDECC82CCBE607C554BCCBA0FAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC9601CC92CCBA4ACCD408CC8FCCB7CCA774CCAC1ECCF8CCA17664CC84094624CCD4CC86CC841C46CCBFCC8425CCC1CCD60982A47A6574619182A474797065A6427566666572A464617461DC00201CCCADCC94CCEFCCEDCCB9CCD2CC9A2F4F1D74CC98CCBB0ECCB37FCC9408063ECCDFCCCC0325CC8C1ECCB8CC88CCDCCC951CAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCC0CCD531CCC0241D3B6BCCA3244B324C1E181ACCA67FCCACCC94CCBE1D2CCCD87816CC94CCBB71CCFDCCAD2B82A47A6574619182A474797065A6427566666572A464617461DC002004CCF5CCFA4ACCC75376CC94CCCFCCF0CCCB17CC9C1ACC932B0333CCB4CCE8CC86CCCF3ECCCFCCDCCCBC3B520FCCFB7A28AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCDD5653CCEACCE323CCD9CC82CCDECC8FCC92CCC2CCBDCC953E5ECCDF10CC8368CCF8CCBACCF63CCCEB6818CCC1CCB4CCFACCBD1382A47A6574619182A474797065A6427566666572A464617461DC0020CC824CCCD3CC96CCE026CC943D2E4DCCF9CC8DCCD6CCD5CCF222280A520369CCBECCAECCFD3E6300CCB1CCC364CCD829AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCC6CCE8CCF6340F15CCF8715BCCA06FCCD3CCD978723ACCD9CCB03249CC845BCCC52ACCB0CC8ACCF5CCFB33CCE11A2282A47A6574619182A474797065A6427566666572A464617461DC0020CCBBCCB4CC81CCB32BCC9350CC85CC85CCA9CCA203CCB9CC83CCD9CCE8CCCCCC837ECCBBCCA9CCDECC941741520F291E70742DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002072CCA00111CCE8CC9BCCBFCCB806CC8A720247CCE50ECC812B18CCA3CCDF5ECCD7CCA97FCCB7CC8BCCAA2844CC87732382A47A6574619182A474797065A6427566666572A464617461DC0020CCE7602BCC8A64CCF7CCCA03CCD14F46CCBA12CCF63C34CCC5CCEF5E25CC8BCCC7CCB9CCD073CCDA1BCCCFCCE10FCCBE2EAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC8C1BCC9140CC88CCFB12CCBCCCB7CC947ECCE73369CCEBCCA1CCCD05113274CCD2CCC256CCB5CCB264CC98CCA0CCB7CCFF0682A47A6574619182A474797065A6427566666572A464617461DC002051CCAACC83CC84CCF229CCB6CC807DCCDECC9ECCFF6675CCD71768CCEF153ACCC84C2E697FCCABCCB46A16CC8DCCF015AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002049CC91CCE0CCADCC981D4BCCC0CCA4485CCCB3CCCA40CCBA3CCC89CCD14FCCECCCB02775CCEE2E35CCFB1CCCE5CCA4CCC80782A47A6574619182A474797065A6427566666572A464617461DC00200BCC91CCCB09CCA3CC847FCCF11A4623CCE1CCE6CC84402BCCC65051CCCCCCEC15CCD773CCE8CCCBCCB1CCCFCCE678CCE806AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020014ECCB14943CC84234ECC80CC8703CCF1CCA65449CCF42F5B20CCE8CCE5CC885E5D64CCC54718CCFBCCD82D1AA17A82A47A6574619182A474797065A6427566666572A464617461DC002022373921CCC3CC84755B7CCCC7CCB0CCC71365415409CCC8CCF1CCD54ECCC3CCCE12252ECC9905CCEECCB50913AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002006CC800ACCC539CCC900CCEC0E10CC894ACC8806495160755B5ECCF7CCBCCCFDCC91CCC7462FCC8542592502A1739682A47A6574619182A474797065A6427566666572A464617461DC002013CCADCCD0CCB9572B71CCBA4CCC8FCCE6CCA8CCB62A550239CC9548CCDFCC89CCD4CCE0CC8455CCFE6A11346F6D1EAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCF42DCCF4CCD1CCBD0ECCEF5ACCE37CCCB3CCD2CCA6CC99CC860B2415CCA4CCC54870CCE3406313CCAFCCD5505ECCC10582A47A6574619182A474797065A6427566666572A464617461DC00203ECCDA37CCF0CCB20525CCF6CCB5CCB039CCC7CCC1CCC8CCD1CC89CCA6CCC9CCAF3C2ACCD7CCC059CCC8CCACCC8BCCE0CCA34F6B2BAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCDA3E7BCCA6146F361CCC9A6CCC92CCC5CCD74D44CCCACCA80DCC881FCCF0CC827D4346CCF9CC96CC8B2C32CCD81A82A47A6574619182A474797065A6427566666572A464617461DC0020CCBD12CCC402CCDB7E2ACC872934CCD4CCA522CCBB5D2249CCAB1E1553CCC33BCCEFCCC173CC96CCBDCC9072CCC02BAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCFF1ACCBCCCB65920CC8F02CCA4CCA6CCAACCC755CC952CCCFDCCB57FCC8129CCA74E6055CCD8CCD1CCF4CC815E23451182A47A6574619182A474797065A6427566666572A464617461DC00200F676716CCDE2644CCC308CCEE0F68CCF52ECC9BCCECCC9CCCBECCC836CCDE473247CCA5CCFE41376B43CCB424AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002049CCB46FCCF8CCC27D5017215BCC920614CCED041826CC9BCCE8CCA6CC873CCCA24909CC923472CC83CCDCCCC90B82A47A6574619182A474797065A6427566666572A464617461DC002067CCE768CCCDCCF7CCFF4D2BCCCD77CCFC60CCBFCCA20365CC8B17CC97CCEECCEBCCBBCC844E7F2F7CCCC0CCF6CCFDCCF310AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD6CCAFCCE0022ACCFD3E1361CCBBCCC6CCD3CCE259CC90376829CCF6CCD8CCDBCCDB600ACC8B2F6FCCECCCF0CCCA030D82A47A6574619182A474797065A6427566666572A464617461DC0020306F2ACC9157CCD4CC97CCC81A510ACCC7CCA96D79CCDF30CC9D4B2FCCDD7CCCAACC9C33CC9430CCF3CCAD075E18AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00205C28CC984567CCAA38CC9F4A3DCC9503422758CCD3CCEACCE7CCCA1803CCF1CC85CCCECCD0CCE5CC84CCADCCDCCCAF431DAC636F656666696369656E74739F82A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B067656E657269635F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B1706F736569646F6E5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B5636F6D706C6574655F6164645F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AC6D756C5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AD656D756C5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B7656E646F6D756C5F7363616C61725F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B572616E67655F636865636B305F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC0020CCA1CC97CCE45F7673CC92CCAB03CC8460CCCBCC92CCAFCCACCCAE311416CC86015BCCFD4BCC8C26CC82CCC450063D00AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002066CCA1CCF73ACC9D0A272175407FCC92CC84721CCCD310CC96284E487861CCD1CC8525CCC9124908182AB572616E67655F636865636B315F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00205173454A1DCCEE79CC88CC9BCC8077476971CC82764F5A6BCCB10B28CCD659CCE3CCC608CCEF7B36CCB50DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002003CCB9CCBECCF01B7ECC87CCC14270CCEDCCE0CCD8CC90CCDECC81CCEFCCDA5CCCE9CCDECCEDCCA05D521220CCA40C1B001CBA666F726569676E5F6669656C645F6164645F73656C6563746F72C0BA666F726569676E5F6669656C645F6D756C5F73656C6563746F72C0AC786F725F73656C6563746F72C0AC726F745F73656C6563746F72C0B26C6F6F6B75705F6167677265676174696F6E82A47A6574619182A474797065A6427566666572A464617461DC002044CCEBCC8CCCC652236FCCADCCAA543749CC89306247CC8934CC840E1B1446CCE14ACCCE45035D114818AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCBB0ECC9F5DCC9F25CC96260371CCBB751DCCF53A73CCFE316F71CCE865CCAD61CCE4CCC1CCF542CCC3CC90CCAE19AC6C6F6F6B75705F7461626C6582A47A6574619182A474797065A6427566666572A464617461DC0020CC9C21CCD0CCEBCCD2CCFB55151F456DCCD0CCBF150860CCC5CCD454CC85CCC3CCBECCD6CCBE45CCDACC8669CCAF697326AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCFA1D3CCCACCC8FCC8C53530A034ECCD8CC92CCEF12CCC54ACC88CC9BCCC0227A0FCCE8CCD5CCCDCCCF74CCB2CC846F28AD6C6F6F6B75705F736F727465649582A47A6574619182A474797065A6427566666572A464617461DC002020CCE7CCE7CC9167CCDBCC83CC87CCCD3ACCEDCCE9CCE2CCF5CCFD4B67773FCCE32228CCD6100FCCF8CC9A37CC95195D00AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00206CCCFFCC8A5C4BCCFE75CC807314381244CCD41661CCD8CCB4CCBC707CCCFECCC6CCB1CCBBCCE74CCC8CCCF0CCFBCCAB1382A47A6574619182A474797065A6427566666572A464617461DC0020CC9422CC9ACCBCCCD962CCAD7E4A22CCB0CCEDCCA2CCABCC846012450352CC80CCA7CCE6750C6C2A00CCF45F7922AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020461216283ACCE31BCCFC7BCC81CC90CCB271661D19CCC2CCF935516DCCEDCCD2CC987DCCC0CCCDCCAACCB1CCA5CC9D1182A47A6574619182A474797065A6427566666572A464617461DC0020CCF5CC900F3BCC8924735F4A7F54CCCFCCF9CCC4630F4E654CCCE6CC9CCCF4CCF8CCED272664133422CCB624AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002048CCE034CCE706CCD85846CCE9CCDECCEECCB774CCCC20CCB138CCB4CCEDCCB51ACCA16D1CCCBF66CCA929CCCBCC91CCD60C82A47A6574619182A474797065A6427566666572A464617461DC002013CC81CC8ECCDDCC9526CCF8471CCCAA5ECCDBCCE521CC87101140CCA86E3C2D4FCC8FCCF501CCD9CC9710CCABCCEA0EAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00206CCC99CCCDCC8ACCC0CCD96ECCEACCDCCCC91ACCB82268CC8BCC9D207C1846CCC8282DCCBBCCE47562CCDACCF449CCD50082A47A6574619182A474797065A6427566666572A464617461DC0020CC8B1B574CCCE360CC86CCAECCFD41CCEA22CC8FCCAB58147478032420CC9913633E21CCA27F1467CCEF25AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD6CCFACCD6CCA2CCDB3F39CCE4CCA74D7E6DCCE2CCAE24CCFD29CCF1CCD32E25CCE35CCCA5CCA1CCDD6122CCC0CCDA2400B472756E74696D655F6C6F6F6B75705F7461626C65C0BD72756E74696D655F6C6F6F6B75705F7461626C655F73656C6563746F72C0B3786F725F6C6F6F6B75705F73656C6563746F72C0BB6C6F6F6B75705F676174655F6C6F6F6B75705F73656C6563746F72C0BB72616E67655F636865636B5F6C6F6F6B75705F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00204008CCDCCCB03DCCDE260BCCFFCCEACCFC7A1734CCDE0329CCD86F0F01786CCCFBCCB3CCF640CC8D53CCCF680DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCB9CCCDCCFBCC8542CC814627CCC2CCC02A417ECC8C49CCA3CCF2726F677C48CC88CCD0CC915ECCC0CCC45E0B6923D921666F726569676E5F6669656C645F6D756C5F6C6F6F6B75705F73656C6563746F72C0A866745F6576616C3182A474797065A6427566666572A464617461DC0020597FCCF314CCFA476D14CC936FCCCFCC84076271CC887ECCA6CCF74672CCB83114CC82CCC55F454318CCD025AF707265765F6368616C6C656E67657390";
    bytes urs_serialized;
    bytes32 numerator_binary =
        0x760553641e13f70f3c75d4e3f8ffc1e46024507d1d363af1dc1177fd9c863c05;

    function run() public {
        urs_serialized = vm.readFileBinary("urs.mpk");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KimchiVerifier verifier = new KimchiVerifier();
        verifier.setup(urs_serialized);

        bool success = verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized,
            numerator_binary
        );

        require(success, "Verification failed.");

        vm.stopBroadcast();
    }
}
