// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import "../lib/bn254/Fields.sol";
import "../lib/bn254/BN254.sol";
import "../src/Verifier.sol";
import "../lib/msgpack/Deserialize.sol";
import "../lib/Commitment.sol";
import "../lib/Alphas.sol";

contract Integration is Test {
    bytes prover_proof_serialized =
        hex"85AB636F6D6D69746D656E747384A6775F636F6D6D9F82A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCD843CC8C68CCADCCC65F0FCCE95332CCD3566E1C7BCCA626764ECCFF30CCEE14CC9560790764CCE7CCC4CC9CA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCE7CCFBCCD1CC92CCBF523131CCDD2FCCB807CCF8CCF7CCCFCCADCCE7CCDF6256CCE8CC9ECC91CCF0CC9C0CCCB11050050FCC85A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCC3CCE17360CCCC5FCCA1CCAD260C0ECCDFCC98CCCBCC8ECCD2367F0B2553654257CCA5CC82CC96CC9361CCF379CC89A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020465CCCB06ACC97CCCC1FCCBA62156DCCEA4A0ACCCF78CC98CCAECCBECCDFCCE1CCD212537BCCCF5970CC8C3A3E30A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCAACCAECCD8302DCC9FCCF808CCA76DCCB646CCA345CCA70BCCFFCCBA5865357522CCF6CCEF443634CC81CCA7CC8A0CA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002010CCDC62CCE86ACCA0CCFBCCCCCCA934CC8ACCB97ACCE3552B5E7442112820503713CCCD7E30CCC4CC8936CC92A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00207833045124CC8BCCFA087CCCC77969CC8B17CCDECCD5CCEACCD3CCB8CCC147CC907DCCFF0042CCB9CCADCCE444CCF1CC80A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00201A49CCD234CCEE0ACC985DCCD452CCB8CCC365CCBA5F7FCCE57874CCE5CCB8CCAE7C24CCA7CCFFCCDF7F06CCCECCBF16A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00203BCCF60A24CCEF2F1B14CCE9CCF71BCCC23ECCEA0C5ACC9C0DCC9E377232CCD501CCBACCCFCCD9CCF9CCF3CCDACCCF00A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00201ECCA4CCCFCCEF710FCCE8CC9B32CC81CC84323C601ACCB1516005CCFFCCEB2FCC90CCBE654CCCFD5D486FCC862FA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCDD7DCCDC5F6ACC8132CCC008CCF9CCE3CCCACC94CC8ACCA83D7ECCC5CC835ECC97CC8ACC95CC9CCCE3CCCA0B58CCDF4FCCE314A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020351B53CCB8CCA6CCDB78CCA61D4865276D69CCDD49361E620A32611E1ECC80CCFE51CC94CCB74C2410A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC830DCC89CCADCCBCCCC9CCD3CC82CCE60114CCCBCCBFCCD5CC8D40723DCCE6CC8354CC9509CCB731CCCACC9ECCD7CCB7CCDECCD7CCABA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCC2CCF328CCED33CCDC6264CCEDCCEC4633CCCCCCA8CCBBCCDACCC24345CC99CCA565CCC23ACCB144CCAACCC459CC924809A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00204DCCBE7C3A5F1E2B7ECC867965CCCBCCD65A7D771ACC81CCEECCF724CCE2010DCCF1CCF63CCCFC4C56CCB5CC9FA773686966746564C0A67A5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC00205CCCB4CC8052CC9A247A2B51425B50705BCCEACCD7CC85CC8664CCBCCC84CCB1CCD318CCB96BCCEA55CC9049CCEBCCA7A773686966746564C0A6745F636F6D6D82A9756E736869667465649782A474797065A6427566666572A464617461DC00203ACCF406CCEBCCEBCCE72979CCF063CCB06BCCA8CCF74A34CCA22B5D4B5E30CCF8CCFD3F7BCC9F11CCC254101582A474797065A6427566666572A464617461DC002071CCF6CC9CCCADCCA4565520CCE9CCA5CCF4CCEBCCA0CCDB1B1E3D760224025A4DCC806BCC9DCCA7CC8CCCA951CCEC0C82A474797065A6427566666572A464617461DC002056CCC151CC80CCF762CCAFCCA4CCD9CCC968CCA6CCAA64CCD60CCCF1CCC4CC9FCCDB6A2D6863CCFFCCAB48796F37CC8D2682A474797065A6427566666572A464617461DC0020CCAECCF3665BCCDFCC97CCBE7CCCE6CCF8CCB70F62CCAE197764CC9ACCB80ACCA416CCE3CCB00E78CCAD265613CCA50B82A474797065A6427566666572A464617461DC0020CCF81C0359CC95CCFCCCA479CCB2CC9DCCEDCC9626CCCECCB6CCEDCCAE642A3DCCF37ECCF56B665BCCD950CCD32C780882A474797065A6427566666572A464617461DC0020CCF6CCF06B74CCA433591E30CCE6CCE1CC93CC8ACC9C56042F3867714FCCC72E7ACC891ECCBB71603DCCE4CCAF82A474797065A6427566666572A464617461DC0020CCCFCCCFCCB3560BCC83CC95CCCC33CCEACC9E6DCC921BCCB4CCCACCA864CCECCCC33776734D657CCCD52BCCAC204BCC94A773686966746564C0A66C6F6F6B757083A6736F727465649582A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCE9CCF5195B6ACCD6CC96CCA1325F2D6C79CCFF6CCCD9CC9ACCFE77CC932BCCE3CC994073CCF2CCFBCCC779CCE56C27A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC975DCCC0CCDD6BCCC7CC9ECC8CCCDA681A17CCDA2CCC9F7BCC916F483D41CCA00A68CCB718CCC722CCBE422E18A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002021CCC1CC8C4370687F69CCA0CCAA533BCCCA0C5BCCE847CCBA78CC83CC8BCCA103CCC67668CCDCCC812405CCA0CC8AA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002019CCD34CCCF25BCCE82955CC974A26663E0F70CCA6596FCCACCC9B7CCCAECC83CCA6556F410771CC92CCF611A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC002045CCF9105CCC8FCCA1CC9E2638607BCC8A2B0266CCEDCCFACC9361CC80CCC1CCE1CC8A3C5B08CCCC5FCC8921CCC2CCA7A773686966746564C0A661676772656782A9756E736869667465649182A474797065A6427566666572A464617461DC00201DCCC905CCCBCCFC7F19CCB5CCCCCCECCCB4CC965DCCA5CC87573F535C6A15CCBD0FCCC0CCA81D07023818CCA21FA773686966746564C0A772756E74696D65C0A570726F6F6682A871756F7469656E7482A474797065A6427566666572A464617461DC0020CCDD7E3BCC86CC99622CCCFD7F08221DCCD8191504CCAB386202CCC50A6ACCB1CC8ECCF663CCBECC9F0A53CC99A8626C696E64696E6782A474797065A6427566666572A464617461DC00207B6778CCBECCFD13CCB616CCEDCCDBCCAA7B1FCCD214CCC4CCD3CC9A4DCCC0306ACCC3CCF3CCD1CCAFCCF64D6858CCB61DA56576616C73DE001AA67075626C696382A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000A1779F82A47A6574619182A474797065A6427566666572A464617461DC0020CC91CCABCC853859CCDB5FCC8FCCC276CCAACCC5183119CC84CC863231CCB456CCB608CC9336CCC3CCC0CCC0CCEACCAB2D2CAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD7CCB3CCC07450CCC178CCBB5B14CCE3CCB5CCB22C70CCEBCC8E770ACCE329284A08CC84CCA5CCDF6BCCC1752E0882A47A6574619182A474797065A6427566666572A464617461DC0020134ECCAECCD96164CCA0CCD8CCBF0B71CC9C5C78CCE3CC8E21CC81CCDF10CCBD02462ECCA8CC9D03CCCECCF06D6F15AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD256CCA01BCCABCCF549CCC62908CCFDCCE5CCF537CCC24BCCF645CCCC2948CCEC3ACCD9CC9ACCAECCC2CCE30ACCCD301D82A47A6574619182A474797065A6427566666572A464617461DC0020CCC2CCEBCC96142945380379CCEFCC95130D6914CC925FCCF623CCA4CCB21BCCE00FCCCA00CCA5CCA44113CCC206AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00203ECCD2CCD9CCADCCB110CCA05F6B0DCCF5CCD435373FCC896DCCC16ECCA81E29CC982A5D422835CCAC4B090C82A47A6574619182A474797065A6427566666572A464617461DC0020162ECCAECCE714CCE053CC94CCFECCB612CCA31371CC8D3856CCD9CCE603CCECCCB2CCE9CCEB39CCDBCC86CCB445251216AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCBACCF04E4E7ACCE2CCCECCBBCCB2CCC2CC8ACCB7CCF06A71CC9F685ACCF1CCC9CCA454CCDC0549CCFFCCD545CC8B4A1A1682A47A6574619182A474797065A6427566666572A464617461DC00200F4B02CCDA68CCDFCCE9CCA8366FCCAACCD70ECCCE3ACCA84BCCC3CC80CCC149CCB077CCA20BCC9DCCBF5FCCEC7ECCBC02AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002066CCA178CCA84845CCE35ECCEA08CCD4CCB1CCEBCCD5CCF6221C0F74CCDCCCCBCCCDCCDFCCDD62CCEECCEC4D6DCCD4CCC40982A47A6574619182A474797065A6427566666572A464617461DC00206ECCE833CCF62BCCF044CCE1CCA3CC9B25604DCC982CCCA1CCFC6ECC9A61CCA4CCE973CCEF0A71CCBFCCD90617CC9422AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00205848CCFC1BCCFC647567CCCFCCF76ACCC176CCFACC92560B6C3E3D6FCC90CCF6CC9FCC9ACC88CC811160CC91CCC20682A47A6574619182A474797065A6427566666572A464617461DC0020CC864757CCB36C11CC86182C11CC832E08CC86466ECC8A49187BCC8BCCEFCC90CCC87171CCA62040CC9ACCC22FAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD0CCAECCFFCC91CCA0CC9FCC9625CC9522CCD5204E2BCCC0CC91507408CCFACCCB5B202C57CCF23A46CCE37D7D2D82A47A6574619182A474797065A6427566666572A464617461DC0020CCE95ACC9E46CCFCCCBA232C37CCC335CCF9CCF9303CCCFFCCC85669CCEFCCB107CC99CCFACCF7CC924F2827CCAE0102AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002009CCB537CC9D6607CCFECCFDCCE14801CCF6CCB3CCA2CCB6CCE2CCDFCCE5CCC83027334FCCAE22221BCCCF1A0F1C0082A47A6574619182A474797065A6427566666572A464617461DC0020CCC6CCCD1ACCBF41233DCCA617CC9C4406CCD861CC91CCF60E4412CCAB4FCCB1CC9F447BCCB3CCABCC9E7836CC960CAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002037CC80CCAECCBD56CCB5CCBC50CCC3CC9746CC995BCCB628CCB674CCACCCF7CCC55D653142CC9FCCCA71CCC9CCE3CCEACC8C0A82A47A6574619182A474797065A6427566666572A464617461DC0020CCB1CC8348CCDACCD87DCCD0CCDC29CC826D03672D64CCAE4963CCE37ECCB205114ACCDECCB5CC9F1E1B72CCAC03AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCF5793436CC87574F2ACCAA5020CCA91E1CCC8451CC81015ECC8E35267C063CCC86CCB87CCCA002CCFF2D82A47A6574619182A474797065A6427566666572A464617461DC0020CCD33CCCAECCD038CCD63324CC9B1DCC9ACC9FCC8040CC9A39CCF7CCEACCCCCCE17ECCE5CCADCCEE18CCB0CC8509497ECC882DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCD32B42CCF447CCDD023CCCD4CCB76D50CC9DCCD2CC8054CCF456CCC709CCA017CCC104CC9A65CCA37439CC96CCA61782A47A6574619182A474797065A6427566666572A464617461DC00200A5D16CC8FCCC1CCF516CC8843CCDBCCFD74CCD8102B5928CCA244CCDC29CCE8CCC4714DCC935628CCB52ECC8D18AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCEA45CCBE2C29CCDFCC805ECCE5CCABCCB3CCAB05CCEDCCE125CCB2CCFDCC8ECCAD6549CCF1CCA57DCCE9CCD647CCE6CCA7650E82A47A6574619182A474797065A6427566666572A464617461DC00204854CCAE40CCFCCC8F3BCC935E2477CCCCCCC90D0C115D72CCAD63CCA537CC9873CC8770CCEFCCBA12CCFDCCB01BAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002022CCDC2DCCD655CCAC0B6311CC9944CC8E39CCDECC81CCBBCCB1CCE45C32CCA4CCBD5A1D4314CCFFCC9010CCF24B2B82A47A6574619182A474797065A6427566666572A464617461DC00201135CCDBCCDC6F7FCCDC26CC845449CCC771CC881029CCC1CC80CCD5CCAE61CC866DCCCF6CCCF81C1C73CC871A2FAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002048CCCBCC81CC906F47CC98CC8F3E3C04CCD4CC9874CCA50A3E3D31CCE6CCCCCC8772CC8ECCBC07CCDA05CCCE273A3082A47A6574619182A474797065A6427566666572A464617461DC00207DCCCCCCCECCBACC9D4373CCAF6F1D07CCD00FCCD42344CCD5CCB3CCE0CCF36A7937CC8DCCFB350BCC8E7F73CC9D26AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00206C2D746FCCD1CCF94654CCB7CCC4CCC7CCE36051CCB019CCCBCCE870CCE5CCD43ACCED10CC93CCFFCCEB4C67CCA05D30A17A82A47A6574619182A474797065A6427566666572A464617461DC00203303576F49CCD5CCA8CCD0CCE87BCC9703CCFCCCEACC9FCC9102CCCC69CC8ACCE4CCEF6945CCA5CCDF1F2B7262652AAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCE747CCA774CC98CCA2CCA610CC9FCCEDCCEC22CCEC150E732818CCFF3727CCD4CCDA31CCE1CCB5587160CCAACCC603A1739682A47A6574619182A474797065A6427566666572A464617461DC002051CCF4CCA0CCA2CCDC4BCCCFCCC2CCDC5CCCFBCCF2CC9FCC9CCCB9CC9FCCA7315741CCFF73CC99CCFF41CCE8CC95CCE6CCD6CCB7001DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCF21D4C5ACC954338CCE1CCC56206CCC45705CCE503CCDD28CCEE64CCF633CCA6CCF677CCFACCF8CCB5CC8A45CC9F0E82A47A6574619182A474797065A6427566666572A464617461DC0020CCEFCC81CCD54E2E33CC860C37CCE8CCA5CC96CCFF1ACC802ACCEACCBDCCD6275770CC841F36CCA6CCD5CCCCCCA13CCCC71AAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCF63A5E6C3ECCF63DCCED4ACC8F75CCDF2ECCBF5ECC95CCC8CCA4CC992926CC996DCCE9CCAD60CCD30122CCE2201782A47A6574619182A474797065A6427566666572A464617461DC00201ECCAA57CCA3CC9BCCDDCCBFCCFCCCD13074CCF7CCFACCD84DCCB434CCC4CCDA5FCCF866CCE6CCD5CCC6CCCD70CCC653CCDDCC882EAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020332374CCBA79025BCC9916CCD7CCD90CCCDC5CCCE0CCA8CCE368CC9F590136CCCB15CCC868CC8BCCA809CC84CCF30082A47A6574619182A474797065A6427566666572A464617461DC002018CC88415E4CCC9E64720DCCF873CCAC561748CCEA26CCF9CC8B153D61CCF34BCCCDCCA62710CCC9500C1BAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCA1CC80CC81CCEC3CCCC6CCF9CC9A5E1ECCC7CCF9CCA2CCF2217743437DCC8BCCF7CCDFCCC3CCC51ECCDECC96CCA0CC8438091182A47A6574619182A474797065A6427566666572A464617461DC0020CCCC40CC942544CCB12E2F46CCF4CCA1CC8ACCC2596C113363CCDF2FCCAF41CCFECCD5CCE5CCFDCCFD7C33107E26AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002011CCAF34CCA9470870CCE7CCF411CCC2CC8741CCDD52CCAB55CCC1CCCECC876ACC870305622F7ACCCBCC8761CCB00982A47A6574619182A474797065A6427566666572A464617461DC0020CCEC6741CCFECCA4CCF6CCF91FCCE6CCDCCC9E5E746B2857CCFFCC962B4ACCCECCE7CCE9CCD429CCB4CCD2CC8D1FCC8DCCFC02AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC81CCA9CCE6CCC546CCA8555ECCF82607CCCECC9563CCDC31CCA3CCD8CCDA2BCCA4CCBE18616426697D696ECC831DAC636F656666696369656E74739F82A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020000000000000000000000000000000000000000000000000000000000000000082A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B067656E657269635F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B1706F736569646F6E5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B5636F6D706C6574655F6164645F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AC6D756C5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AD656D756C5F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B7656E646F6D756C5F7363616C61725F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000000B572616E67655F636865636B305F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC0020CCA8CC92CCB340CCC520573BCCF5CCC60BCCABCCBDCCE7CC8F15CCE2CCEDCCEE31CC9B484D5FCCD62CCCC2CCC3391ACCFF2EAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC9D37CCAE26CC8702CCBB67CCFFCCBACC841DCCEB383113CCFBCCB3CCE6CC8FCCF0CCBFCCEFCCDB1B6F622645CC830F27B572616E67655F636865636B315F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC0020CCF2CC90CCC8CCA4CC8DCC92CCE7CCDFCCA93938044316CCBE6D37CCC9023A2A54CCD9043B0ECCBECCF912350703AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC941CCCCA71CCDA09CC8DCCD162CCF4CCBACCA814CCEE5BCC9ACCF9216D7CCC990E0ACCFECCB7CCB37B397CCC85CCBA15BA666F726569676E5F6669656C645F6164645F73656C6563746F72C0BA666F726569676E5F6669656C645F6D756C5F73656C6563746F72C0AC786F725F73656C6563746F72C0AC726F745F73656C6563746F72C0B26C6F6F6B75705F6167677265676174696F6E82A47A6574619182A474797065A6427566666572A464617461DC0020CCBB1ACCD376CCEECCF0CCA750CC8B711ACC97CC8160CCE1CCC5CCFCCCF0CCE0412861CCEF5128CCF4CC99CCCE39CCC4CCF80DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002032CC903FCCD27BCC9ECC9CCCAFCCBC39CCC1CCC3CC9BCCA36D0570CCA114CCAE2CCC9F1203CCBD60CCA31D7ACCBB0514AC6C6F6F6B75705F7461626C6582A47A6574619182A474797065A6427566666572A464617461DC00203D663E7E6610CCB1CC844863CC803466590A2A1CCCA451CCC755393BCCD3CCC762CC822B44CCA8CCB02BAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CC8ACC985A1D271113CCCACCE0CCA7CCEACCB5CC86CC845CCCB8CCCD2E27CCDF38CCD30E76CCC81832CC94CC8ECCF4CCAB1FAD6C6F6F6B75705F736F727465649582A47A6574619182A474797065A6427566666572A464617461DC002003CCF1CC8FCC8CCC843B1ACCC26DCCDE6ECCE46E64CCC9CCE971CCDECCC4CC84CCFE2FCCBACCFBCC8737CCACCC8756CC945F23AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCA3326726CCABCCD7CC904C23CC927068CC920F59CCB7CCEA17CCCFCC8878CC91CCC13ACCE36C3F4725CC8B222882A47A6574619182A474797065A6427566666572A464617461DC0020CCF52ECCB7683352CCA3CCF176CCEECCD461CCCC0C3ACCD905CC80CCAF4E25CCBE29CCA8CC99CCD87ECC8ACCC20FCCB90DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00207BCCD5CCC6CC9228CCE1CCBA3E037ACC854FCC9A6BCCCC492CCCA7CCA7CCF5CCEF3FCC862278CCC732CCDD45CCFCCCD02782A47A6574619182A474797065A6427566666572A464617461DC0020CC9741CCC7CCC0CCFC6F6A6768377ECCD94ACCB1CCC92FCCE66129CCE7CCC8CC8436CCB3CCBE2DCC8BCCF418CCB20415AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC00205772CCCF1B0A32CCFDCCE247CCC3CCDD6CCC8126CC83CCFCCCBE5F31CCA53521CC85CCBA72CCBDCC85344265701282A47A6574619182A474797065A6427566666572A464617461DC0020CCB4CCA0CCEA22046DCC87CCB2427F4954CC82CC84CCADCCD10BCCB7CCD7CC990044CCF4CCDFCCD95FCCD5CCD27167CCBE18AA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC0020CCF569CC93331A635C4465CCE85C6CCC8121CCBBCC93CCD7CC8DCCE6CCFACCE4CCE817CCD95270384D500ECCCB1582A47A6574619182A474797065A6427566666572A464617461DC0020CCB7CCCB1F526A127353CCDBCC97CCB7CCCB32CC82CCB26FCCE9CCBACCC4CCB8CCE915CC9F65CCBBCCDD42412A0F771DAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002005CCABCCEE75CCBA63CC9C0824CCCCCCFD6ACCC6CCE1CCC4CCF2CCACCCA9CCACCCA2CCD90716CCD746CCA3CCCD00002D4C26B472756E74696D655F6C6F6F6B75705F7461626C65C0BD72756E74696D655F6C6F6F6B75705F7461626C655F73656C6563746F72C0B3786F725F6C6F6F6B75705F73656C6563746F72C0BB6C6F6F6B75705F676174655F6C6F6F6B75705F73656C6563746F72C0BB72616E67655F636865636B5F6C6F6F6B75705F73656C6563746F7282A47A6574619182A474797065A6427566666572A464617461DC0020CCBD2ECCC43CCCBD197CCCC3112429CCCC1FCC83CCC26DCCBBCCB77DCC87CCDD691844CCA257CCB678CCEDCC9FCCEC1FAA7A6574615F6F6D6567619182A474797065A6427566666572A464617461DC002022CCE5404D5BCCA94DCCD57A78CCBE50CCFA5417CCF3CCCE46CCD5CCC4CCFDCCDCCC8226CCE5CC906A7861CCEF6C0FD921666F726569676E5F6669656C645F6D756C5F6C6F6F6B75705F73656C6563746F72C0A866745F6576616C3182A474797065A6427566666572A464617461DC00202E74CCF4CCB84B766ECCB00ACCC6CCFD70306ECCA8CCA2CC870ACCD8780864005B306ECC8DCC957CCCD04916AF707265765F6368616C6C656E67657390";
    bytes verifier_index_serialized =
        hex"DE0015A6646F6D61696E82A474797065A6427566666572A464617461DC00AC00400000000000000E00000000400000000000000000000000000000000000000000000000000000000000000140CCB0190CCCE6CC9CCC81CCABCC89CC97CCD87847CCBFCCC65752CCA76A7564CCA937631B66CCA7CCE1CC8C6330CC856E7C61CCC201CCAACCADCCE6CCAA2074CCE13ECCA9CCB4CCA8CCA8CCDC0DCCB8514E1FCC81CCE4CCD9CCCD5156CC962D10CC841C6434CCE9CCEECCF8CCC0717767CCB07609CCF4CC8C6ECC8E55420D6811CCE9CCE9CCE7066F031C28676666CCC6CCD4CCFBCCF3CCE7062D4ACCCACCE95CCCAECCA9CC8B56CCCD337CCCB5CCB949CCAACCD9135ACC94525B13AD6D61785F706F6C795F73697A65CD4000A77A6B5F726F777303A67075626C696300AF707265765F6368616C6C656E67657300AA7369676D615F636F6D6D9782A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC8E6A46CCC4CC9A5B053E3ACCD03ACCCACC896319CCAB43CC88CCAFCC887ECC84CCBC3DCCACCCFB49CCAB67CCDDCC93CC8AA773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200F751F4138CC9FCCEFCCCACCC43ACCB9CCA01B0810CCAB2CCCB74C70CCDFCCD8CC9521CCC7CCA0CCCFCCA15019CCDECCA4A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00205CCC903D4275CC90CC98CC987ACCE8CCA0CC946A33CCDACCB8CCBB386052CC93CCDF725A29CCC840CCF4CC87CCD6CCABCC99A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCDD7526CCDDCC86CCA2CC9CCCD6CC8F0ACC937E062E56CCD25E3250CC90CC86CCC958CC84CCE0CCA5CC9701CC99CC8F7BCCA5A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CC964300CC855F1C7BCCB37B55CC854C582F48CCC54938CCAB48CC815BCCD64A5ACCC62DCC8C37CCDDCCE403A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCF9322C5458CCD204CCDECC90CCE7CCFBCCED5E5ACCB2CCFC4651CCBA62297E0ACCFCCCF2CCCACCFBCCB0CCA05D0421A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCB3183ECCF8CCF4CC9410CCA465CCA4CCD145CC97CC9A4E5FCCB92FCCEACC81CCD7767434CC99CCC7CCC428CCEBCCBB6819A773686966746564C0B1636F656666696369656E74735F636F6D6D9F82A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C082A9756E736869667465649182A474797065A6427566666572A464617461DC00200000000000000000000000000000000000000000000000000000000000000040A773686966746564C0AC67656E657269635F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A870736D5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B1636F6D706C6574655F6164645F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A86D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0A9656D756C5F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B3656E646F6D756C5F7363616C61725F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020723737CCCF1CCCC96BCCB40021504A4FCCF45D21CC914ECC94CC84CCF2113D66545A3826CC91CC9ACC9C25A773686966746564C0B172616E67655F636865636B305F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020190C1BCC8C2123CC9301CCC0CCCD623DCCA5CC91CC84CCEBCC871B15076BCCF5CCC1CCD7497ACC8ACC99CCC2260ACCA4A773686966746564C0B172616E67655F636865636B315F636F6D6D82A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCFA37CCB2CCCFCCCB1A44CCE4CCF8204DCCB54FCC852335CCE0075ECC8D6BCC87CCB4CCA3CCB47444185C44CCEDCCAFA773686966746564C0B6666F726569676E5F6669656C645F6164645F636F6D6DC0B6666F726569676E5F6669656C645F6D756C5F636F6D6DC0A8786F725F636F6D6DC0A8726F745F636F6D6DC0A573686966749782A474797065A6427566666572A464617461DC0020010000000000000000000000000000000000000000000000000000000000000082A474797065A6427566666572A464617461DC0020CCE3CCA214CCE91334CCD0CCCACCF1CCEBCC85CCDF5BCCD7524D73CCD5CCEB7ACCAF742A7ECCB2CCD40BCCFDCCC8CCCDCCB90082A474797065A6427566666572A464617461DC00206D0F4433CC9A33CC9FCCB8CCA4CCE4CC9BCCF109CC9620CCAA64CC9918482BCC95CCA3CC97CCAE39CCB9CCEC5ACCD4770082A474797065A6427566666572A464617461DC0020CCB40923CCBD78CCE619CCC80A7B39CCC0CCF3CCF11E48005519CCD2CCFECCF16A1F77CCD40545CCE5CCC7770082A474797065A6427566666572A464617461DC0020CCF9CCC95CCCD6CCB11B38CCDF7855CCFD4D2A036329CCADCCCACCD613CCF100CCB92310CC9540356A597C0082A474797065A6427566666572A464617461DC00205A696526CCFA30CC9C412C10CCE86604CCC3CCC0CCAD2CCCD9443DCCD85BCC8232037212CC81CCCFCCBF330082A474797065A6427566666572A464617461DC002043423BCCB307CCCECCC1CC9F297C41CC88CCDECCB23ACCCC7B581271CC9B2ECCACCCCBCCF1CCB7034ACCE6CCACCCE800AC6C6F6F6B75705F696E64657886B16A6F696E745F6C6F6F6B75705F75736564C2AC6C6F6F6B75705F7461626C659182A9756E736869667465649182A474797065A6427566666572A464617461DC0020CCE6CCA15E7ECCA10ECCD2CC8F0F3361CCC7CCA7CCF45CCCED5E6D382017CC8CCC832CCCFCCCC0CCDF0E343ECCB1CC80A773686966746564C0B06C6F6F6B75705F73656C6563746F727384A3786F72C0A66C6F6F6B7570C0AB72616E67655F636865636B82A9756E736869667465649182A474797065A6427566666572A464617461DC00201B24636044CCD6CCED30CCC611CC85CCD45B2969CC98CCB811CCB754CCA5507C08CCD1CC9124CC9B37CCC01721A773686966746564C0A566666D756CC0A97461626C655F69647382A9756E736869667465649182A474797065A6427566666572A464617461DC00205F28CC8BCCB342CC8034CCA922CCB3CCE618CCEA3ECC811ECCDF61CC81CCB10B7ECCF6CCC859CCFD03CCEA2B39CCA70EA773686966746564C0AB6C6F6F6B75705F696E666F83AB6D61785F7065725F726F7704AE6D61785F6A6F696E745F73697A6501A8666561747572657383A87061747465726E7384A3786F72C2A66C6F6F6B7570C2AB72616E67655F636865636BC3B1666F726569676E5F6669656C645F6D756CC2B16A6F696E745F6C6F6F6B75705F75736564C2B3757365735F72756E74696D655F7461626C6573C2B772756E74696D655F7461626C65735F73656C6563746F72C0";
    bytes urs_serialized =
        hex"92dc0020c4200100000000000000000000000000000000000000000000000000000000000000c42055a8e8d2b2221c2e7641eb8f5b656e352c9e7b5aca91da8ca92fe127e7fb2c21c42003bc09f3825fafdefe1cb25b4a296b60f2129a1c3a90826c3dc2021be421aa8ec4206422698aa4f80a088fd4e0d3a3cd517c2cb1f280cb95c9313823b8f8060f1786c4203558cb03f0cf841ed3a8145a7a8084e182731a9628779ef59d3bc47bae8a1192c4202ac41dd231cb8e97ffc3281b20e6799c0ae18afc13d3de1b4b363a0cd070baa7c420b6205dfa129f52601adfd87829901f06f1fd32e22a71f44b769d674448f05d83c4205d1b9b83cdcba66ff9424c7242c67394d7956dabf5407f4105124b7239d43e80c420e95ffc0999a8997b045430aa564c7bd9a25303e8a5ebbe4a99f6329b7f2a64aac4206cca50f1237f867fee63ac65249d6911494680f42d0e71386b1586be39092f9cc4204b9b17d64b384a65d7c80c8ab0f5fff75c69fd147835599753beea03152a3923c4205c0f706b036ed361e787af70acea3533d6e349869e83368979fdbbf382a4900bc420da6652a81754a6263e677d23a55bd729205f5fb64fa39b6771d9b811e5548bafc4208db1ad69d758362a4ecacff98a6910a95b3c2697e455271b2d7c078f1894eb1fc42010f56f1046a1121b1df5c401969b5acbf80eef8bfd5438270e09243413382788c4200cca37d1a3a721792dc232bb6a95bd14143350b6784bcdd4898a0bb34dd8bd2cc4202b7a1991e05b77d911d15ae590ff6f6ad7d1ed572b34654e3ce92e38e4839425c4201977ca4631e9eea53c7ba59d334c14dac7ee1071d6bf6ebf2ab7450c16975d23c4209eb742379ee8664a8bf9c18a40a534bb2961020bd0077cd0b603d2a8b9fe5a17c4201c50af6002db8dfa5a310ce795dcb06de94ead6687687263fd59acbc8612f180c4205241cbed55fbe1193f366e7ea8ad11bc97742eb35ca39129c4931b9bef64df1ec420646e69eb7d4682ad6bff24d40bf22184694c569246385cc127b3ec4a99875a85c42046b77ed1e120130743344ea9372ea58118604c730800e0d7038f2c80211f4f90c4208f20f3c39a09b5615bd8b2a09eec7dbc11b5ea1f8fe7eb0d5a69c1264412d199c42095f0b87ed771c169a8b6c0a6e21b13ab715407a4e6637a0b8fe0a1e3278f32a7c420a80440e1a07157bad23d7a7d3ddd7445f578021650016fc4bfb3324ed967c82bc4202b94fd0b89e7e2c9d245a4e94a539b14c5db26ed5ba4b3989ef0ba0712d4582ec42068f583079aa73425184a328127be63421eae683a25be94a0aa697ce74b5b972dc4209fa10b770e452852612ea392b8521683999d0a168c5eb85a6925d1ffe21d418ac420826a0976821c9309ed896678a97634a2fb1392a64ab8c59c8380012ffb601189c4203096ba3ed0b597fa29da6caa9000a409702b1f945561e82d02ab77b0cfdb649fc4204a718bc27174d557e036bcbcb9874ce5a6e1a63ccbe491e509d4201bfcb50806c420723737cf1cc96bb40021504a4ff45d21914e9484f2113d66545a3826919a9c250a";

    function test_partial_verify() public {
        KimchiVerifier verifier = new KimchiVerifier();

        verifier.setup(urs_serialized);

        verifier.verify_with_index(
            verifier_index_serialized,
            prover_proof_serialized
        );
    }
}
