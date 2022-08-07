// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRewardMgr {
    // Distribute rewards. VID atleast equal to totalPayment should be deposited to the RewardMgr account
    // before calling this method
    function distribute(IERC20 token, address[] memory accounts, uint256 totalPayment) external; 
}