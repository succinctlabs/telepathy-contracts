pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract LightClientTest is Test, LightClientFixture {
    uint32 constant SOURCE_CHAIN_ID = 1;
    uint16 constant FINALITY_THRESHOLD = 350;

    uint256 constant FIXTURE_SLOT_START = 5043198;
    uint256 constant FIXTURE_SLOT_END = 5053982;

    Fixture[] fixtures;

    function setUp() public {
        // read all fixtures from entire directory
        string memory root = vm.projectRoot();
        for (uint256 i = 0; i < FIXTURE_SLOT_END - FIXTURE_SLOT_START; i++) {
            uint256 slot = FIXTURE_SLOT_START + i;

            string memory filename = string.concat("slot", Strings.toString(slot));
            string memory path =
                string.concat(root, "/test/lightclient/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                Fixture memory params = abi.decode(parsed, (Fixture));
                fixtures.push(params);
            } catch {
                continue;
            }
        }

        vm.warp(9999999999999);
    }

    function testSetup() public view {
        require(fixtures.length > 0, "no fixtures found");
    }

    function testStep() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
            LightClientStep memory step = convertToLightClientStep(fixture.step);

            lc.step(step);
        }
    }

    function testRotate() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
            LightClientRotate memory rotate =
                convertToLightClientRotate(fixture.step, fixture.rotate);

            lc.rotate(rotate);
        }
    }

    function testRawStepProof() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

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
    }

    function testRawRotateProof() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);

            uint256[2] memory a = [strToUint(fixture.rotate.a[0]), strToUint(fixture.rotate.a[1])];
            uint256[2][2] memory b = [
                [strToUint(fixture.rotate.b[0][1]), strToUint(fixture.rotate.b[0][0])],
                [strToUint(fixture.rotate.b[1][1]), strToUint(fixture.rotate.b[1][0])]
            ];
            uint256[2] memory c = [strToUint(fixture.rotate.c[0]), strToUint(fixture.rotate.c[1])];

            LightClientRotate memory rotate =
                convertToLightClientRotate(fixture.step, fixture.rotate);

            uint256[65] memory inputs;
            uint256 syncCommitteeSSZNumeric = uint256(rotate.syncCommitteeSSZ);
            for (uint256 i = 0; i < 32; i++) {
                inputs[32 - 1 - i] = syncCommitteeSSZNumeric % 2 ** 8;
                syncCommitteeSSZNumeric = syncCommitteeSSZNumeric / 2 ** 8;
            }
            uint256 finalizedHeaderRootNumeric = uint256(fixture.step.finalizedHeaderRoot);
            for (uint256 i = 0; i < 32; i++) {
                inputs[64 - i] = finalizedHeaderRootNumeric % 2 ** 8;
                finalizedHeaderRootNumeric = finalizedHeaderRootNumeric / 2 ** 8;
            }
            inputs[32] = uint256(SSZ.toLittleEndian(uint256(rotate.syncCommitteePoseidon)));

            require(lc.verifyProofRotate(a, b, c, inputs) == true);
        }
    }
}
