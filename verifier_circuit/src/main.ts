import { readFileSync, writeFileSync } from "fs";
import { ForeignGroup } from "o1js";
import { Verifier } from "./verifier/verifier.js";
import { deserOpeningProof } from "./serde/serde_proof.js";
import { ForeignField } from "./foreign_fields/foreign_field.js";

let inputs;
try {
    inputs = JSON.parse(readFileSync("./src/inputs.json", "utf-8"));
} catch (e) {
    console.log("Using default inputs");
    inputs = {
        lr: [
            [
                {
                    x: "15056458356549368836415633500603264082819406126835989214093189700490430930116",
                    y: "1928005820572277184380963105363980983102097028550233849236781406603089872153"
                },
                {
                    x: "9182167604036410118677763325402408926194953997439983663372403476636404780089",
                    y: "20909274614588990083270453623720008616518463619466932076869095069338417606955"
                }
            ],
            [
                {
                    x: "19062458101827706513660889881054866727327343607507982123158510082753084649154",
                    y: "7537258272679824270706593784561520223299347412573748455110280162065083448682"
                },
                {
                    x: "3065229608570483859392376442394536918171915826427479130451366194559803303962",
                    y: "28305423865365603509793697681803611202003837696247454201108870650912990170560"
                }
            ],
            [
                {
                    x: "8228937498310069267773255373362656199670008775554861152924089212004386334741",
                    y: "17793603729181823107964165774303821283633431758501735288205353170921649957220"
                },
                {
                    x: "17295776460154203249387329824146486765233816557379311666554679385157844646637",
                    y: "19746536534306794841560548822399424130721399789033039886088015014223622413716"
                }
            ],
            [
                {
                    x: "26722771704284443688160882187912538566887119421362549546344521989029146496189",
                    y: "8596230220359770003101880867746887492406106246998608421353598890048537763303"
                },
                {
                    x: "1124229489469359266107147221490530526555807859779856281029706624360591882988",
                    y: "14516987202492889029649105334168236475528055961771554168559116104858596971811"
                }
            ],
            [
                {
                    x: "7481290794888540167756117454586301142614716210995011934341423509917544489149",
                    y: "28112604356047470676089579814139744504056836236831141862866605072069967340892"
                },
                {
                    x: "12992621779046151948693103403570053044157597438612813490091786654617355043519",
                    y: "26414773678100887173724924046494436667688331383648127439574866785116403129927"
                }
            ],
            [
                {
                    x: "21340609344578428659848896695074420041225502940513627367214048746429572223322",
                    y: "21043920579589589330295826688109489028802535941108123505425023485198962315714"
                },
                {
                    x: "18469747189720246941892142627426271937379012069052629525194832660289254813601",
                    y: "9515599646233475194309538751390679428585519691491126105022538689193743284789"
                }
            ],
            [
                {
                    x: "159102287799330434463376845083396554513864739430706682413509901377116833570",
                    y: "18635743149334409772539967606413077940369661467128311092642866569900915739247"
                },
                {
                    x: "8633482100448602739257547638726501006678646858952466677388987217565092023007",
                    y: "19103619640284066331902091440868353486908464827912191238707076036054412966715"
                }
            ],
            [
                {
                    x: "1065744395229239059865995435622815633328942311823641471511955115723649011692",
                    y: "22247708742931016388708150556051006886614838574436535540895418082141409884720"
                },
                {
                    x: "7182287414862859896011959572365935074210394616064729482174734984705278229969",
                    y: "2522408908603772989775126667431225205270468259100355313890475616917016187632"
                }
            ],
            [
                {
                    x: "8698493090886338577943737311004205414136384256934696053333619560414991976040",
                    y: "8079713557014151488183820855838431064731935433150058976742617002334708082901"
                },
                {
                    x: "19474958820205604015244105389050453846253192874434348128253236026832429734342",
                    y: "19559667068832536392427755594970585440741471968355150722533074315169235900982"
                }
            ],
            [
                {
                    x: "14846175827469966978763304894608400366946824181628031806765338480618837997949",
                    y: "1450927296652806916480366170838951610376370001846009428463032936821009667940"
                },
                {
                    x: "24008051939642014513890279046098142854351239640243428142754718225782602951216",
                    y: "17208913362274177797032229409566532784966898770577167988999939520785024802069"
                }
            ],
            [
                {
                    x: "2946060301574890651391856819216980710355491138728809532062269262459434151802",
                    y: "9854468153121475191969781023762663717097881956501795032956784060992036927263"
                },
                {
                    x: "7328723969625239561926724215691170700623562175085982545001079109379438760716",
                    y: "9898397285029374442293298267733718921067981525129999852233914093602298807405"
                }
            ],
            [
                {
                    x: "12983022367612407645046298916522325008479088230306768758837317694994709249026",
                    y: "7245054108967065918406624538032466052364774295177922618089460081859571841268"
                },
                {
                    x: "6480154251938154602906429614317966977964121815807607560809010681863994140561",
                    y: "4927179016306050825369079942785185817992764272845172082132606677127727600815"
                }
            ],
            [
                {
                    x: "4641485974558971814501734042550153509435117315169699526132490507944372979092",
                    y: "10928112838492019735533269571387222256137510803780188500476031109792007137564"
                },
                {
                    x: "12117229535699278412898914422747301262111474546582169882166727664554750557105",
                    y: "9148093048442265141406450337737209342044047868850291508030546843127943258640"
                }
            ],
            [
                {
                    x: "12499585482194471938916657011396736825212796614273303154191563346857806776830",
                    y: "2753257740836654479999754161261134022721758312663829926292220695628136269693"
                },
                {
                    x: "8966014484183991848942964459883730173140299599507566274345071962900117910258",
                    y: "27195242318195937027170630104856602559028096227142236571322768396345584732442"
                }
            ],
            [
                {
                    x: "14881144118948554857555018857445430880469957187889557937666726549121104890453",
                    y: "19217742189659546142610667717601175383499175578467547254213786114667884708330"
                },
                {
                    x: "20641115612459006722008199719758629604928375919234914751170135403598740580346",
                    y: "28295335450993256160133865752838758105258730682624968898412730524026902806946"
                }
            ],
            [
                {
                    x: "529428558106229823346926265048411183540427749411260062871802184470411397597",
                    y: "26633857841397297989794386200903781106253753888786960863116515850963665429174"
                },
                {
                    x: "21664977641877179287655018363222834100788934643275839757364598108148473993257",
                    y: "22295431001057758423313591920158790805914173392619762721028139596564449674176"
                }
            ],
            [
                {
                    x: "5632622980941715115746064082249106829671294237624483290707960620563359134085",
                    y: "27144546804685920640095412985232420000440964221450509119472274570150914792699"
                },
                {
                    x: "3076218371151160128254340036596757745056040459655556158450727638117859407442",
                    y: "16967804336957477531777458676308931648530486021356200301255377860402258266353"
                }
            ]
        ],
        z1: "18845944470864557066061335688631852589739377437901427006344079231778889146583",
        z2: "11541666340858523044638638958882681270199360990343878907487629352130149288654",
        delta: {
            x: "27912413724899915430798699554911957726900924053030261912898866221492838898090",
            y: "1348851537069545967541844547386640191635584379045685108861781238912529403388"
        },
        sg: {
            x: "7305352762199476900646532835923736945118344132878064466681297617935968538405",
            y: "12830329628725949683485078920424344038983458282825212027279434925082536425380"
        },
        expected: {
            x: "27192842137970086387668453521227458723324579704177139492340627945016788024595",
            y: "15359381866960722347427095147982607799207355786870875866481794641234265669315"
        }
    }

}

console.log('O1JS loaded');

// ----------------------------------------------------

console.log("Generating circuit keypair...");
let keypair = await Verifier.generateKeypair();

console.log("Proving...");
let openingProof = deserOpeningProof(inputs);
let proof = await Verifier.prove([], [openingProof], keypair);
console.log(proof);

console.log("Writing circuit gates into file...");
let gates = keypair.constraintSystem();
writeFileSync("../kzg_prover/gates.json", JSON.stringify(gates));

// ----------------------------------------------------
console.log('Shutting down O1JS...');
