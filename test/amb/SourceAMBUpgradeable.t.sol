pragma solidity 0.8.14;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "src/libraries/Timelock.sol";
import "src/amb/SourceAMB.sol";
import "src/libraries/Proxy.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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

contract SourceAMBUpgradeableTest is Test {
    UUPSProxy proxy;
    SourceAMB wrappedSourceAMBProxy;
    Timelock timelock;

    address bob = payable(makeAddr("bob"));
    bytes32 SALT = 0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc726;
    uint256 MIN_DELAY = 60 * 24 * 24;

    function setUp() public {
        SourceAMB sourceAMBImplementation = new SourceAMB();
        proxy = new UUPSProxy(address(sourceAMBImplementation), "");

        wrappedSourceAMBProxy = SourceAMB(address(proxy));
        wrappedSourceAMBProxy.initialize();

        setUpTimelock();
    }

    function setUpTimelock() public {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = bob;
        executors[0] = bob;

        vm.deal(bob, 100);

        timelock = new Timelock(
            MIN_DELAY,
            proposers,
            executors,
            address(0)
        );
    }

    function testCanInitialize() public {
        assertFalse(wrappedSourceAMBProxy.owner() == address(0));
    }

    function testCannotUpgradeWithoutUUPS() public {
        ContractV2 testContractV2 = new ContractV2();
        vm.expectRevert(bytes("ERC1967Upgrade: new implementation is not UUPS"));
        wrappedSourceAMBProxy.upgradeTo(address(testContractV2));
    }

    function testCanUpgradeUUPS() public {
        ContractV2NonUpgradeable testContractV2 = new ContractV2NonUpgradeable();
        wrappedSourceAMBProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));
        assertEq(wrappedProxyV2.VERSION(), 2);
    }

    function testCanPersistStorageAfterUpgrade() public {
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();
        wrappedSourceAMBProxy.upgradeTo(address(testContractV2));
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
        wrappedSourceAMBProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));

        vm.expectRevert();
        wrappedProxyV2.upgradeTo(address(fakeContract));
    }

    function testUpgradeUsingTimelock() public {
        wrappedSourceAMBProxy.transferOwnership(address(timelock));
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.startPrank(bob);
        timelock.schedule(
            address(wrappedSourceAMBProxy),
            0,
            abi.encodeWithSelector(
                wrappedSourceAMBProxy.upgradeTo.selector, address(testContractV2)
            ),
            bytes32(0),
            SALT,
            MIN_DELAY
        );

        vm.warp(block.timestamp + MIN_DELAY);

        timelock.execute(
            address(wrappedSourceAMBProxy),
            0,
            abi.encodeWithSelector(
                wrappedSourceAMBProxy.upgradeTo.selector, address(testContractV2)
            ),
            bytes32(0),
            SALT
        );

        vm.stopPrank();

        assertEq(wrappedSourceAMBProxy.VERSION(), 2);
    }

    function testCannotCallUpgradeAsNonOwner() public {
        wrappedSourceAMBProxy.transferOwnership(address(timelock));

        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        wrappedSourceAMBProxy.upgradeTo(address(testContractV2));
    }
}
