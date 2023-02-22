pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";

import {WrappedInitialize} from "./TargetAMB.t.sol";

contract SourceAMBTest is Test {
    TelepathyRouter wrappedSourceAMBProxy;

    function setUp() public {
        TelepathyRouter sourceAMBImplementation = new TelepathyRouter();
        UUPSProxy proxy = new UUPSProxy(address(sourceAMBImplementation), "");

        wrappedSourceAMBProxy = TelepathyRouter(address(proxy));
        WrappedInitialize.init(
            address(wrappedSourceAMBProxy),
            1,
            makeAddr("lightclient"),
            makeAddr("sourceAMB"),
            address(this),
            address(this)
        );
    }

    function testSend() public {
        wrappedSourceAMBProxy.send(100, 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990, hex"deadbeef");
    }

    function testSendViaLog() public {
        wrappedSourceAMBProxy.send(100, 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990, hex"deadbeef");
    }
}
