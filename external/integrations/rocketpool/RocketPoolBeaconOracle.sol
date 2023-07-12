pragma solidity 0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";

contract RocketPoolBeaconOracle {
    ILightClient lightclient;

    event BeaconOracleUpdate(uint256 validatorIndex);

    error InvalidLightClientAddress();

    constructor(address _lightClient) {
        if (_lightClient == address(0)) {
            revert InvalidLightClientAddress();
        }
        lightclient = ILightClient(_lightClient);
    }

    /// @notice Mapping from validator index to validator struct
    mapping(uint256 => BeaconOracleHelper.ValidatorStatus) public validatorState;

    /// @notice Prove the validatorData corresponds to the validator root at validatorIndex
    function proveValidatorRootFromFields(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconOracleHelper.ValidatorProofInfo calldata _validatorProofInfo,
        BeaconOracleHelper.Validator calldata validatorData,
        bytes32[] calldata _balanceProof,
        bytes32 _combinedBalance
    ) external {
        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_beaconStateRootProofInfo.slot);

        BeaconOracleHelper.verifyValidatorRoot(
            _beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot
        );

        BeaconOracleHelper.verifyCompleteValidatorStruct(
            _validatorProofInfo.validatorRoot, _validatorProofInfo.validatorIndex, validatorData
        );

        uint256 balance = BeaconOracleHelper.proveValidatorBalance(
            _validatorProofInfo.validatorIndex,
            _beaconStateRootProofInfo.beaconStateRoot,
            _combinedBalance,
            _balanceProof
        );

        validatorState[_validatorProofInfo.validatorIndex] =
            BeaconOracleHelper.ValidatorStatus(validatorData, balance, true);

        emit BeaconOracleUpdate(_validatorProofInfo.validatorIndex);
    }

    function getValidator(uint256 _validatorIndex)
        external
        view
        returns (BeaconOracleHelper.ValidatorStatus memory)
    {
        return validatorState[_validatorIndex];
    }
}
