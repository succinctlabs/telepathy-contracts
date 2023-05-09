pragma solidity 0.8.16;

import {SSZ} from "src/libraries/SimpleSerialize.sol";

library BeaconOracleHelper {
    /// @notice Beacon block constants
    uint256 internal constant BEACON_STATE_ROOT_INDEX = 11;
    uint256 internal constant BASE_DEPOSIT_INDEX = 6336;
    uint256 internal constant EXECUTION_PAYLOAD_BLOCK_NUMBER_INDEX = 3222;

    /// @notice Validator proof constants
    uint256 internal constant BASE_VALIDATOR_INDEX = 94557999988736;
    uint256 internal constant VALIDATOR_FIELDS_LENGTH = 8;
    uint256 internal constant PUBKEY_INDEX = 0;
    uint256 internal constant WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant EFFECTIVE_BALANCE_INDEX = 2;
    uint256 internal constant SLASHED_INDEX = 3;
    uint256 internal constant ACTIVATION_ELIGIBILITY_EPOCH_INDEX = 4;
    uint256 internal constant ACTIVATION_EPOCH_INDEX = 5;
    uint256 internal constant EXIT_EPOCH_INDEX = 6;
    uint256 internal constant WITHDRAWABLE_EPOCH_INDEX = 7;

    /// @notice Balance constants
    uint256 internal constant BASE_BALANCE_INDEX = 24189255811072;

    /// @notice Errors
    // Beacon State Proof Errors
    error InvalidValidatorProof(uint256 validatorIndex);
    error InvalidCompleteValidatorProof(uint256 validatorIndex);
    error InvalidValidatorFieldProof(ValidatorField field, uint256 validatorIndex);
    error InvalidBalanceProof(uint256 validatorIndex);

    // Beacon Block Proof Errors
    error InvalidBeaconStateRootProof();
    error InvalidBlockNumberProof();
    error InvalidDepositProof(bytes32 validatorPubkeyHash);

    struct BeaconStateRootProofInfo {
        uint256 slot;
        bytes32 beaconStateRoot;
        bytes32[] beaconStateRootProof;
    }

    struct ValidatorProofInfo {
        uint256 validatorIndex;
        bytes32 validatorRoot;
        bytes32[] validatorProof;
    }

    struct Validator {
        // TODO: Can divide this into pubkey1, pubkey2 (48 bytes total)
        bytes32 pubkeyHash;
        bytes32 withdrawalCredentials;
        // Not to be confused with the validator's balance (effective balance capped at 32ETH)
        uint64 effectiveBalance;
        bool slashed;
        uint64 activationEligibilityEpoch;
        uint64 activationEpoch;
        // If null, type(uint64).max
        uint64 exitEpoch;
        // If null, type(uint64).max
        uint64 withdrawableEpoch;
    }

    struct ValidatorStatus {
        Validator validator;
        uint256 balance;
        bool exists;
    }

    enum ValidatorField {
        Pubkey,
        WithdrawalCredentials,
        // Not to be confused with the validator's balance (effective balance capped at 32ETH)
        EffectiveBalance,
        Slashed,
        ActivationEligibilityEpoch,
        ActivationEpoch,
        ExitEpoch,
        WithdrawableEpoch
    }

    function _verifyBlockNumber(
        uint256 _blockNumber,
        bytes32[] memory _blockNumberProof,
        bytes32 _blockHeaderRoot
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                SSZ.toLittleEndian(_blockNumber),
                EXECUTION_PAYLOAD_BLOCK_NUMBER_INDEX,
                _blockNumberProof,
                _blockHeaderRoot
            )
        ) {
            revert InvalidBlockNumberProof();
        }
    }

    function _verifyBeaconStateRoot(
        BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        bytes32 _blockHeaderRoot
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                _beaconStateRootProofInfo.beaconStateRoot,
                BEACON_STATE_ROOT_INDEX,
                _beaconStateRootProofInfo.beaconStateRootProof,
                _blockHeaderRoot
            )
        ) {
            revert InvalidBeaconStateRootProof();
        }
    }

    function _verifyValidatorRoot(
        BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        ValidatorProofInfo calldata _validatorProofInfo,
        bytes32 _blockHeaderRoot
    ) internal pure {
        _verifyBeaconStateRoot(_beaconStateRootProofInfo, _blockHeaderRoot);

        _verifyValidatorRoot(_validatorProofInfo, _beaconStateRootProofInfo.beaconStateRoot);
    }

    function _verifyValidatorRoot(
        ValidatorProofInfo calldata _validatorProofInfo,
        bytes32 _beaconStateRoot
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                _validatorProofInfo.validatorRoot,
                BASE_VALIDATOR_INDEX + _validatorProofInfo.validatorIndex,
                _validatorProofInfo.validatorProof,
                _beaconStateRoot
            )
        ) {
            revert InvalidValidatorProof(_validatorProofInfo.validatorIndex);
        }
    }

    /// @notice Proves the gindex for the specified pubkey at _depositIndex
    function _verifyValidatorDeposited(
        uint256 _depositIndex,
        bytes32 _pubkeyHash,
        bytes32[] memory _depositedPubkeyProof,
        bytes32 _blockHeaderRoot
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                _pubkeyHash,
                ((((BASE_DEPOSIT_INDEX + _depositIndex) * 2) + 1) * 4) + 0,
                _depositedPubkeyProof,
                _blockHeaderRoot
            )
        ) {
            revert InvalidDepositProof(_pubkeyHash);
        }
    }

    /// @notice Proves the validator balance against the beacon state root
    /// @dev The validator balance is stored in a packed array of 4 64-bit integers, so we prove the combined balance at gindex (BASE_BALANCE_INDEX + (validatorIndex / 4)
    function _verifyValidatorBalance(
        bytes32[] memory _balanceProof,
        uint256 _validatorIndex,
        bytes32 _combinedBalance,
        bytes32 _beaconStateRoot
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                _combinedBalance,
                BASE_BALANCE_INDEX + (_validatorIndex / 4),
                _balanceProof,
                _beaconStateRoot
            )
        ) {
            revert InvalidBalanceProof(_validatorIndex);
        }
    }

    /// @notice Proves a validator field against the validator root
    function _verifyValidatorField(
        bytes32 _validatorRoot,
        uint256 _validatorIndex,
        bytes32 _leaf,
        bytes32[] memory _validatorFieldProof,
        ValidatorField _field
    ) internal pure {
        if (
            !SSZ.isValidMerkleBranch(
                _leaf, _getFieldGIndex(_field), _validatorFieldProof, _validatorRoot
            )
        ) {
            revert InvalidValidatorFieldProof(_field, _validatorIndex);
        }
    }

    /// @notice Checks complete validator struct against validator root
    function _verifyCompleteValidatorStruct(
        bytes32 validatorRoot,
        uint256 validatorIndex,
        Validator calldata validatorData
    ) internal pure {
        bytes32 h1 =
            sha256(abi.encodePacked(validatorData.pubkeyHash, validatorData.withdrawalCredentials));
        bytes32 h2 = sha256(
            abi.encodePacked(
                SSZ.toLittleEndian(validatorData.effectiveBalance),
                SSZ.toLittleEndian(validatorData.slashed ? 1 : 0)
            )
        );
        bytes32 h3 = sha256(
            abi.encodePacked(
                SSZ.toLittleEndian(validatorData.activationEligibilityEpoch),
                SSZ.toLittleEndian(validatorData.activationEpoch)
            )
        );
        bytes32 h4 = sha256(
            abi.encodePacked(
                SSZ.toLittleEndian(validatorData.exitEpoch),
                SSZ.toLittleEndian(validatorData.withdrawableEpoch)
            )
        );

        bytes32 h5 = sha256(abi.encodePacked(h1, h2));
        bytes32 h6 = sha256(abi.encodePacked(h3, h4));
        bytes32 h7 = sha256(abi.encodePacked(h5, h6));

        if (h7 != validatorRoot) {
            revert InvalidCompleteValidatorProof(validatorIndex);
        }
    }

    /// @notice Proves the balance of a validator against combined balances array &
    /// @return Validator balance
    function _proveValidatorBalance(
        uint256 _validatorIndex,
        bytes32 _beaconStateRoot,
        // Combined balances of 4 validators packed into same gindex
        bytes32 _combinedBalance,
        bytes32[] calldata _balanceProof
    ) internal pure returns (uint256) {
        _verifyValidatorBalance(_balanceProof, _validatorIndex, _combinedBalance, _beaconStateRoot);

        return _getBalanceFromCombinedBalance(_validatorIndex, _combinedBalance);
    }

    /// @notice Validator balances are stored in an array of 4 64-bit integers, we extract the validator's balance
    function _getBalanceFromCombinedBalance(uint256 _validatorIndex, bytes32 _combinedBalance)
        internal
        pure
        returns (uint256)
    {
        uint256 modBalance = _validatorIndex % 4;

        bytes32 mask = bytes32(0xFFFFFFFFFFFFFFFF << ((3 - modBalance) * 64));
        bytes32 leBytes = (_combinedBalance & mask) << (modBalance * 64);
        uint256 result = 0;
        for (uint256 i = 0; i < leBytes.length; i++) {
            result += uint256(uint8(leBytes[i])) * 2 ** (8 * i);
        }
        return result;
    }

    /// @notice Returns the gindex for a validator field
    function _getFieldGIndex(ValidatorField _field) internal pure returns (uint256) {
        if (_field == ValidatorField.Pubkey) {
            return VALIDATOR_FIELDS_LENGTH + PUBKEY_INDEX;
        } else if (_field == ValidatorField.WithdrawalCredentials) {
            return VALIDATOR_FIELDS_LENGTH + WITHDRAWAL_CREDENTIALS_INDEX;
        } else if (_field == ValidatorField.Slashed) {
            return VALIDATOR_FIELDS_LENGTH + SLASHED_INDEX;
        } else if (_field == ValidatorField.ActivationEligibilityEpoch) {
            return VALIDATOR_FIELDS_LENGTH + ACTIVATION_ELIGIBILITY_EPOCH_INDEX;
        } else if (_field == ValidatorField.ActivationEpoch) {
            return VALIDATOR_FIELDS_LENGTH + ACTIVATION_EPOCH_INDEX;
        } else if (_field == ValidatorField.ExitEpoch) {
            return VALIDATOR_FIELDS_LENGTH + EXIT_EPOCH_INDEX;
        } else {
            return VALIDATOR_FIELDS_LENGTH + WITHDRAWABLE_EPOCH_INDEX;
        }
    }
}
