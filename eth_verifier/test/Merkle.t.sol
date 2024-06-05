// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "poseidon/Sponge.sol";
import "pasta/Fields.sol";
import "merkle/Verify.sol";

contract MerkleTest is Test {
    Poseidon poseidon_sponge_contract;
    MerkleVerifier merkle_verifier;

    function setUp() public {
        poseidon_sponge_contract = new Poseidon();
        merkle_verifier = new MerkleVerifier();
    }

    function test_depth_1_proof() public {
        MerkleVerifier.PathElement[]
            memory merkle_path = new MerkleVerifier.PathElement[](1);
        merkle_path[0] = MerkleVerifier.PathElement(
            Pasta.from(42),
            MerkleVerifier.LeftOrRight.Left
        );

        Pasta.Fp leaf_hash = Pasta.from(80);

        Pasta.Fp root = merkle_verifier.calc_path_root(
            merkle_path,
            leaf_hash,
            poseidon_sponge_contract
        );

        assertEq(
            Pasta.Fp.unwrap(root),
            586916851671628937271642655597333396477811635876932869114437365941107007713
        );
    }

    function test_depth_2_proof() public {
        MerkleVerifier.PathElement[]
            memory merkle_path = new MerkleVerifier.PathElement[](2);
        merkle_path[0] = MerkleVerifier.PathElement(
            Pasta.from(42),
            MerkleVerifier.LeftOrRight.Left
        );
        merkle_path[1] = MerkleVerifier.PathElement(
            Pasta.from(28),
            MerkleVerifier.LeftOrRight.Right
        );

        Pasta.Fp leaf_hash = Pasta.from(80);

        Pasta.Fp root = merkle_verifier.calc_path_root(
            merkle_path,
            leaf_hash,
            poseidon_sponge_contract
        );

        assertEq(
            Pasta.Fp.unwrap(root),
            20179372078419284495777784494767897705526278687856314176984937187561031505424
        );
    }

    function test_depth_35_proof() public {
        // Proof taken from local sandbox Mina node

        MerkleVerifier.PathElement[] memory merkle_path = new MerkleVerifier.PathElement[](35);
        MerkleVerifier.PathElement[35] memory merkle_path_fix = [
            MerkleVerifier.PathElement(Pasta.from(25269606294916619424328783876704640983264873133815222226208603489064938585963), MerkleVerifier.LeftOrRight.Right),
            MerkleVerifier.PathElement(Pasta.from(25007007256384944882905405604034518504068874873083358951799359466121314322110), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(7215733857675538665207647125574410089751356370280345059969727973716036781109), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(11675502286292853653967170164874347759631001134551978982661175757639336655203), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(4693941016685726924011477103376122792121393624262436606875444683370096234842), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(16433445017086641142063239834507914818488546646730449637369850633542683002323), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(19525687889735069135389545695685589898547363283645924409997338604644211020165), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(21445019880069604159182854981425354819870947976592388639924911106308886101583), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(20894402139528067835909935277874525399255235657001118287546511264386895769621), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(883229644397733039066253671955693697113975269219426363508259187408670360883), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(9769914702946050828692551650179547224426684260009754295891562165984001044159), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(10297524488630367552093608413474608735915477327721251109778411714211204757470), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(1496321477249655206167525073537310005622058311564791180207644487283463863898), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(10772837653959418633137031193105415079228935669218218525739441178449860550037), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(696092792553552689655004235885208270952911318900402910117767792225021223362), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(20499284764105850422619742708102293468642385252120895329218092651295105457537), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(12197922778747608042733767950590679520334041548650005099692442442290423955136), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(6781788106327601599702202199756117532472472684470091628838303569264537775700), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(16918038186554675056000578097630897159236284751433663183439602696852905624415), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(28627628212319805343454811139849901640500073315285842033614442274505756385536), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(28758859610334920473530372700694516882691452974475767468086895285359096307274), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(16430190523938219721147185711044261861887815192145019235086508794037748662978), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(23300248870286894992003584685086043578048220924304538552357941351343423298077), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(18721105361232651344875520416758751524020336778169872574984370086949138642085), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(10611828583016686420873473112404506690775956092186634604097134580560948638514), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(11448813184116204118725235537673043143764404790624366392625860187638781235615), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(6507258883578376028376981545955062827139698232277887871775971553968101691249), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(17493244980280937955941580434326677459751473714746227943153210535373918340114), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(18464507392887829891264190376236139806757048001410567864732128380527868369455), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(374677701015397178366310913911051069892586440922808798004746377118603064136), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(7414597540944309778303590613882007538175921122373418819351437768289067050688), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(4911425897386868865951704774190352922917918118795543476097437449334578129718), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(2537948008614359414287158135558328051431310188498471600040371216889620767874), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(11945594868601920248817415866479228952991063900530321216805456660202303767865), MerkleVerifier.LeftOrRight.Left),
            MerkleVerifier.PathElement(Pasta.from(7727454798157491451398259626232336317494512806516291520841511378379541110711), MerkleVerifier.LeftOrRight.Left)
        ];
        for (uint256 i = 0; i < merkle_path.length; i++) {
            merkle_path[i] = merkle_path_fix[i];
        }

        Pasta.Fp leaf_hash = Pasta.from(5547050440260440001206353800257378236791122500588428095288570642887590248302);

        Pasta.Fp root = merkle_verifier.calc_path_root(
            merkle_path,
            leaf_hash,
            poseidon_sponge_contract
        );

        assertEq(
            Pasta.Fp.unwrap(root),
            25386343758799444195005156917506668892978004126168706919054504716147406520412
        );
    }
}
