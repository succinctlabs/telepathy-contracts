pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/lightclient/LightClient.sol";
import "../../src/lightclient/libraries/SimpleSerialize.sol";

contract LightClientTest is Test {
    LightClient lc;

    function setUp() public {
        bytes32 genesisValidatorsRoot = bytes32(
            0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb
        );
        uint256 genesisTime = 1616508000;
        uint256 secondsPerSlot = 12;
        uint256 syncCommitteePeriod = 532;
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(7032059424740925146199071046477651269705772793323287102921912953216115444414);

        lc = new LightClient(
            genesisValidatorsRoot,
            genesisTime,
            secondsPerSlot,
            syncCommitteePeriod,
            syncCommitteePoseidon
        );
        vm.warp(9999999999999);
    }

    function testProof() public {
        uint256[2] memory a = [
            19052226342225059169368468943242899722463738230905472208500084961135663160509,
            16380864488893534373718997305335489269591160449720961122684967788310493516960
        ];
        uint256[2][2] memory b = [
            [
                4244962819146553706141100213693629757064153729737155348694001350554073199025,
                2406202055061937495864025448062673105573298015762558145337278147528693758087
            ],
            [
                19863879735005091764507944581578827016309554400620309321981302697664139308420,
                4919212484791842246061291319810230307273866158940801673938573541010074937108
            ]
        ];
        uint256[2] memory c = [
            1829551706225848956019079207808894803390573677937562262492010544721230274603,
            13268182403423635285587955224347309783477597315739288159906876579157053326067
        ];
        uint256[1] memory inputs = [11375407177000571624392859794121663751494860578980775481430212221322179592816];
        require(lc.verifyProofStep(a, b, c, inputs) == true);
    }

    function testPublicInputsRoot() public {
        bytes32 finalizedHeaderRoot = bytes32(
            0xfad3ba4e53d01e392d6c191294d6191f51d769666bae2869ca3d2ac962c2cace
        );
        bytes32 finalizedSlotLE = SSZ.toLittleEndian(4359712);
        bytes32 participationLE = SSZ.toLittleEndian(426);
        bytes32 executionStateRoot = bytes32(
            0x6fc15b26deadfb27063a8ee1147dd66e060ddea457a7b9bb4473199dc352ab47
        );
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(7032059424740925146199071046477651269705772793323287102921912953216115444414);

        bytes32 h;
        h = sha256(bytes.concat(finalizedSlotLE, finalizedHeaderRoot));
        console.logBytes32(h);
        h = sha256(bytes.concat(h, participationLE));
        console.logBytes32(h);
        h = sha256(bytes.concat(h, executionStateRoot));
        console.logBytes32(h);
        h = sha256(bytes.concat(h, syncCommitteePoseidon));
        console.logBytes32(h);
        console.logUint(uint256(h) & (uint256(1 << 253) - 1));
    }

    function testStep() public {
        uint256 finalizedSlot = 4359840;
        uint256 participation = 432;
        bytes32 finalizedHeaderRoot = bytes32(
            0x70d0a7f53a459dd88eb37c6cfdfb8c48f120e504c96b182357498f2691aa5653
        );
        bytes32 executionStateRoot = bytes32(
            0x69d746cb81cd1fb4c11f4dcc04b6114596859b518614da0dd3b4192ff66c3a58
        );

        uint256[2] memory a = [
            14717729948616455402271823418418032272798439132063966868750456734930753033999,
            10284862272179454279380723177303354589165265724768792869172425850641532396958
        ];
        uint256[2][2] memory b = [
            [
                20094085308485991030092338753416508135313449543456147939097124612984047201335,
                11269943315518713067124801671029240901063146909738584854987772776806315890545
            ],
            [
                5111528818556913201486596055325815760919897402988418362773344272232635103877,
                8122139689435793554974799663854817979475528090524378333920791336987132768041
            ]
        ];
        uint256[2] memory c = [
            6410073677012431469384941862462268198904303371106734783574715889381934207004,
            11977981471972649035068934866969447415783144961145315609294880087827694234248
        ];


        Groth16Proof memory proof;
        proof.a = a;
        proof.b = b;
        proof.c = c;

        LightClientStep memory update = LightClientStep(
            finalizedSlot,
            participation,
            finalizedHeaderRoot,
            executionStateRoot,
            proof
        );

        lc.step(update);
    }

    function testRotate() public {
        uint256 finalizedSlot = 4360032;
        uint256 participation = 413;
        bytes32 finalizedHeaderRoot = bytes32(
            0xb6c60352d13b5a1028a99f11ec314004da83c9dbc58b7eba72ae71b3f3373c30
        );
        bytes32 executionStateRoot = bytes32(
            0xef6dc7ca7a8a7d3ab379fa196b1571398b0eb9744e2f827292c638562090f0cb
        );

        uint256[2] memory a = [
            2389393404492058253160068022258603729350770245558596428430133000235269498543,
            10369223312690872346127509312343439494640770569110984786213351208635909948543
        ];
        uint256[2][2] memory b = [
            [
                10181085549071219170085204492459257955822340639736743687662735377741773005552,
                11815959921059098071620606293769973610509565967606374482200288258603855668773
            ],
            [
                14404189974461708010365785617881368513005872936409632496299813856721680720909,
                4596699114942981172597823241348081341260261170814329779716288274614793962155
            ]
        ];
        uint256[2] memory c = [
            9035222358509333553848504918662877956429157268124015769960938782858405579405,
            10878155942650055578211805190943912843265267774943864267206635407924778282720
        ];


        Groth16Proof memory proof;
        proof.a = a;
        proof.b = b;
        proof.c = c;

        LightClientStep memory step = LightClientStep(
            finalizedSlot,
            participation,
            finalizedHeaderRoot,
            executionStateRoot,
            proof
        );

        uint256[2] memory a2 = [
            19432175986645681540999611667567820365521443728844489852797484819167568900221,
            17819747348018194504213652705429154717568216715442697677977860358267208774881
        ];
        uint256[2][2] memory b2 = [
            [
                18685503971201701637279255177672737459369364286579884138384195256096640826544,
                19517979001366784491262985007208187156868482446794264383959847800886523509877
            ],
            [
                12866135194889417072846904485239086915117156987867139218395654387586559304324,
                16475201747689810182851523453109345313415173394858409181213088485065940128783
            ]
        ];
        uint256[2] memory c2 = [
            5276319441217508855890249255054235161211918914051110197093775833187899960891,
            14386728697935258641600181574898746001129655942955900029040036823246860905307
        ];
        Groth16Proof memory proof2;
        proof2.a = a2;
        proof2.b = b2;
        proof2.c = c2;

        bytes32 syncCommitteeSSZ = bytes32(
            0xc1c5193ee38508e60af26d51b83e2c6ba6934fd00d2bb8cb36e95d5402fbfc94
        );
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(13340003662261458565835017692041308090002736850267009725732232370707087749826);

        LightClientRotate memory update = LightClientRotate(
            step,
            syncCommitteeSSZ,
            syncCommitteePoseidon,
            proof2
        );

        lc.rotate(update);
    }
}
