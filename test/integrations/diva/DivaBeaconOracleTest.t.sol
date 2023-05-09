pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClient, LightClientStep, LightClientRotate} from "src/lightclient/LightClient.sol";
import {LightClientFixture} from "test/lightclient/LightClientFixture.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {DivaBeaconOracle} from "external/integrations/diva/DivaBeaconOracle.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

import {LightClientMock} from "src/lightclient/LightClientMock.sol";

struct DepositFixture {
    uint256 depositIndex;
    bytes32 headerRoot;
    bytes32 pubkeyHash;
    bytes32[] pubkeyProof;
    uint256 slot;
}

struct StatusFixture {
    uint64 activationEpoch;
    bytes32[] activationProof;
    bytes32 beaconStateRoot;
    bytes32[] beaconStateRootProof;
    bytes32 blockHeaderRoot;
    uint64 exitEpoch;
    bytes32[] exitProof;
    uint64 pendingEpoch;
    bytes32[] pendingProof;
    uint64 slashed;
    bytes32[] slashedProof;
    uint256 slot;
    uint256 validatorIndex;
    bytes32[] validatorProof;
    bytes32 validatorRoot;
    bytes32 withdrawalCredentials;
    bytes32[] withdrawalCredentialsProof;
}

struct BeaconOracleUpdateFixture {
    bytes32[] balanceProof;
    bytes32 beaconStateRoot;
    bytes32[] beaconStateRootProof;
    bytes32 combinedBalance;
    bytes32 headerRoot;
    uint256 slot;
    uint256 validatorBalance;
    uint256 validatorIndex;
    bytes32[] validatorProof;
    bytes32 validatorRoot;
    bytes32 withdrawalCredentials;
    bytes32[] withdrawalCredentialsProof;
}

contract TestErrors {
    error InvalidBeaconStateRootProof();

    error InvalidValidatorProof(uint256 validatorIndex);

    error InvalidDepositProof(bytes32 validatorPubkeyHash);
    error InvalidBalanceProof(uint256 validatorIndex);
    error InvalidValidatorFieldProof(
        BeaconOracleHelper.ValidatorField field, uint256 validatorIndex
    );
}

contract TestEvents {
    event BeaconOracleUpdate(uint256 validatorIndex);
}

contract DivaBeaconOracleTest is Test, TestEvents, TestErrors {
    uint32 constant SOURCE_CHAIN_ID = 1;
    uint16 constant FINALITY_THRESHOLD = 350;

    address public oracleOperator;
    BeaconOracleUpdateFixture fixture;
    DepositFixture depositFixture;
    StatusFixture statusFixture;
    DivaBeaconOracle oracle;

    function setUp() public {
        // read all fixtures from entire directory

        LightClientMock lightClient = new LightClientMock();

        oracleOperator = makeAddr("operator");

        oracle = new DivaBeaconOracle(address(lightClient));

        string memory root = vm.projectRoot();
        string memory filename = "diva_6250752";
        string memory path =
            string.concat(root, "/test/integrations/diva/fixtures/", filename, ".json");
        string memory file = vm.readFile(path);
        bytes memory parsed = vm.parseJson(file);
        fixture = abi.decode(parsed, (BeaconOracleUpdateFixture));

        filename = "diva_deposit_6308974";
        path = string.concat(root, "/test/integrations/diva/fixtures/", filename, ".json");
        file = vm.readFile(path);
        parsed = vm.parseJson(file);
        depositFixture = abi.decode(parsed, (DepositFixture));

        filename = "diva_status_6308974";
        path = string.concat(root, "/test/integrations/diva/fixtures/", filename, ".json");
        file = vm.readFile(path);
        parsed = vm.parseJson(file);
        statusFixture = abi.decode(parsed, (StatusFixture));

        lightClient.setHeader(fixture.slot, fixture.headerRoot);
        lightClient.setHeader(depositFixture.slot, depositFixture.headerRoot);
    }

    function test_ProveDeposit() public {
        oracle.proveDeposit(
            depositFixture.slot,
            depositFixture.pubkeyHash,
            depositFixture.depositIndex,
            depositFixture.pubkeyProof
        );

        uint256 slotDeposited = oracle.getDepositStatus(depositFixture.pubkeyHash);
        assertEq(slotDeposited, depositFixture.slot);
    }

    function test_ProveValidatorField() public {
        BeaconOracleHelper.BeaconStateRootProofInfo memory beaconStateRootProofInfo =
        BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: statusFixture.slot,
            beaconStateRoot: statusFixture.beaconStateRoot,
            beaconStateRootProof: statusFixture.beaconStateRootProof
        });

        BeaconOracleHelper.ValidatorProofInfo memory validatorProofInfo = BeaconOracleHelper
            .ValidatorProofInfo({
            validatorIndex: statusFixture.validatorIndex,
            validatorRoot: statusFixture.validatorRoot,
            validatorProof: statusFixture.validatorProof
        });

        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            statusFixture.withdrawalCredentials,
            statusFixture.withdrawalCredentialsProof,
            BeaconOracleHelper.ValidatorField.WithdrawalCredentials
        );

        bytes32 withdrawalCredentials =
            oracle.getWithdrawalCredentials(validatorProofInfo.validatorIndex);

        assertEq(withdrawalCredentials, statusFixture.withdrawalCredentials);

        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            statusFixture.pendingEpoch,
            statusFixture.pendingProof,
            BeaconOracleHelper.ValidatorField.ActivationEligibilityEpoch
        );
        uint256 pendingEpoch = oracle.getActivationEligibilityEpoch(statusFixture.validatorIndex);
        assertEq(pendingEpoch, statusFixture.pendingEpoch);

        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            statusFixture.activationEpoch,
            statusFixture.activationProof,
            BeaconOracleHelper.ValidatorField.ActivationEpoch
        );
        uint256 activationEpoch = oracle.getActivationEpoch(statusFixture.validatorIndex);
        assertEq(activationEpoch, statusFixture.activationEpoch);

        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            statusFixture.exitEpoch,
            statusFixture.exitProof,
            BeaconOracleHelper.ValidatorField.ExitEpoch
        );
        uint256 exitEpoch = oracle.getExitEpoch(statusFixture.validatorIndex);
        assertEq(exitEpoch, statusFixture.exitEpoch);

        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            statusFixture.slashed,
            statusFixture.slashedProof,
            BeaconOracleHelper.ValidatorField.Slashed
        );
        bool slashed = oracle.getSlashed(statusFixture.validatorIndex);
        assertEq(slashed, statusFixture.slashed == 1);
    }

    function test_ProveValidatorBalance() public {
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

        oracle.proveValidatorBalance(
            beaconStateRootProofInfo,
            validatorProofInfo,
            fixture.combinedBalance,
            fixture.balanceProof
        );

        uint256 balance = oracle.getBalance(validatorProofInfo.validatorIndex);
        assertEq(balance, fixture.validatorBalance);
    }

    function test_RevertInProveDeposit() public {
        vm.expectRevert(
            abi.encodeWithSelector(InvalidDepositProof.selector, depositFixture.pubkeyHash)
        );
        oracle.proveDeposit(
            depositFixture.slot,
            depositFixture.pubkeyHash,
            // Incorrect deposit index
            16,
            depositFixture.pubkeyProof
        );
    }

    function test_RevertInProveValidatorBalance() public {
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

        vm.expectRevert(
            abi.encodeWithSelector(InvalidBalanceProof.selector, validatorProofInfo.validatorIndex)
        );
        oracle.proveValidatorBalance(
            // Incorrect combined balance
            beaconStateRootProofInfo,
            validatorProofInfo,
            "0x0",
            fixture.balanceProof
        );
    }

    function test_RevertsInProveValidatorStatus() public {
        BeaconOracleHelper.BeaconStateRootProofInfo memory beaconStateRootProofInfo =
        BeaconOracleHelper.BeaconStateRootProofInfo({
            slot: statusFixture.slot,
            beaconStateRoot: statusFixture.beaconStateRoot,
            beaconStateRootProof: statusFixture.beaconStateRootProof
        });

        BeaconOracleHelper.ValidatorProofInfo memory validatorProofInfo = BeaconOracleHelper
            .ValidatorProofInfo({
            validatorIndex: statusFixture.validatorIndex,
            validatorRoot: statusFixture.validatorRoot,
            validatorProof: statusFixture.validatorProof
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidValidatorFieldProof.selector,
                BeaconOracleHelper.ValidatorField.WithdrawalCredentials,
                validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            // Incorrect withdrawal credentials
            "0x0",
            statusFixture.withdrawalCredentialsProof,
            BeaconOracleHelper.ValidatorField.WithdrawalCredentials
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidValidatorFieldProof.selector,
                BeaconOracleHelper.ValidatorField.ActivationEligibilityEpoch,
                validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            // Incorrect leaf
            uint64(0),
            statusFixture.pendingProof,
            BeaconOracleHelper.ValidatorField.ActivationEligibilityEpoch
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidValidatorFieldProof.selector,
                BeaconOracleHelper.ValidatorField.ActivationEpoch,
                validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            // Incorrect leaf
            uint64(0),
            statusFixture.activationProof,
            BeaconOracleHelper.ValidatorField.ActivationEpoch
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidValidatorFieldProof.selector,
                BeaconOracleHelper.ValidatorField.ExitEpoch,
                validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo,
            // Incorrect leaf
            uint64(0),
            statusFixture.exitProof,
            BeaconOracleHelper.ValidatorField.ExitEpoch
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidValidatorFieldProof.selector,
                BeaconOracleHelper.ValidatorField.Slashed,
                validatorProofInfo.validatorIndex
            )
        );
        oracle.proveValidatorField(
            beaconStateRootProofInfo,
            validatorProofInfo, // Validator IS slashed
            uint64(0),
            statusFixture.slashedProof,
            BeaconOracleHelper.ValidatorField.Slashed
        );
    }
}
