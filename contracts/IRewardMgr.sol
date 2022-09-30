// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRewardMgr {
    // Distribute rewards. VID atleast equal to totalPayment should be deposited to the RewardMgr account
    // before calling this method
    function distribute(
        address[] memory accounts,
        uint256 tokenId,
        uint256 totalPayment
    ) external;

    function registerWorkerDao(address _contractAddress) external;
}
