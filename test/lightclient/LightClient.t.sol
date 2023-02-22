pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {
    LightClient,
    Groth16Proof,
    LightClientStep,
    LightClientRotate
} from "src/lightclient/LightClient.sol";

contract LightClientTest is Test {
    LightClient lc;

    function setUp() public {
        bytes32 genesisValidatorsRoot =
            bytes32(0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb);
        uint256 genesisTime = 1616508000;
        uint256 secondsPerSlot = 12;
        uint256 slotsPerPeriod = 8192;
        uint256 syncCommitteePeriod = 610;
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(
            13019491976711767701293683625907699777932850451357438941446798435975830292102
        );

        lc = new LightClient(
            genesisValidatorsRoot,
            genesisTime,
            secondsPerSlot,
            slotsPerPeriod,
            syncCommitteePeriod,
            syncCommitteePoseidon,
            1,
            350
        );

        vm.warp(9999999999999);
    }

    function testProof() public view {
        uint256[2] memory a = [
            11630589312070769396465720534428344760247404875328900854267347789818433209185,
            11790328228568274004079011370260388066456190172972635717624831943081779186743
        ];
        uint256[2][2] memory b = [
            [
                5624997824066270682100895320124330016996856792065993179123759422195960118812,
                11793579149009431837916473757232323989362855752395220240450104958076427570665
            ],
            [
                19855567624288519382801539090338558208306002798522314415056212766111994903376,
                2360159037609775520540128605233318375955660205289227802825475729636460541235
            ]
        ];
        uint256[2] memory c = [
            21827364402153409025957834894675063273772194188963869841338636348537883370062,
            15953979659618274791467615165304296356048513021445980730071876453265513747304
        ];
        uint256[1] memory inputs =
            [879146123280141673197263251119129573654633325556131278157141281457854666715];
        require(lc.verifyProofStep(a, b, c, inputs) == true);
    }

    function testPublicInputsRoot() public view {
        bytes32 finalizedHeaderRoot =
            bytes32(0xfad3ba4e53d01e392d6c191294d6191f51d769666bae2869ca3d2ac962c2cace);
        bytes32 finalizedSlotLE = SSZ.toLittleEndian(4359712);
        bytes32 participationLE = SSZ.toLittleEndian(426);
        bytes32 executionStateRoot =
            bytes32(0x6fc15b26deadfb27063a8ee1147dd66e060ddea457a7b9bb4473199dc352ab47);
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(
            7032059424740925146199071046477651269705772793323287102921912953216115444414
        );

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
        uint256 attestedSlot = 4999199;
        uint256 finalizedSlot = 4999103;
        uint256 participation = 396;
        bytes32 finalizedHeaderRoot =
            bytes32(0x3465a8518ae00557edda3091a5bb5815406b6725cb53e5720159bd64100dbad8);
        bytes32 executionStateRoot =
            bytes32(0x65f354d62a6d401cd82d86f62fe4d860fe124bb3380611e1eab8a761fa2077ff);

        uint256[2] memory a = [
            11630589312070769396465720534428344760247404875328900854267347789818433209185,
            11790328228568274004079011370260388066456190172972635717624831943081779186743
        ];
        uint256[2][2] memory b = [
            [
                5624997824066270682100895320124330016996856792065993179123759422195960118812,
                11793579149009431837916473757232323989362855752395220240450104958076427570665
            ],
            [
                19855567624288519382801539090338558208306002798522314415056212766111994903376,
                2360159037609775520540128605233318375955660205289227802825475729636460541235
            ]
        ];
        uint256[2] memory c = [
            21827364402153409025957834894675063273772194188963869841338636348537883370062,
            15953979659618274791467615165304296356048513021445980730071876453265513747304
        ];

        Groth16Proof memory proof;
        proof.a = a;
        proof.b = b;
        proof.c = c;

        LightClientStep memory update = LightClientStep(
            attestedSlot,
            finalizedSlot,
            participation,
            finalizedHeaderRoot,
            executionStateRoot,
            proof
        );

        lc.step(update);
    }

    function testRotate() public {
        uint256 attestedSlot = 4999199;
        uint256 finalizedSlot = 4999103;
        uint256 participation = 396;
        bytes32 finalizedHeaderRoot =
            bytes32(0x3465a8518ae00557edda3091a5bb5815406b6725cb53e5720159bd64100dbad8);
        bytes32 executionStateRoot =
            bytes32(0x65f354d62a6d401cd82d86f62fe4d860fe124bb3380611e1eab8a761fa2077ff);

        uint256[2] memory a = [
            11630589312070769396465720534428344760247404875328900854267347789818433209185,
            11790328228568274004079011370260388066456190172972635717624831943081779186743
        ];
        uint256[2][2] memory b = [
            [
                5624997824066270682100895320124330016996856792065993179123759422195960118812,
                11793579149009431837916473757232323989362855752395220240450104958076427570665
            ],
            [
                19855567624288519382801539090338558208306002798522314415056212766111994903376,
                2360159037609775520540128605233318375955660205289227802825475729636460541235
            ]
        ];
        uint256[2] memory c = [
            21827364402153409025957834894675063273772194188963869841338636348537883370062,
            15953979659618274791467615165304296356048513021445980730071876453265513747304
        ];

        Groth16Proof memory proof;
        proof.a = a;
        proof.b = b;
        proof.c = c;

        LightClientStep memory step = LightClientStep(
            attestedSlot,
            finalizedSlot,
            participation,
            finalizedHeaderRoot,
            executionStateRoot,
            proof
        );

        uint256[2] memory a2 = [
            9390511395604537969292524093504636703588117920617926267790783301590100068494,
            20913833680709932821014208177101226008781738920228730773364880566388123643580
        ];
        uint256[2][2] memory b2 = [
            [
                14443058885197990538349302180251674865496959612493881393349447510656954122092,
                11362461321687335502108166993424022365478961467277276821248099975500569570008
            ],
            [
                2506910838470716762915933730531714590048223360462727731683450704200494018620,
                817410398284862557720261800038310678425863966289025004569806002003600121149
            ]
        ];
        uint256[2] memory c2 = [
            20314396056409460029716564648051295257010795083450773780618429506605946921664,
            19137897936051421051773515844340538008009516285280881313265593284128402034592
        ];
        Groth16Proof memory proof2;
        proof2.a = a2;
        proof2.b = b2;
        proof2.c = c2;

        bytes32 syncCommitteeSSZ =
            bytes32(0x223c6f16315d21b7a8d096633efc6262f430fc8397fa5b3f091ed908a0fae0e4);
        bytes32 syncCommitteePoseidon = SSZ.toLittleEndian(
            18802460813909764763944139774824413921538051655330664562178748111458630931473
        );

        LightClientRotate memory update =
            LightClientRotate(step, syncCommitteeSSZ, syncCommitteePoseidon, proof2);

        lc.rotate(update);
    }
}
