// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {
    ITelepathyReceiverV2,
    MessageStatus,
    ITelepathyHandlerV2,
    ITelepathyRouterV2
} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyRouterV2} from "src/amb-v2/TelepathyRouter.sol";
import {TelepathyStorageV2Verifier} from "src/amb-v2/verifier/TelepathyStorageVerifier.sol";
import {TelepathyEventVerifier} from "src/amb-v2/verifier/TelepathyEventVerifier.sol";
import {Bytes32} from "src/libraries/Typecast.sol";
import {TelepathyStorageV2Verifier} from "src/amb-v2/verifier/TelepathyStorageVerifier.sol";
import {TelepathyEventVerifier} from "src/amb-v2/verifier/TelepathyEventVerifier.sol";
import {TelepathyAttestationVerifier} from "src/amb-v2/verifier/TelepathyAttestationVerifier.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

library WrappedInitialize {
    function initializeRouter(
        address _targetAMB,
        uint32 _sourceChainId,
        address _beaconLightClient,
        address _ethCallGateway,
        address _sourceAMB,
        address _timelock,
        address _guardian
    ) internal returns (address, address, address) {
        uint32[] memory sourceChainIds = new uint32[](0);
        address[] memory beaconLightClients = new address[](0);
        address[] memory sourceAMBs = new address[](0);

        TelepathyRouterV2(_targetAMB).initialize(
            sourceChainIds, beaconLightClients, sourceAMBs, _timelock, _guardian, true
        );

        return initializeVerifiers(_sourceChainId, _beaconLightClient, _ethCallGateway, _sourceAMB);
    }

    function initializeVerifiers(
        uint32 _sourceChainId,
        address _beaconLightClient,
        address _ethCallGateway,
        address _sourceAMB
    ) internal returns (address, address, address) {
        uint32[] memory sourceChainIds = new uint32[](1);
        sourceChainIds[0] = _sourceChainId;
        address[] memory beaconLightClients = new address[](1);
        beaconLightClients[0] = _beaconLightClient;
        address[] memory sourceAMBs = new address[](1);
        sourceAMBs[0] = _sourceAMB;

        address storageVerifierAddr =
            address(new TelepathyStorageV2Verifier(sourceChainIds, beaconLightClients, sourceAMBs));
        address eventVerifierAddr =
            address(new TelepathyEventVerifier(sourceChainIds, beaconLightClients, sourceAMBs));
        address attestationVerifierAddr =
            address(new TelepathyAttestationVerifier(_ethCallGateway, sourceChainIds, sourceAMBs));

        return (storageVerifierAddr, eventVerifierAddr, attestationVerifierAddr);
    }
}

contract SimpleHandler is ITelepathyHandlerV2 {
    uint32 public sourceChain;
    address public sourceAddress;
    address public targetAMB;
    uint256 public nonce;
    mapping(uint256 => bytes32) public nonceToDataHash;
    VerifierType public vType = VerifierType.ZK_EVENT;

    function setParams(uint32 _sourceChain, address _sourceAddress, address _targetAMB) public {
        sourceChain = _sourceChain;
        sourceAddress = _sourceAddress;
        targetAMB = _targetAMB;
    }

    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        require(msg.sender == targetAMB, "Only Telepathy can call this function");
        require(_sourceChainId == sourceChain, "Invalid source chain id");
        require(_sourceAddress == sourceAddress, "Invalid source address");
        nonceToDataHash[nonce++] = keccak256(_data);
        return ITelepathyHandlerV2.handleTelepathy.selector;
    }

    function setVerifierType(VerifierType _verifierType) external {
        vType = _verifierType;
    }

    function verifierType() external view returns (VerifierType) {
        return vType;
    }
}
