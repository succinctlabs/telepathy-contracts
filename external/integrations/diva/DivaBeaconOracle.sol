pragma solidity 0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";

contract DivaBeaconOracle {
    ILightClient lightclient;

    event BeaconOracleUpdate(uint256 validatorIndex);

    error InvalidLightClientAddress();

    constructor(address _lightClient) {
        if (_lightClient == address(0)) {
            revert InvalidLightClientAddress();
        }
        lightclient = ILightClient(_lightClient);
    }

    /// @notice Mapping from SHA-256 hash of padded pubkey to the slot of the latest proved deposit
    mapping(bytes32 => uint256) public depositedSlots;
    /// @notice Mapping from validator index to latest proved withdrawal amount
    mapping(uint256 => uint256) public withdrawalAmounts;
    /// @notice Mapping from validator index to latest proved balance
    mapping(uint256 => uint256) public validatorBalances;
    /// @notice Mapping from validator index to validator struct
    mapping(uint256 => BeaconOracleHelper.Validator) public validatorState;

    /// @notice Prove pubkey against deposit in beacon block
    function proveDeposit(
        uint256 _slot,
        bytes32 _pubkeyHash,
        // Index of deposit in deposit tree (MAX_LENGTH = 16)
        uint256 _depositIndex,
        bytes32[] calldata _depositedPubkeyProof
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_slot);

        BeaconOracleHelper._verifyValidatorDeposited(
            _depositIndex, _pubkeyHash, _depositedPubkeyProof, blockHeaderRoot
        );

        depositedSlots[_pubkeyHash] = _slot;
    }

    /// @notice Prove pubkey against deposit in beacon block
    function proveWithdrawal(
        uint256 _slot,
        uint256 _validatorIndex,
        uint256 _amount,
        // Index of deposit in deposit tree (MAX_LENGTH = 16)
        uint256 _withdrawalIndex,
        bytes32[] memory _withdrawalValidatorIndexProof,
        bytes32[] memory _withdrawalAmountProof
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_slot);

        BeaconOracleHelper._verifyValidatorWithdrawal(
                _withdrawalIndex, _validatorIndex, _amount, _withdrawalValidatorIndexProof, _withdrawalAmountProof, blockHeaderRoot
            );

        withdrawalAmounts[_validatorIndex] = _amount;
    }

    /// @notice Prove pubkey, withdrawal credentials
    function proveValidatorField(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconOracleHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Prove fields that are bytes32
        bytes32 _validatorFieldLeaf,
        bytes32[] calldata _validatorFieldProof,
        BeaconOracleHelper.ValidatorField _field
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_beaconStateRootProofInfo.slot);

        BeaconOracleHelper._verifyValidatorRoot(
            _beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot
        );
        BeaconOracleHelper._verifyValidatorField(
            _validatorProofInfo.validatorRoot,
            _validatorProofInfo.validatorIndex,
            _validatorFieldLeaf,
            _validatorFieldProof,
            _field
        );
        BeaconOracleHelper.Validator storage validator =
            validatorState[_validatorProofInfo.validatorIndex];
        if (_field == BeaconOracleHelper.ValidatorField.Pubkey) {
            validator.pubkeyHash = _validatorFieldLeaf;
        } else if (_field == BeaconOracleHelper.ValidatorField.WithdrawalCredentials) {
            validator.withdrawalCredentials = _validatorFieldLeaf;
        }
    }

    /// @notice Prove slashed & status epochs
    function proveValidatorField(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconOracleHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Prove fields that are uint256 or bool
        uint64 _validatorFieldLeaf,
        bytes32[] calldata _validatorFieldProof,
        BeaconOracleHelper.ValidatorField _field
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_beaconStateRootProofInfo.slot);

        BeaconOracleHelper._verifyValidatorRoot(
            _beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot
        );

        BeaconOracleHelper._verifyValidatorField(
            _validatorProofInfo.validatorRoot,
            _validatorProofInfo.validatorIndex,
            SSZ.toLittleEndian(_validatorFieldLeaf),
            _validatorFieldProof,
            _field
        );

        BeaconOracleHelper.Validator memory validator =
            validatorState[_validatorProofInfo.validatorIndex];
        if (_field == BeaconOracleHelper.ValidatorField.Slashed) {
            validator.slashed = _validatorFieldLeaf == 1;
        } else if (_field == BeaconOracleHelper.ValidatorField.ActivationEligibilityEpoch) {
            validator.activationEligibilityEpoch = _validatorFieldLeaf;
        } else if (_field == BeaconOracleHelper.ValidatorField.ActivationEpoch) {
            validator.activationEpoch = _validatorFieldLeaf;
        } else if (_field == BeaconOracleHelper.ValidatorField.ExitEpoch) {
            validator.exitEpoch = _validatorFieldLeaf;
        } else if (_field == BeaconOracleHelper.ValidatorField.WithdrawableEpoch) {
            validator.withdrawableEpoch = _validatorFieldLeaf;
        }
        validatorState[_validatorProofInfo.validatorIndex] = validator;
    }

    /// @notice Proves the balance of a validator against balances array
    function proveValidatorBalance(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconOracleHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Combined balances of 4 validators packed into same gindex
        bytes32 _combinedBalance,
        bytes32[] calldata _balanceProof
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_beaconStateRootProofInfo.slot);

        BeaconOracleHelper._verifyValidatorRoot(
            _beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot
        );

        validatorBalances[_validatorProofInfo.validatorIndex] = BeaconOracleHelper
            ._proveValidatorBalance(
            _validatorProofInfo.validatorIndex,
            _beaconStateRootProofInfo.beaconStateRoot,
            _combinedBalance,
            _balanceProof
        );

        emit BeaconOracleUpdate(_validatorProofInfo.validatorIndex);
    }

    function getWithdrawalCredentials(uint256 _validatorIndex) external view returns (bytes32) {
        return validatorState[_validatorIndex].withdrawalCredentials;
    }

    function getPubkey(uint256 _validatorIndex) external view returns (bytes32) {
        return validatorState[_validatorIndex].pubkeyHash;
    }

    function getSlashed(uint256 _validatorIndex) external view returns (bool) {
        return validatorState[_validatorIndex].slashed;
    }

    function getActivationEligibilityEpoch(uint256 _validatorIndex)
        external
        view
        returns (uint256)
    {
        return validatorState[_validatorIndex].activationEligibilityEpoch;
    }

    function getActivationEpoch(uint256 _validatorIndex) external view returns (uint64) {
        return validatorState[_validatorIndex].activationEpoch;
    }

    function getExitEpoch(uint256 _validatorIndex) external view returns (uint64) {
        return validatorState[_validatorIndex].exitEpoch;
    }

    function getWithdrawableEpoch(uint256 _validatorIndex) external view returns (uint64) {
        return validatorState[_validatorIndex].withdrawableEpoch;
    }

    function getBalance(uint256 _validatorIndex) external view returns (uint256) {
        return validatorBalances[_validatorIndex];
    }

    function getDepositStatus(bytes32 _validatorPubkeyHash) external view returns (uint256) {
        return depositedSlots[_validatorPubkeyHash];
    }

    function getWithdrawalAmount(uint256 _validatorIndex) external view returns (uint256) {
        return withdrawalAmounts[_validatorIndex];
    }
}