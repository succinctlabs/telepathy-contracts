pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import {TelepathyValidator} from "./TelepathyValidator.sol";
import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";

contract Deploy is Script {
    function run() public {
        address GUARDIAN_ADDRESS = vm.envAddress("GUARDIAN_ADDRESS");
        address TIMELOCK_ADDRESS = vm.envAddress("TIMELOCK_ADDRESS");
        address LIGHT_CLIENT_ADDRESS = vm.envAddress("LIGHT_CLIENT_ADDRESS");

        vm.startBroadcast();
        TelepathyPubSub pubsub = new TelepathyPubSub(
            GUARDIAN_ADDRESS,
            TIMELOCK_ADDRESS,
            LIGHT_CLIENT_ADDRESS
        );
        vm.stopBroadcast();

        uint32 SOURCE_CHAIN_ID = uint32(vm.envUint("SOURCE_CHAIN_ID"));
        address AMB_AFFIRMATION_SOURCE_ADDRESS = vm.envAddress("AMB_AFFIRMATION_SOURCE_ADDRESS");
        uint64 START_SLOT = uint64(vm.envUint("START_SLOT"));
        uint64 END_SLOT = uint64(vm.envUint("END_SLOT"));
        address HOME_AMB_ADDRESS = vm.envAddress("HOME_AMB_ADDRESS");
        address OWNER = vm.envAddress("OWNER");

        vm.startBroadcast();
        TelepathyValidator validator = new TelepathyValidator();
        validator.initialize(
            address(pubsub),
            SOURCE_CHAIN_ID,
            AMB_AFFIRMATION_SOURCE_ADDRESS,
            START_SLOT,
            END_SLOT,
            HOME_AMB_ADDRESS,
            OWNER 
        );
        vm.stopBroadcast();
    }
}
