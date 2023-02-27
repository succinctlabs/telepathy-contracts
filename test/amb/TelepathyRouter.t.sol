pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {UUPSProxy} from "src/libraries/Proxy.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";

contract TelepathyRouterTest is Test {
    function testInitializeImplementation() public {
        TelepathyRouter router = new TelepathyRouter();

        uint32[] memory sourceChainIds = new uint32[](1);
        sourceChainIds[0] = 1;
        address[] memory lightClients = new address[](1);
        lightClients[0] = address(this);
        address[] memory broadcasters = new address[](1);
        broadcasters[0] = address(this);

        vm.expectRevert();
        router.initialize(
            sourceChainIds, lightClients, broadcasters, address(this), address(this), true
        );
    }

    function testInitializeProxy() public {
        TelepathyRouter implementation = new TelepathyRouter();
        UUPSProxy proxy = new UUPSProxy(address(implementation), "");

        uint32[] memory sourceChainIds = new uint32[](1);
        sourceChainIds[0] = 1;
        address[] memory lightClients = new address[](1);
        lightClients[0] = address(this);
        address[] memory broadcasters = new address[](1);
        broadcasters[0] = address(this);

        TelepathyRouter(address(proxy)).initialize(
            sourceChainIds, lightClients, broadcasters, address(this), address(this), true
        );
    }
}
