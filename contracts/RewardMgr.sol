// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract RewardMgr is Context {
    event EthPaymentReleased(uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    // Parent Contract
    address public nftContract;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == address(owner), "RW: Invalid Owner Address");
        _;
    }

    constructor(address _nftContract) {
        owner = msg.sender;
        nftContract = _nftContract;
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
    function totalShares(address[] memory accounts, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 _totalShares = 0;
        // TODO get it from GatingNft1155
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 _shares = shares(accounts[i], tokenId);
            _totalShares += _shares;
        }
        return _totalShares;
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 count = IERC1155(nftContract).balanceOf(account, tokenId);
        return count;
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function distribute(
        address[] memory accounts,
        uint256 tokenId,
        uint256 totalPayment
    ) public {
        uint256 _totalShares = totalShares(accounts, tokenId);
        uint256 totalBalance = address(this).balance;
        require(totalBalance >= totalPayment, "Not enough Reward balance!");
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 _shares = shares(accounts[i], tokenId);
            uint256 payment = _pendingPayment(
                _shares,
                _totalShares,
                totalPayment
            );
            (bool sent, ) = payable(accounts[i]).call{value: payment}("");
            require(sent, "Payment failed");
        }
        emit EthPaymentReleased(totalPayment);
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        uint256 _shares,
        uint256 _totalShares,
        uint256 _totalPayment
    ) private pure returns (uint256) {
        return (_totalPayment * _shares) / _totalShares;
    }

    function setNftContract(address _nftContract) external onlyOwner {
        nftContract = _nftContract;
    }
}
