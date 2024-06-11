// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../bn254/Fields.sol";
import {console} from "forge-std/console.sol";

contract Poseidon {
    using {Scalar.add, Scalar.mul, Scalar.pow} for uint256;

    uint256 constant RATE = 2;
    uint256 constant ROUNDS = 55;

    enum SpongeMode {
        Absorbing,
        Squeezing
    }

    struct Sponge {
        uint256[3] state;
        uint256 offset;
        SpongeMode mode;
    }

    function new_sponge() public pure returns (Sponge memory sponge) {
        sponge.offset = 0;
        sponge.mode = SpongeMode.Absorbing;
    }

    function absorb(
        Sponge memory self,
        uint256 fe
    ) public view returns (Sponge memory updated_self) {
        updated_self = self;
        if (updated_self.mode == SpongeMode.Squeezing) {
            updated_self.mode = SpongeMode.Absorbing;
            updated_self.offset = 0;
        } else if (self.offset == RATE) {
            updated_self.state = permutation(updated_self.state);
            updated_self.offset = 0;
        }

        updated_self.state[updated_self.offset] = updated_self
            .state[updated_self.offset]
            .add(fe);
        updated_self.offset += 1;
    }

    function squeeze(
        Sponge memory self
    ) public view returns (Sponge memory updated_self, uint256 result) {
        updated_self = self;
        if (
            updated_self.mode == SpongeMode.Absorbing ||
            updated_self.offset == RATE
        ) {
            updated_self.mode = SpongeMode.Squeezing;
            self.state = permutation(self.state);
            updated_self.offset = 0;
        }

        result = updated_self.state[updated_self.offset];
        updated_self.offset += 1;
    }

    function sbox(uint256 f) private view returns (uint256) {
        return f.pow(7);
    }

    function apply_mds(
        uint256[3] memory state
    ) private pure returns (uint256[3] memory n) {
        n[0] = state[0].mul(mds0).add(state[1].mul(mds1)).add(
            state[2].mul(mds2)
        );
        n[1] = state[0].mul(mds3).add(state[1].mul(mds4)).add(
            state[2].mul(mds5)
        );
        n[2] = state[0].mul(mds6).add(state[1].mul(mds7)).add(
            state[2].mul(mds8)
        );
    }

    function apply_round(
        uint256 round,
        uint256[3] memory state
    ) private view returns (uint256[3] memory) {
        state[0] = sbox(state[0]);
        state[1] = sbox(state[1]);
        state[2] = sbox(state[2]);

        state = apply_mds(state);

        state[0] = state[0].add(round_constants[round * 3]);
        state[1] = state[1].add(round_constants[round * 3 + 1]);
        state[2] = state[2].add(round_constants[round * 3 + 2]);

        return state;
    }

    function permutation(
        uint256[3] memory state
    ) internal view returns (uint256[3] memory) {
        for (uint256 round = 0; round < ROUNDS; round++) {
            state = apply_round(round, state);
        }
        return state;
    }

    uint256 internal constant mds0 =
        15913613074278028058360498857043999222867772811338037425231170199156889337604;
    uint256 internal constant mds1 =
        65180538277771794992983614695816638391617290189527384182155063505825555179;
    uint256 internal constant mds2 =
        5394145287608961087977235806233358974273334844303649346024304966582176196487;
    uint256 internal constant mds3 =
        15414815283538893716009156559702084916211023875136356807248219032453798152465;
    uint256 internal constant mds4 =
        3463018243616155786290732419705147785020336294529003837260493734746385539469;
    uint256 internal constant mds5 =
        12716468877825667500219920861172138145894921271005565146996037137547785771411;
    uint256 internal constant mds6 =
        1792045203208933407244693490495238027092197802128268175009298962707699842710;
    uint256 internal constant mds7 =
        76356542649790718492035692281837451271781062546545119705441901238018861818;
    uint256 internal constant mds8 =
        9520069514281255561624128661339565451189764370791651000392579220353790670830;

    uint256[165] internal round_constants = [
        12455131979215983316735047846658291859029812584241282581257197013302738138666,
        20029656970890966196099810168066995443524989185718089119520857141365451679654,
        8929913078653797661905726823410775654210481762974885244818731639242977419622,
        8662787891019924101534530927954444401015394189462080864609938870691307539536,
        20294115837600366998212029140165760858924828875933683067126492672917588261877,
        2682014173266320611146882768057075830238591616831154961603507352639750394592,
        18907515456503482670621260399010811269866082079896285203284611749350771281411,
        1424609887444859910324043210736091906100438801135358613993092433663809225411,
        1531059541788158835714117823424146308635531997487162670061618032695665453831,
        19444238474448321066398700689084787616548516614414549514749853660756611792379,
        2236237945310446639621733106225706828551103453944652411264620402517164583264,
        12605646628049520919535266096828454658561884709869426105979276828733666269521,
        14653124040822125428573681427514890989900893513402451718822527259901516216058,
        1535968898232047429062068090527484451997796559364245278047376516596586180554,
        3307538294663905716144414865227035949873283327379581103741297483063276195183,
        21111467054595055527346262240389751012262991994706430976179289552457483727796,
        17649294376560630922417546944777537620537408190408066211453084495108565929366,
        7683463515567855955851784553909126014159314191075450219244796328948411069744,
        21262229851583325466767017312569047417622760705999088078958228786464449033067,
        11691182518884460508022694337582074624192039580202157360389815110719437213363,
        8690728446593494554377477996892461126663797704587025899930929227865493269824,
        21622260498668079571860417097494779160364898191075577203239012897437375456411,
        21067767847052854366896470071519184914663018103241392453030719014890445499665,
        21348828409856354758094844442899573788047317201055667836817119877806560465334,
        2704440995725305992776846806711930876273040749514871232837487081811513368296,
        1142050494870706434296077676238780951797136607536187326800297147932619878418,
        3652944740784795248484484454916800802095288396765069024258114251561069674735,
        1747641587474624832364464288237802774971629275511085691789065855359044028198,
        14935834110027005954806028171080511939971704126366459140378790942754129686907,
        3215720726490672077485888789426411334496962379737529853320875594879037332594,
        2892159931078719741396670290810431382361178666606213506995456264415113913847,
        1938538891009879014088646889644828497511974353410971027478866497380422633484,
        13916214761542255527505866254811968868327635410573168146297241319868121689821,
        266821775768872344171470219200118028338254464492956024813242747554382748942,
        11055386921184594780372263378420826851562920740321950336882051897732501262543,
        2504617730099125455929793538006173214604536705392412461363354681040283013164,
        8077046888362371937918818344109572894796988781119069525502907016581642522710,
        7281012798633884984170366068851653834509460567285503188952416990462599509288,
        11914125581503780978633571238267986373793149282818856451291452464271781243920,
        5911373857383996424444312456230128887937254975139357544835683280828995545397,
        20728259298426389276714612941176977888429183727869747381529137474366072279101,
        8331123017723440628782766975941869108307759426898189357261715346312601104654,
        19978529403683797449165109778464832800224916941903951374610236813523844409526,
        17316158269457914256007584527534747738658973027567786054549020564540952112346,
        7848194400773744361171082305364633343688318123652518347170031226439829254882,
        17698087730709566968258013675219881840614043344609152682517330801348583470562,
        2484533502052370851335172153342694835144795809438965797062785488685902188726,
        13372068881052003992228272108672679285817785895634149926809187580418595890381,
        4450005426773734601782625050142815413017019480402129494014819930729323864775,
        15031465389782276133463098319911853017052619244999605688724393058338301291115,
        6028902109643218557806340932181364476799161079643636815411563224652423572198,
        2957732585137901025626087202113249345076588554941059487693780861098604986119,
        12565476532112137808460978474958060441970941349010371267577877299656634907765,
        10508327646678453674728048391759640526197954899878596680197847666563367632543,
        4493451765845812430310778141104432201437429164475176054680492630627878568332,
        15095408309586969968044201398966210357547906905122453139947200130015688526573,
        10819130048432875198797495465270179395954461390529553930221225323229387202234,
        15905267794015672354278595057670574122197927816429433548802165993220415414073,
        19290205907831398371768999387869637435049824367233327965730120884036212709842,
        15451920390057917627290027104082580122165965120355347782937661856388593985245,
        6425598873527092853966039409614693840647173123073098849086711894647944582332,
        17307716513182567320564075539526480893558355908652993731441220999922946005081,
        19372285427179952013203092658533484049593114439149219035606060254764845851391,
        14724939606645168531546334343600232253284320276481307778787768813885931648950,
        4684996260500305121238590806572541849891754312215139285622888510153705963000,
        19906278135333202031075665370853003279083131420237405129919260859757146418025,
        3999693912508849442569285360026642503093489903926874133118153062461080435481,
        20129375303694053217240183105192753906500831553949001131297105718176015558964,
        17281496576809338419011697046933296343189100335422897604615575811331627359485,
        15637748291684046440453413703705692658155214802161964102299272768648229342362,
        2094444825794502002152585986969571562449905861771519270554787618649438333195,
        1152889601932463959824817875107315518104722504910095364729880245759523916044,
        12114165850379066500859611262167642397834899331804245444372878412987365128590,
        20821227542001445006023346122554483849065713580779858784021328359824080462519,
        3440756720132945332811173288138999408441021502908547499697282473681525253805,
        20938628428302899368158656913047855118000040623605421135349389583331392728782,
        8850081254230234130482383430433176873344633494243110112848647064077741649744,
        1819639941546179668398979507053724449231350395599747300736218202072168364980,
        21219092773772827667886204262476112905428217689703647484316763603169544906986,
        13148487544990345541730567143235754764404038697816450525897467218977412799129,
        13598807739063229961519663325640861142062394342851403440808670891533339780790,
        18784327298376147342042823437947970462892869194728299228507919810276864843414,
        2764493745803317574883853704043825342340808631956690807684613803167040529511,
        21531775639025076953020023111055490895978901214310417059307899853240995381819,
        19964398501876039777029130298682737202257582985971095863290288610857831427638,
        15003442983970848114681480873546789629160262059108570865485071572172687676835,
        20614241966717622390914334053622572167995367802051836931454426877074875942253,
        19733168743390283576337440585736332292298547880804855952734808967278966077887,
        20530621481603446397085836296967350209890164029268319619481535419199429275412,
        12361620530467399202722610329149901344545851901477091854159960517963801528971,
        9497854724940806346676139162466690071592872530638144182764466319052293463165,
        7549205476288061047040852944548942878112823732145584918107208536541712726277,
        9010672859023729500640324904403960830965495099902505763591033382017769059028,
        809006882768062359480853341102632220777932068978149301935174282279746446958,
        7106371976957177712230305966566701811850820970657101896348127436646177656365,
        18845123379649840503129460949570724717923057602542920800815047452665097128575,
        14712923944932171466124439335703740452883296028663247289510978550197451911919,
        19555759172327736128240171000715903945570888389700763573790859521156095228287,
        17179695917466049633838471880559548490881310699092342418090873652775810295378,
        18944876856792381816055068913314141690530834943354883079085532905267119397008,
        3257630700960849517603336097571474897923100547762764495987576852490355943460,
        3963500912949736174926372928446487843084987377580944585294277449817215093365,
        21304716730402869084944080869903443431235336418077153507261240151959530377653,
        18998265936988640248585036755202701418246223100957416731998639191794797638003,
        16839625825914009701942141907800050396084195897386326382915730670235616618695,
        16907937154215020261110468963982390213438461071031811101554056252102505124726,
        1294898660752289889975651445755491766586322714088107994205473403531724749589,
        9172546393414544394143001120250095355087186863911844697260687867341704896778,
        18891778779724165209072874482651171817270086247356116562427206569585293483055,
        13093554332096549605604948416229955030385793767090042194569924056338021838108,
        6540069282618873496342140872069384185118574828832026154295825270730722501809,
        11698805795265597745890922320669982345748592147825010914959366790903803563027,
        11128587690756409041400570351324823090287237584985813997261416805030246953137,
        574796972312053991589591668868339165343116554180562026519971681663627339366,
        8263653526367544279471418475309371793291954818747935714794248360166503487859,
        495546618036723566920914648951352373868059898268055487677897567226892784967,
        2528292188392170914010448139211586215817069915670005292953294092269979070980,
        14954597262610438728753406794870316034770442280143947719391702684620418262496,
        2873290581141877304970576969082349138229332018341156071844198415188999408160,
        7877226570858832633875209751493918650976179001613717862579011309181456152753,
        5290811263292128650829809831924435265520706616680110737471312421357061576251,
        5711353914598993184207904758686192904620948114158132435163135551043392236587,
        9671966951859991559346179676315084295317241890404128352532995814366687016784,
        20648234869018782942484412385329986060607455807332118750782252709151244400533,
        1521221467156754943933671253020851096017281629892920730907443291972734010497,
        6375300799036358132607612364454746219201386369274233783761503007631282551380,
        18921242117750773300194037006101341214923275379274370683247849512779159129078,
        7813033521740037204631731835076108697814182206021466630450781049551634237483,
        7795208366125068859216483161820518701837348485078219412133643408967011329822,
        21634048616875364065210304993971256601326650069082669576726378272437410251852,
        1440291557054822025042926468154900761163167753541613162663250995564641638121,
        8030862880899531201072645375229460968330384014296763956553993045932171788794,
        18227143364048378671809657511264604955612895339528675264153781365139338073044,
        21758886539711282145698252967647695643837152466011063420158481037553923112829,
        2085588517087605436136379278738013214233743532079287631079316773925068862732,
        9513664655545306376987968929852776467090105742275395185801917554996684570014,
        3550496136894926428779047632731319031180547135184616875506154252232382772731,
        17611757480287922505786279147168077243913583114117625089682651438292645979006,
        9510531870810299962531161626148485102758508164021526746981465493469502973181,
        13147395489659079072941169740078305253501735721348147621757420460777184976765,
        20981004218820236011689230170078809973840534961691702543937445515733151438851,
        7510474971056266438887013036637998526887329893492694485779774584612719651459,
        1410506880075029891986606588556057112819357276074907152324471561666187504226,
        8531153700191448965915372279944017070557402838400132057846710117192547288312,
        9754021311900999917627020811752417367253388211990562024285328010011773088524,
        2596434275792412604724294796434266571220373976229139969740378299737237088707,
        12362606196840499695717697542757730593369897628148107607660372162713524022091,
        7436712609498458515091822640340398689078308761236724993140849063351217155692,
        13658397008139421803306375444518324400013880452735832208526361116879733324843,
        8172299227253932586074375157726142633344272790321861656172484971306271304428,
        8605586894544301092657394167906502995894014247978769840701086209902531650480,
        8900145888985471928279988821934068156350024482295663273746853580585203659117,
        10470367937616887936936637392485540045417066546520320064401889047735866701687,
        11506602210275354295255815678397482725225279643868372198705067756030230710066,
        17848856881287888035559207919717746181941756011012420474955535369227552058196,
        19621145748343950799654655801831590696734631175445290325293238308726746856381,
        12864577757979281303137787677967581089249504938390812240088160999517854207023,
        18146514933233558325125054842576736679593504913006946427595273862389774486334,
        17884323247493851213892188228998881081766487773962855826892871743190914823275,
        15402752720164650756401756498467037967910822997380610100998339390049962612988,
        7603833157231114748089157493970988832295123465399487746989788482408777456140,
        2397354421161661799662850246720819176952681967344524176801474312220041680576,
        4644616545339594419852483555455431260822330146405566037177120172304445909733
    ];
}
