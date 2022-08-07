// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IRewardMgr.sol";

contract RewardMgr is IRewardMgr, Context {
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event ERC20PaymentReleased(IERC20 indexed token, address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    
    // Miner node operator assoicated with theToken ID
    address payable public operator;
    
    // Contract deployer
    address public  owner;

    // Parent Contract    
    address public  contractAddress;

    // Tken ID associated with this instance
    uint256 public  tokenID;

    modifier onlyOperator() {
        require(msg.sender == address(operator));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == address(owner));
        _;
    }

    modifier onlyParent() {
        require(msg.sender == address(contractAddress));
        _;
    }

    constructor(address _operator, address _contractAddress, uint _tokenID) payable {
        owner = msg.sender;
        operator = payable(_operator);
        contractAddress = _contractAddress;
        tokenID = _tokenID;
    }

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares(address [] memory accounts) public view returns (uint256) {
        uint256 _totalShares = 0;
        // TODO get it from GatingNft1155
        for (uint i=0; i < accounts.length; i++) {
            uint256 _shares = shares(accounts[i]);
            _totalShares += _shares;
        }
        return _totalShares;
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        uint256 _shares = 0;
       uint count = IERC1155(contractAddress).balanceOf(account, tokenID);
        return _shares;
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function distribute(IERC20 token, address[] memory accounts, uint256 totalPayment) 
    public 
    onlyOperator 
    {
        uint256 _totalShares = totalShares(accounts); 
        uint256 totalBalance = token.balanceOf(address(this));
        require(totalBalance >= totalPayment); 
        for (uint i=0; i < accounts.length; i++) {
            uint256 _shares = shares(accounts[i]);
            uint256 payment = _pendingPayment(accounts[i], _shares, _totalShares, totalPayment);
            SafeERC20.safeTransfer(token, accounts[i], payment);
            emit ERC20PaymentReleased(token, accounts[i], payment);
        }
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 _shares,
        uint256 _totalShares,
        uint256 _totalPayment
    ) private view returns (uint256) {
        return (_totalPayment * _shares) / _totalShares;
    }

}