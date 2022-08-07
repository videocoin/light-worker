// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILightWorkerDao {

    function addWorker(address owner) external;
    function removeWorker(address owner) external;

    function addPredictionChallenge(uint rewardAmount, uint rewardThreshold, uint minValue, uint maxValue, bytes memory data) external returns (uint challengeId);
    function getPredictionChallenge() external returns (uint challengeId, uint minValue, uint maxValue, bytes memory data);

    function submitResponse(uint challengeId, uint value) external;

    function processPredictions(uint challengeId) external;

    function getResponseCount(uint transactionId) external view returns (uint count);
    function getTransactionCount(bool pending, bool executed) external view returns (uint count);

    function getPredictions(uint challengeId) external view returns (address[] memory _predictions);
    function getTransactionIds(uint from, uint to, bool pending, bool executed) external view returns (uint[] memory  _transactionIds);
    function getPredictionValue() external returns (uint value);
}
