pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {EigenLayerBeaconOracle} from "src/integrations/eigenlayer/EigenLayerBeaconOracle.sol";
import {EigenLayerBeaconOracleProxy} from
    "src/integrations/eigenlayer/EigenLayerBeaconOracleProxy.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

import {LightClientMock} from "src/lightclient/LightClientMock.sol";

struct BeaconOracleUpdateFixture {
    bytes32 beaconStateRoot;
    bytes32[] beaconStateRootProof;
    uint256 blockNumber;
    bytes32[] blockNumberProof;
    bytes32 headerRoot;
    uint256 slot;
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
    BeaconOracleUpdateFixture fixture;
    BeaconOracleUpdateFixture fixture2;

    function isWhitelisted(address _oracleUpdater) public view returns (bool) {
        return oracle.whitelistedOracleUpdaters(_oracleUpdater);
    }

    function setUp() public {
        // read all fixtures from entire directory

        LightClientMock lightClient = new LightClientMock();

        oracleOperator = makeAddr("operator");
        guardian = makeAddr("guardian");

        EigenLayerBeaconOracleProxy EigenLayerBeaconOracleImplementation =
            new EigenLayerBeaconOracleProxy();

        UUPSProxy proxy = new UUPSProxy(address(EigenLayerBeaconOracleImplementation), "");

        oracle = EigenLayerBeaconOracleProxy(address(proxy));
        EigenLayerBeaconOracleProxy(address(proxy)).initialize(
            address(lightClient), guardian, guardian
        );

        vm.prank(guardian);
        EigenLayerBeaconOracleProxy(address(proxy)).updateWhitelist(oracleOperator, true);

        string memory root = vm.projectRoot();
        string memory filename = "valid_6211232";
        string memory path = string.concat(root, "/test/integrations/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        fixture = abi.decode(parsed, (BeaconOracleUpdateFixture));

        lightClient.setHeader(fixture.slot, fixture.headerRoot);

        string memory filename2 = "valid_6250752";
        string memory path2 =
            string.concat(root, "/test/integrations/fixtures/", filename2, ".json");
        string memory file2 = vm.readFile(path2);
        bytes memory parsed2 = vm.parseJson(file2);
        fixture2 = abi.decode(parsed2, (BeaconOracleUpdateFixture));

        lightClient.setHeader(fixture2.slot, fixture2.headerRoot);

        vm.warp(9999999999999);
    }

    function test_FulfillRequest() public {
        vm.prank(oracleOperator);
        // Check that event is emitted
        vm.expectEmit(true, true, true, true);
        emit BeaconStateOracleUpdate(fixture.slot, fixture.blockNumber, fixture.beaconStateRoot);

        oracle.fulfillRequest(
            fixture.slot,
            fixture.blockNumber,
            fixture.blockNumberProof,
            fixture.beaconStateRoot,
            fixture.beaconStateRootProof
        );

        bytes32 beaconStateRoot = oracle.blockNumberToStateRoot(fixture.blockNumber);

        assertTrue(beaconStateRoot == fixture.beaconStateRoot, "beacon state roots should be equal");
    }

    function test_RevertFulfillRequestWhenNotWhitelisted() public {
        // Sender is not whitelisted
        address notOperator = makeAddr("0x456");

        bool value = isWhitelisted(notOperator);
        assertTrue(!value);

        vm.prank(notOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidUpdater.selector, notOperator));
        oracle.fulfillRequest(
            fixture.slot,
            fixture.blockNumber,
            fixture.blockNumberProof,
            fixture.beaconStateRoot,
            fixture.beaconStateRootProof
        );
    }

    function test_RevertSlotTooLow() public {
        vm.prank(oracleOperator);
        oracle.fulfillRequest(
            fixture2.slot,
            fixture2.blockNumber,
            fixture2.blockNumberProof,
            fixture2.beaconStateRoot,
            fixture2.beaconStateRootProof
        );

        vm.prank(oracleOperator);
        // Slot number is lower than previous slot
        vm.expectRevert(abi.encodeWithSelector(SlotNumberTooLow.selector));
        oracle.fulfillRequest(
            fixture.slot,
            fixture.blockNumber,
            fixture.blockNumberProof,
            fixture.beaconStateRoot,
            fixture.beaconStateRootProof
        );
    }

    function test_RevertInvalidBlockNumberProof() public {
        vm.prank(oracleOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidBlockNumberProof.selector));
        oracle.fulfillRequest(
            fixture.slot,
            fixture.blockNumber,
            // Invalid blockNumberProof
            fixture2.blockNumberProof,
            fixture.beaconStateRoot,
            fixture.beaconStateRootProof
        );
    }

    function test_RevertInvalidBeaconStateRootProof() public {
        vm.prank(oracleOperator);
        vm.expectRevert(abi.encodeWithSelector(InvalidBeaconStateRootProof.selector));
        oracle.fulfillRequest(
            fixture.slot,
            fixture.blockNumber,
            fixture.blockNumberProof,
            fixture.beaconStateRoot,
            // Invalid beaconStateRootProof
            fixture2.beaconStateRootProof
        );
    }
}
