pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {LightClientMock} from "./LightClientMock.sol";
import {TargetAMB} from "src/amb/TargetAMB.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {Timelock} from "src/libraries/Timelock.sol";

contract ContractV2 {
    uint8 public constant VERSION = 2;
    uint8 public value;

    function setValue(uint8 _value) external {
        value = _value;
    }
}

contract ContractV3 is UUPSUpgradeable {
    uint8 public constant VERSION = 3;
    uint8 public value;

    function _authorizeUpgrade(address newImplementation) internal pure override {}
}

contract ContractV2Upgradeable is UUPSUpgradeable, ContractV2 {
    function _authorizeUpgrade(address newImplementation) internal pure override {}
}

contract ContractV2NonUpgradeable is UUPSUpgradeable, ContractV2 {
    function _authorizeUpgrade(address newImplementation) internal pure override {
        revert();
    }
}

contract TargetAMBUpgradeableTest is Test {
    UUPSProxy proxy;
    TargetAMB wrappedTargetAMBProxy;
    Timelock timelock;

    address bob = payable(makeAddr("bob"));
    bytes32 SALT = 0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc726;
    uint256 MIN_DELAY = 60 * 24 * 24;

    function setUp() public {
        LightClientMock lc = new LightClientMock();
        address lightClientAddress = address(lc);
        address sourceAMBAddress = 0x42793dF05c085187E20aa99104A4E67e21823880;

        TargetAMB sourceAMBImplementation = new TargetAMB();
        proxy = new UUPSProxy(address(sourceAMBImplementation), "");

        wrappedTargetAMBProxy = TargetAMB(address(proxy));
        wrappedTargetAMBProxy.initialize(lightClientAddress, sourceAMBAddress, address(this));

        setUpTimelock();
    }

    function setUpTimelock() public {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = bob;
        executors[0] = bob;

        timelock = new Timelock(
            MIN_DELAY,
            proposers,
            executors,
            address(0)
        );
    }

    function testCanInitialize() public {
        assertFalse(wrappedTargetAMBProxy.owner() == address(0));
    }

    function testCannotUpgradeWithoutUUPS() public {
        ContractV2 testContractV2 = new ContractV2();
        vm.expectRevert(bytes("ERC1967Upgrade: new implementation is not UUPS"));
        wrappedTargetAMBProxy.upgradeTo(address(testContractV2));
    }

    function testCanUpgradeUUPS() public {
        ContractV2NonUpgradeable testContractV2 = new ContractV2NonUpgradeable();
        wrappedTargetAMBProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));
        assertEq(wrappedProxyV2.VERSION(), 2);
    }

    function testCanPersistStorageAfterUpgrade() public {
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();
        wrappedTargetAMBProxy.upgradeTo(address(testContractV2));
        ContractV2Upgradeable wrappedProxyV2 = ContractV2Upgradeable(address(proxy));

        wrappedProxyV2.setValue(111);

        ContractV3 testContractV3 = new ContractV3();
        wrappedProxyV2.upgradeTo(address(testContractV3));

        ContractV3 wrappedProxyV3 = ContractV3(address(proxy));
        assertEq(wrappedProxyV3.VERSION(), 3);
        assertEq(wrappedProxyV3.value(), 111);
    }

    function testCannotUpgradeAnymore() public {
        // Upgrade to a new implementation that disables upgrade function.
        ContractV2NonUpgradeable testContractV2 = new ContractV2NonUpgradeable();
        ContractV3 fakeContract = new ContractV3();
        wrappedTargetAMBProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));

        vm.expectRevert();
        wrappedProxyV2.upgradeTo(address(fakeContract));
    }

    function testUpgradeUsingTimelock() public {
        wrappedTargetAMBProxy.transferOwnership(address(timelock));
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.startPrank(bob);
        timelock.schedule(
            address(wrappedTargetAMBProxy),
            0,
            abi.encodeWithSelector(
                wrappedTargetAMBProxy.upgradeTo.selector, address(testContractV2)
            ),
            bytes32(0),
            SALT,
            MIN_DELAY
        );

        vm.warp(block.timestamp + MIN_DELAY);

        timelock.execute(
            address(wrappedTargetAMBProxy),
            0,
            abi.encodeWithSelector(
                wrappedTargetAMBProxy.upgradeTo.selector, address(testContractV2)
            ),
            bytes32(0),
            SALT
        );

        vm.stopPrank();

        assertEq(wrappedTargetAMBProxy.VERSION(), 2);
    }

    function testCannotCallUpgradeAsNonOwner() public {
        wrappedTargetAMBProxy.transferOwnership(address(timelock));

        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        wrappedTargetAMBProxy.upgradeTo(address(testContractV2));
    }
}
