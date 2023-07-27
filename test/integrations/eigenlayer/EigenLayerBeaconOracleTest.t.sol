pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";
import {EigenLayerBeaconOracle} from "external/integrations/eigenlayer/EigenLayerBeaconOracle.sol";
import {EigenLayerBeaconOracleProxy} from
    "external/integrations/eigenlayer/EigenLayerBeaconOracleProxy.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

import {LightClientMock} from "src/lightclient/LightClientMock.sol";

struct BeaconOracleUpdateFixture {
    bytes32 sourceHeaderRoot;
    uint256 sourceSlot;
    bytes32 sourceStateRoot;
    bytes32[] sourceStateRootProof;
    bytes32 targetHeaderRoot;
    bytes32[] targetHeaderRootProof;
    uint256 targetSlot;
    uint256 targetTimestamp;
    bytes32[] targetTimestampProof;
}

contract TestErrors {
    error InvalidBlockNumberProof();
    error InvalidBeaconStateRootProof();
    error InvalidUpdater(address updater);
    error SlotNumberTooLow();
}

contract TestEvents {
    event BeaconStateOracleUpdate(uint256 slot, uint256 blockNumber, bytes32 stateRoot);
}

contract EigenLayerBeaconOracleTest is Test, TestEvents, TestErrors {
    uint32 constant SOURCE_CHAIN_ID = 1;
    uint16 constant FINALITY_THRESHOLD = 350;

    EigenLayerBeaconOracle oracle;
    address public oracleOperator;
    address public guardian;
    BeaconOracleUpdateFixture fixture1;
    BeaconOracleHelper.BeaconStateRootProofInfo beaconStateRootProofInfo1;
    BeaconOracleHelper.TargetBeaconBlockRootProofInfo targetBeaconBlockRootProofInfo1;
    BeaconOracleUpdateFixture fixture2;
    BeaconOracleHelper.BeaconStateRootProofInfo beaconStateRootProofInfo2;
    BeaconOracleHelper.TargetBeaconBlockRootProofInfo targetBeaconBlockRootProofInfo2;

    function isWhitelisted(address _oracleUpdater) public view returns (bool) {
        return oracle.whitelistedOracleUpdaters(_oracleUpdater);
    }

    function setUp() public {
        // Setup oracle operator and guardian.
        oracleOperator = makeAddr("operator");
        guardian = makeAddr("guardian");

        // Setup mock light client.
        LightClientMock lightClient = new LightClientMock();

        // Initialize beacon oracle.
        EigenLayerBeaconOracleProxy EigenLayerBeaconOracleImplementation =
            new EigenLayerBeaconOracleProxy();
        UUPSProxy proxy = new UUPSProxy(address(EigenLayerBeaconOracleImplementation), "");
        oracle = EigenLayerBeaconOracleProxy(address(proxy));
        EigenLayerBeaconOracleProxy(address(proxy)).initialize(
            address(lightClient), guardian, guardian, address(0)
        );

        // Set oracle operator.
        vm.prank(guardian);
        EigenLayerBeaconOracleProxy(address(proxy)).updateWhitelist(oracleOperator, true);

        // Load fixture.
        string memory root = vm.projectRoot();
        string memory filename = "eigenlayer1";
        string memory path =
            string.concat(root, "/test/integrations/eigenlayer/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        fixture1 = abi.decode(parsed, (BeaconOracleUpdateFixture));

        root = vm.projectRoot();
        filename = "eigenlayer2";
        path = string.concat(root, "/test/integrations/eigenlayer/fixtures/", filename, ".json");
        file = vm.readFile(path);
        parsed = vm.parseJson(file);
        fixture2 = abi.decode(parsed, (BeaconOracleUpdateFixture));

        // Set light client header.
        lightClient.setHeader(fixture1.sourceSlot, fixture1.sourceHeaderRoot);
        lightClient.setHeader(fixture2.sourceSlot, fixture2.sourceHeaderRoot);

        beaconStateRootProofInfo1 = BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: fixture1.sourceSlot,
            beaconStateRoot: fixture1.sourceStateRoot,
            beaconStateRootProof: fixture1.sourceStateRootProof
        });
        targetBeaconBlockRootProofInfo1 = BeaconOracleHelper.TargetBeaconBlockRootProofInfo({
            targetSlot: fixture1.targetSlot,
            targetBeaconBlockRoot: fixture1.targetHeaderRoot,
            targetBeaconBlockRootProof: fixture1.targetHeaderRootProof
        });
        beaconStateRootProofInfo2 = BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: fixture2.sourceSlot,
            beaconStateRoot: fixture2.sourceStateRoot,
            beaconStateRootProof: fixture2.sourceStateRootProof
        });
        targetBeaconBlockRootProofInfo2 = BeaconOracleHelper.TargetBeaconBlockRootProofInfo({
            targetSlot: fixture2.targetSlot,
            targetBeaconBlockRoot: fixture2.targetHeaderRoot,
            targetBeaconBlockRootProof: fixture2.targetHeaderRootProof
        });

        vm.warp(9999999999999);
    }

    function test_FulfillRequest() public {
        vm.prank(oracleOperator);
        // Check that event is emitted
        vm.expectEmit(true, true, true, true);
        emit BeaconStateOracleUpdate(
            fixture1.targetSlot, fixture1.targetTimestamp, fixture1.targetHeaderRoot
        );

        oracle.fulfillRequest(
            beaconStateRootProofInfo1,
            targetBeaconBlockRootProofInfo1,
            fixture1.targetTimestampProof,
            fixture1.targetTimestamp
        );

        bytes32 beaconBlockRoot = oracle.timestampToBlockRoot(fixture1.targetTimestamp);
        assertTrue(
            beaconBlockRoot == fixture1.targetHeaderRoot, "beacon state roots should be equal"
        );
    }

    function test_RevertFulfillRequestWhenNotWhitelisted() public {
        // Sender is not whitelisted
        address notOperator = makeAddr("0x456");

        bool value = isWhitelisted(notOperator);
        assertTrue(!value);

        vm.prank(notOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidUpdater.selector, notOperator));
        oracle.fulfillRequest(
            beaconStateRootProofInfo1,
            targetBeaconBlockRootProofInfo1,
            fixture1.targetTimestampProof,
            fixture1.targetTimestamp
        );
    }

    function test_RevertInvalidBlockNumberProof() public {
        vm.prank(oracleOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidBlockNumberProof.selector));
        oracle.fulfillRequest(
            beaconStateRootProofInfo1,
            targetBeaconBlockRootProofInfo1,
            fixture1.targetTimestampProof,
            fixture1.targetTimestamp + 1
        );
    }

    function test_RevertInvalidBeaconStateRootProof() public {
        vm.prank(oracleOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidBeaconStateRootProof.selector));
        beaconStateRootProofInfo1.beaconStateRoot = bytes32(0);
        oracle.fulfillRequest(
            beaconStateRootProofInfo1,
            targetBeaconBlockRootProofInfo1,
            fixture1.targetTimestampProof,
            fixture1.targetTimestamp
        );
    }
}
