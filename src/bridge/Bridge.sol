// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "src/amb/interfaces/IAMB.sol";
import "src/amb/SourceAMB.sol";
import "./Tokens.sol";

contract Bridge is Ownable {
}

contract Deposit is Bridge {
    SourceAMB homeAmb;
	address allowedDepositToken;
    address foreignWithdraw;
    // GAS_LIMIT is how much gas the foreignWithdraw contract will
    // have to execute the withdraw function. Foundry estimates 33536
    // so we leave some buffer.
    uint256 internal constant GAS_LIMIT = 50000;

	event DepositEvent(
		address indexed from,
		address indexed recipient,
		uint256 amount,
		address tokenAddress,
        uint16 chainId
	);

	constructor(address _homeAmb, address _allowedToken) {
        homeAmb = SourceAMB(_homeAmb);
		allowedDepositToken = _allowedToken;
	}

    function setWithdraw(address _foreignWithdraw) public onlyOwner {
        foreignWithdraw = _foreignWithdraw;
    }

	function deposit(
		address recipient,
		uint256 amount,
		address tokenAddress,
        uint16 chainId
	) external payable virtual {
        // 0.001 Ether as a fee to cover our relayer
        require(msg.value >= 1000000000000000, "Not enough fee");
		require(allowedDepositToken == tokenAddress, "Invalid deposit token address address");
        // We multiply by 10**18 since standard tokens have 18 decimals.
        require(amount <= 10**18 * 100, "Can deposit a max of 100 tokens at a time");
		require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(foreignWithdraw != address(0), "Unset foreign withdraw contract address");
		IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        bytes memory msgData = abi.encode(recipient, amount, tokenAddress);
        homeAmb.send(foreignWithdraw, chainId, GAS_LIMIT, msgData);
		emit DepositEvent(msg.sender, recipient, amount, tokenAddress, chainId);
	}

    function claimFees() external onlyOwner {
        // Only the contract deployer can pay the fee
        // Note that this requires the contract deployer to be an EOA
        // which might be undesireable in the future.
        address payable owner = payable(msg.sender);
        owner.transfer(address(this).balance);
    }
}

contract DepositMock is Deposit {
	constructor(address _homeAmb, address _allowedToken) Deposit(_homeAmb, _allowedToken) {
	}

	// We have a mock for testing purposes.
	function deposit(
		address recipient,
		uint256 amount,
		address tokenAddress,
        uint16 chainId
	) external payable override {
        require(msg.value >= 1000000000000000, "Not enough fee");
		require(allowedDepositToken == tokenAddress, "Invalid deposit token address address");
        require(amount <= 10**18 * 100, "Can deposit a max of 100 tokens at a time");
		// Do not do any of the checks involving ERC20.
		bytes memory msgData = abi.encode(recipient, amount, tokenAddress);
        homeAmb.send(foreignWithdraw, chainId, GAS_LIMIT, msgData);
		emit DepositEvent(msg.sender, recipient, amount, tokenAddress, chainId);
	}
}

contract Withdraw is Bridge {
    address homeDeposit;
    address foreignAmb;
    IERC20Ownable public token;

	event WithdrawEvent(
		address indexed from,
		address indexed recipient,
		uint256 amount,
		address depositTokenAddress,
		address withdrawTokenAddress
	);

	constructor(address _foreignAmb, address _homeDeposit) {
		foreignAmb = _foreignAmb;
		homeDeposit = _homeDeposit;
        token = new Succincts();
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // Mint the max number of tokens to this contract
        token.mint(address(this), MAX_INT);
	}

	function receiveSuccinct(
        address srcAddress,
        bytes calldata callData
	) public {
        require(msg.sender == foreignAmb, "Only foreign amb can call this function");
        require(srcAddress == homeDeposit, "Only home deposit can trigger a message call to this contract.");
        (address recipient, uint256 amount, address tokenAddress) = abi.decode(callData, (address, uint256, address));
        token.transfer(recipient, amount);
		emit WithdrawEvent(msg.sender, recipient, amount, tokenAddress, address(token));
	}
}
