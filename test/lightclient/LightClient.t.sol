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
        for (uint256 i = FIXTURE_SLOT_START; i <= FIXTURE_SLOT_END; i++) {
            uint256 slot = i;

            string memory filename = string.concat("slot", Strings.toString(slot));
            string memory path =
                string.concat(root, "/test/lightclient/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                fixtures.push(abi.decode(parsed, (Fixture)));
            } catch {
                continue;
            }
        }

        vm.warp(9999999999999);
    }

    function test_SetUp() public view {
        require(fixtures.length > 0, "no fixtures found");
    }

    function test_Step() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
            LightClientStep memory step = convertToLightClientStep(fixture.step);

            lc.step(step);
        }
    }

    function test_Rotate() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
            LightClientRotate memory rotate =
                convertToLightClientRotate(fixture.step, fixture.rotate);

            lc.rotate(rotate);
        }
    }

    function test_RawStepProof() public {
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

    function test_RawRotateProof() public {
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
            for (uint256 j = 0; j < 32; j++) {
                inputs[32 - 1 - j] = syncCommitteeSSZNumeric % 2 ** 8;
                syncCommitteeSSZNumeric = syncCommitteeSSZNumeric / 2 ** 8;
            }
            uint256 finalizedHeaderRootNumeric = uint256(fixture.step.finalizedHeaderRoot);
            for (uint256 j = 0; j < 32; j++) {
                inputs[64 - j] = finalizedHeaderRootNumeric % 2 ** 8;
                finalizedHeaderRootNumeric = finalizedHeaderRootNumeric / 2 ** 8;
            }
            inputs[32] = uint256(SSZ.toLittleEndian(uint256(rotate.syncCommitteePoseidon)));

            require(lc.verifyProofRotate(a, b, c, inputs) == true);
        }
    }

    function test_RevertStep_WhenBadA() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.a[0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadB() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.b[0][0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadC() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.c[0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadAttestedSlot() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.attestedSlot = 0;

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadFinalizedSlot() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.finalizedSlot = 0;

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadParticipation() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.participation = Strings.toString(FINALITY_THRESHOLD - 1);

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadFinalizedHeaderRoot() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.finalizedHeaderRoot = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenBadExecutionStateRoot() public {
        Fixture memory fixture = fixtures[0];

        fixture.step.executionStateRoot = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenSlotBelowPeriodBoundary() public {
        Fixture memory fixture = fixtures[0];

        fixture.initial.syncCommitteePeriod++;

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertStep_WhenSlotAbovePeriodBoundary() public {
        Fixture memory fixture = fixtures[0];

        fixture.initial.syncCommitteePeriod--;

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientStep memory step = convertToLightClientStep(fixture.step);

        vm.expectRevert();
        lc.step(step);
    }

    function test_RevertRotate_WhenBadA() public {
        Fixture memory fixture = fixtures[0];

        fixture.rotate.a[0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        vm.expectRevert();
        lc.rotate(rotate);
    }

    function test_RevertRotate_WhenBadB() public {
        Fixture memory fixture = fixtures[0];

        fixture.rotate.b[0][0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        vm.expectRevert();
        lc.rotate(rotate);
    }

    function test_RevertRotate_WhenBadC() public {
        Fixture memory fixture = fixtures[0];

        fixture.rotate.c[0] = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        vm.expectRevert();
        lc.rotate(rotate);
    }

    function test_RevertRotate_WhenBadSyncCommitteeSSZ() public {
        Fixture memory fixture = fixtures[0];

        fixture.rotate.syncCommitteeSSZ = 0;

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        vm.expectRevert();
        lc.rotate(rotate);
    }

    function test_RevertRotate_WhenBadSyncCommitteePoseidon() public {
        Fixture memory fixture = fixtures[0];

        fixture.rotate.syncCommitteePoseidon = "0";

        LightClient lc = newLightClient(fixture.initial, SOURCE_CHAIN_ID, FINALITY_THRESHOLD);
        LightClientRotate memory rotate = convertToLightClientRotate(fixture.step, fixture.rotate);

        vm.expectRevert();
        lc.rotate(rotate);
    }
}
