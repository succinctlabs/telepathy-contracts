pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {WrappedInitialize} from "./TargetAMB.t.sol";
import {Timelock} from "src/libraries/Timelock.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TelepathyRouterTest is Test {
    function test_InitializeImplementation() public {
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

    function test_InitializeProxy() public {
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

contract TelepathyRouterUpgradeableTest is Test {
    UUPSProxy proxy;
    TelepathyRouter wrappedRouterProxy;
    Timelock timelock;

    address bob = payable(makeAddr("bob"));
    bytes32 SALT = 0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc726;
    uint256 MIN_DELAY = 60 * 24 * 24;

    function setUp() public {
        TelepathyRouter router = new TelepathyRouter();
        proxy = new UUPSProxy(address(router), "");
        setUpTimelock();

        wrappedRouterProxy = TelepathyRouter(address(proxy));

        WrappedInitialize.init(
            address(wrappedRouterProxy),
            uint32(block.chainid),
            makeAddr("lightclient"),
            makeAddr("sourceAMB"),
            address(timelock),
            address(this)
        );
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

    function test_Initialize() public {
        assertFalse(wrappedRouterProxy.version() == 0);
    }

    function test_Upgrade() public {
        vm.startPrank(address(timelock));
        ContractV2NonUpgradeable testContractV2 = new ContractV2NonUpgradeable();
        wrappedRouterProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));
        assertEq(wrappedProxyV2.VERSION(), 2);
    }

    // Storage values set in V2 should be preserved after upgrade to V3.
    function test_Upgrade_WhenPersistedToStorageAfterUpgrade() public {
        vm.startPrank(address(timelock));
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();
        wrappedRouterProxy.upgradeTo(address(testContractV2));

        ContractV2Upgradeable wrappedProxyV2 = ContractV2Upgradeable(address(proxy));
        wrappedProxyV2.setFoo1(111);
        wrappedProxyV2.setFoo2(222);
        assertEq(wrappedProxyV2.VERSION(), 2);
        assertEq(wrappedProxyV2.foo1(), 111);
        assertEq(wrappedProxyV2.foo2(), 222);

        ContractV3 testContractV3 = new ContractV3();
        wrappedProxyV2.upgradeTo(address(testContractV3));

        ContractV3 wrappedProxyV3 = ContractV3(address(proxy));
        assertEq(wrappedProxyV3.VERSION(), 3);
        assertEq(wrappedProxyV3.foo1(), 111);
        assertEq(wrappedProxyV3.foo2(), 222);
    }

    // Storage values written in V3 should not overwrite slots persisted in V2.
    function test_Upgrade_WhenWritingToStorageAfterUpgrade() public {
        vm.startPrank(address(timelock));
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();
        wrappedRouterProxy.upgradeTo(address(testContractV2));

        ContractV2Upgradeable wrappedProxyV2 = ContractV2Upgradeable(address(proxy));
        wrappedProxyV2.setFoo1(111);
        wrappedProxyV2.setFoo2(222);
        assertEq(wrappedProxyV2.VERSION(), 2);
        assertEq(wrappedProxyV2.foo1(), 111);
        assertEq(wrappedProxyV2.foo2(), 222);

        ContractV3 testContractV3 = new ContractV3();
        wrappedProxyV2.upgradeTo(address(testContractV3));

        ContractV3 wrappedProxyV3 = ContractV3(address(proxy));
        wrappedProxyV3.setBar(333); // should not alter foo1 and foo2
        assertEq(wrappedProxyV3.VERSION(), 3);
        assertEq(wrappedProxyV3.foo1(), 111);
        assertEq(wrappedProxyV3.foo2(), 222);
        assertEq(wrappedProxyV3.bar(), 333);
    }

    function test_Upgrade_WhenTimelock() public {
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.startPrank(bob);
        timelock.schedule(
            address(wrappedRouterProxy),
            0,
            abi.encodeWithSelector(wrappedRouterProxy.upgradeTo.selector, address(testContractV2)),
            bytes32(0),
            SALT,
            MIN_DELAY
        );

        vm.warp(block.timestamp + MIN_DELAY);

        timelock.execute(
            address(wrappedRouterProxy),
            0,
            abi.encodeWithSelector(wrappedRouterProxy.upgradeTo.selector, address(testContractV2)),
            bytes32(0),
            SALT
        );

        assertEq(wrappedRouterProxy.VERSION(), 2);
    }

    function test_RevertUpgrade_WhenNotUUPS() public {
        vm.startPrank(address(timelock));
        ContractV2 testContractV2 = new ContractV2();
        vm.expectRevert(bytes("ERC1967Upgrade: new implementation is not UUPS"));
        wrappedRouterProxy.upgradeTo(address(testContractV2));
    }

    // Upgrade to a new non-upgradable implementation that disables upgrade function.
    function test_RevertUpgrade_WhenUpgradeable() public {
        vm.startPrank(address(timelock));
        ContractV2NonUpgradeable testContractV2 = new ContractV2NonUpgradeable();
        ContractV3 fakeContract = new ContractV3();
        wrappedRouterProxy.upgradeTo(address(testContractV2));

        ContractV2NonUpgradeable wrappedProxyV2 = ContractV2NonUpgradeable(address(proxy));

        vm.expectRevert();
        wrappedProxyV2.upgradeTo(address(fakeContract));
    }

    function test_RevertUpgrade_WhenNonOwner() public {
        ContractV2Upgradeable testContractV2 = new ContractV2Upgradeable();

        vm.expectRevert(bytes("TelepathyRouter: only timelock can call this function"));
        wrappedRouterProxy.upgradeTo(address(testContractV2));
    }
}

// For testing https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps

contract ContractStorageV2 {
    mapping(uint256 => bytes32) public messages;

    uint128 public foo1;
    uint128 public foo2;

    uint256[48] private __gap;
}

contract ContractStorageV3 {
    mapping(uint256 => bytes32) public messages;

    uint128 public foo1;
    uint128 public foo2;

    uint256 public bar;

    uint256[47] private __gap;
}

contract ContractV2 is ContractStorageV2 {
    uint8 public constant VERSION = 2;

    function setFoo1(uint128 _foo1) external {
        foo1 = _foo1;
    }

    function setFoo2(uint128 _foo2) external {
        foo2 = _foo2;
    }
}

contract ContractV3 is UUPSUpgradeable, ContractStorageV3 {
    uint8 public constant VERSION = 3;

    function setFoo1(uint128 _foo1) external {
        foo1 = _foo1;
    }

    function setFoo2(uint128 _foo2) external {
        foo2 = _foo2;
    }

    function setBar(uint256 _bar) external {
        bar = _bar;
    }

    function _authorizeUpgrade(address) internal pure override {}
}

contract ContractV2Upgradeable is UUPSUpgradeable, ContractV2 {
    function _authorizeUpgrade(address) internal pure override {}
}

contract ContractV2NonUpgradeable is UUPSUpgradeable, ContractV2 {
    function _authorizeUpgrade(address) internal pure override {
        revert();
    }
}
