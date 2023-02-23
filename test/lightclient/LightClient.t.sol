pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";

contract LightClientTest is Test, LightClientFixture {
    uint32 constant SOURCE_CHAIN_ID = 1;
    uint16 constant FINALITY_THRESHOLD = 350;

    function setUp() public {
        vm.warp(9999999999999);
    }

    function testStep() public {
        Fixture memory fixture = parseFixture("lcUpdate");

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        lc.step(step);
    }

    function testRotate() public {
        Fixture memory fixture = parseFixture("lcUpdate");

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        lc.rotate(rotate);
    }

    function testRawProof() public {
        Fixture memory fixture = LightClientFixture.parseFixture("lcUpdate");

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);

        uint256[2] memory a = [strToUint(fixture.step.a[0]), strToUint(fixture.step.a[1])];
        uint256[2][2] memory b = [
            [strToUint(fixture.step.b[0][1]), strToUint(fixture.step.b[0][0])],
            [strToUint(fixture.step.b[1][1]), strToUint(fixture.step.b[1][0])]
        ];
        uint256[2] memory c = [strToUint(fixture.step.c[0]), strToUint(fixture.step.c[1])];
        uint256[1] memory inputs = [strToUint(fixture.step.inputs[0])];

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
}
