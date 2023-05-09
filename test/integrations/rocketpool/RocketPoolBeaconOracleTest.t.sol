pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {RocketPoolBeaconOracle} from "external/integrations/rocketpool/RocketPoolBeaconOracle.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

import {LightClientMock} from "src/lightclient/LightClientMock.sol";

struct ValidatorFixture {
    uint64 activationEligibilityEpoch;
    uint64 activationEpoch;
    bytes32[] balanceProof;
    bytes32 beaconStateRoot;
    bytes32[] beaconStateRootProof;
    bytes32 blockHeaderRoot;
    bytes32 combinedBalance;
    uint64 effectiveBalance;
    uint64 exitEpoch;
    bytes32 pubkey;
    uint64 slashed;
    uint256 slot;
    uint256 validatorIndex;
    bytes32[] validatorProof;
    bytes32 validatorRoot;
    uint64 withdrawableEpoch;
    bytes32 withdrawalCredentials;
}

contract TestErrors {
    error InvalidBalanceProof(uint256 validatorIndex);
    error InvalidBeaconStateRootProof();
    error InvalidValidatorProof(uint256 validatorIndex);
    error InvalidCompleteValidatorProof(uint256 validatorIndex);
    error InvalidLightClientAddress();
}

contract TestEvents {
    event BeaconOracleUpdate(uint256 validatorIndex);
}

contract RocketPoolBeaconOracleTest is Test, TestEvents, TestErrors {
    uint32 constant SOURCE_CHAIN_ID = 1;
    uint16 constant FINALITY_THRESHOLD = 350;

    address public oracleOperator;
    ValidatorFixture fixture;
    RocketPoolBeaconOracle oracle;
    BeaconOracleHelper.Validator validator;

    function setUp() public {
        // read all fixtures from entire directory

        LightClientMock lightClient = new LightClientMock();

        oracleOperator = makeAddr("operator");

        oracle = new RocketPoolBeaconOracle(address(lightClient));

        string memory root = vm.projectRoot();
        string memory filename = "rocketpool_6308974";
        string memory path =
            string.concat(root, "/test/integrations/rocketpool/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);

        bytes memory parsed = vm.parseJson(file);

        fixture = abi.decode(parsed, (ValidatorFixture));

        validator = BeaconOracleHelper.Validator(
            fixture.pubkey,
            fixture.withdrawalCredentials,
            fixture.effectiveBalance,
            fixture.slashed == 1,
            fixture.activationEligibilityEpoch,
            fixture.activationEpoch,
            fixture.exitEpoch,
            fixture.withdrawableEpoch
        );

        lightClient.setHeader(fixture.slot, fixture.blockHeaderRoot);
    }

    function test_ProveCompleteValidator() public {
        BeaconOracleHelper.BeaconStateRootProofInfo memory beaconStateRootProofInfo =
        BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: fixture.slot,
            beaconStateRoot: fixture.beaconStateRoot,
            beaconStateRootProof: fixture.beaconStateRootProof
        });

        BeaconOracleHelper.ValidatorProofInfo memory validatorProofInfo = BeaconOracleHelper
            .ValidatorProofInfo({
            validatorIndex: fixture.validatorIndex,
            validatorRoot: fixture.validatorRoot,
            validatorProof: fixture.validatorProof
        });
        oracle.proveValidatorRootFromFields(
            beaconStateRootProofInfo,
            validatorProofInfo,
            validator,
            fixture.balanceProof,
            fixture.combinedBalance
        );

        BeaconOracleHelper.ValidatorStatus memory storedValidator =
            oracle.getValidator(fixture.validatorIndex);
        assertEq(storedValidator.validator.pubkeyHash, fixture.pubkey);
    }

    function test_RevertProveValidator() public {
        BeaconOracleHelper.BeaconStateRootProofInfo memory beaconStateRootProofInfo =
        BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: fixture.slot,
            beaconStateRoot: fixture.beaconStateRoot,
            beaconStateRootProof: fixture.beaconStateRootProof
        });

        BeaconOracleHelper.ValidatorProofInfo memory validatorProofInfo = BeaconOracleHelper
            .ValidatorProofInfo({
            validatorIndex: fixture.validatorIndex,
            validatorRoot: fixture.validatorRoot,
            validatorProof: fixture.validatorProof
        });
        // Invalid activation epoch
        validator.activationEpoch = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCompleteValidatorProof.selector, validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorRootFromFields(
            beaconStateRootProofInfo,
            validatorProofInfo,
            validator,
            fixture.balanceProof,
            fixture.combinedBalance
        );
    }
}
