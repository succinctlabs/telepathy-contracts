// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {ITelepathyRouter} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

import "./Tokens.sol";

contract Deposit is Ownable {
    uint256 public constant FEE = 0.001 ether;

    ITelepathyRouter router;
    address depositToken;
    address foreignWithdraw;

    event DepositEvent(
        address indexed from,
        address indexed recipient,
        uint256 amount,
        address tokenAddress,
        uint32 chainId
    );

    constructor(address _router, address _depositToken) {
        router = ITelepathyRouter(_router);
        depositToken = _depositToken;
    }

    /// @notice set the address of the withdrawal contract on destination chains
    /// @dev Right now the withdrawal contract must be the same across all destination chains
    function setWithdraw(address _foreignWithdraw) public onlyOwner {
        foreignWithdraw = _foreignWithdraw;
    }

    /// @notice used to deposit tokens to the bridge contract, which will send a message to the
    /// withdrawal contract on the destination chain
    /// @param recipient the address of the recipient on the destination chain
    /// @param amount the amount of tokens to deposit
    /// @param tokenAddress the address of the ERC20 token to deposit. This token address currently
    /// must match `depositToken` in the constructor but in the future we can support multiple tokens
    /// @param chainId the chain id of the destination chain
    function deposit(address recipient, uint256 amount, address tokenAddress, uint32 chainId)
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
        router.send(chainId, foreignWithdraw, msgData);
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

contract Withdraw is Ownable, TelepathyHandler {
    address depositAddress;
    uint32 sourceChainId;
    /// @notice the token that will be transferred to the recipient
    IERC20Ownable public token;

    event WithdrawEvent(
        address indexed from,
        address indexed recipient,
        uint256 amount,
        address depositTokenAddress,
        address withdrawTokenAddress
    );

    /// @notice constructor for the withdraw contract
    /// @param _depositAddress the address of the deposit contract on the source chain
    /// @param _telepathyReceiver the address of the telepathy receiver contract on this chain that can call `handleTelepathy`
    /// @param _sourceChainId the chain id of the source chain where deposits are being made
    constructor(address _depositAddress, address _telepathyReceiver, uint32 _sourceChainId)
        TelepathyHandler(_telepathyReceiver)
    {
        depositAddress = _depositAddress;
        sourceChainId = _sourceChainId;
        token = new Succincts();
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // Mint the max number of tokens to this contract
        token.mint(address(this), MAX_INT);
    }

    function handleTelepathyImpl(uint32 _sourceChainId, address _senderAddress, bytes memory _data)
        internal
        override
    {
        require(
            _senderAddress == depositAddress,
            "Only deposit address can trigger a message call to this contract."
        );
        require(_sourceChainId == sourceChainId, "Invalid source chain id");
        (address recipient, uint256 amount, address tokenAddress) =
            abi.decode(_data, (address, uint256, address));
        token.transfer(recipient, amount);
        emit WithdrawEvent(msg.sender, recipient, amount, tokenAddress, address(token));
    }
}
