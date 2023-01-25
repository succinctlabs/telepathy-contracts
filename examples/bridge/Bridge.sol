// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import {ITelepathyHandler, ITelepathyBroadcaster} from "src/amb/interfaces/ITelepathy.sol";
import "./Tokens.sol";

contract Deposit is Ownable {
    uint256 public constant FEE = 1000000000000000;

    ITelepathyBroadcaster broadcaster;
    address depositToken;
    address foreignWithdraw;

    event DepositEvent(
        address indexed from,
        address indexed recipient,
        uint256 amount,
        address tokenAddress,
        uint16 chainId
    );

    constructor(address _broadcaster, address _depositToken) {
        broadcaster = ITelepathyBroadcaster(_broadcaster);
        depositToken = _depositToken;
    }

    function setWithdraw(address _foreignWithdraw) public onlyOwner {
        foreignWithdraw = _foreignWithdraw;
    }

    function deposit(address recipient, uint256 amount, address tokenAddress, uint16 chainId)
        external
        payable
        virtual
    {
        // 0.001 Ether as a fee to cover our relayer
        require(msg.value >= FEE, "Not enough fee");
        require(depositToken == tokenAddress, "Invalid deposit token address address");
        // We multiply by 10**18 since standard tokens have 18 decimals.
        require(amount <= 10 ** 18 * 100, "Can deposit a max of 100 tokens at a time");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(foreignWithdraw != address(0), "Unset foreign withdraw contract address");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        bytes memory msgData = abi.encode(recipient, amount, tokenAddress);
        broadcaster.send(chainId, foreignWithdraw, msgData);
        emit DepositEvent(msg.sender, recipient, amount, tokenAddress, chainId);
    }

    /// @notice to claimFees to the owner of the contract
    function claimFees() external onlyOwner {
        address payable owner = payable(msg.sender);
        owner.transfer(address(this).balance);
    }

    /// @notice to claimFees to a specific address
    function claimFees(address _feeRecipient) external onlyOwner {
        address payable feeRecipient = payable(_feeRecipient);
        feeRecipient.transfer(address(this).balance);
    }
}

contract Withdraw is Ownable, ITelepathyHandler {
    address depositAddress;
    address telepathyReceiver;
    uint16 sourceChainId;
    IERC20Ownable public token;

    event WithdrawEvent(
        address indexed from,
        address indexed recipient,
        uint256 amount,
        address depositTokenAddress,
        address withdrawTokenAddress
    );

    constructor(address _depositAddress, address _telepathyReceiver, uint16 _sourceChainId) {
        depositAddress = _depositAddress;
        telepathyReceiver = _telepathyReceiver;
        sourceChainId = _sourceChainId;
        token = new Succincts();
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // Mint the max number of tokens to this contract
        token.mint(address(this), MAX_INT);
    }

    function handleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes calldata _data)
        public
    {
        require(msg.sender == telepathyReceiver, "Only Telepathy Receiver can call this function");
        require(
            _senderAddress == depositAddress,
            "Only deposit can trigger a message call to this contract."
        );
        require(_sourceChainId == sourceChainId, "Invalid source chain id");
        (address recipient, uint256 amount, address tokenAddress) =
            abi.decode(_data, (address, uint256, address));
        token.transfer(recipient, amount);
        emit WithdrawEvent(msg.sender, recipient, amount, tokenAddress, address(token));
    }
}
