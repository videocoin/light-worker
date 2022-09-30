// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILightWorkerDao {
    function addWorker(address owner) external;

    function removeWorker(address owner) external;

    function addPredictionChallenge(
        uint256 rewardAmount,
        uint256 rewardThreshold,
        uint256 minValue,
        uint256 maxValue,
        uint256 validWindow,
        bytes memory data
    ) external returns (uint256 challengeId);

    function getPredictionChallenge(uint256 _challengeId)
        external
        view
        returns (
            uint256 minValue,
            uint256 maxValue,
            uint256 creationTIme,
            uint256 validWindow,
            bytes memory data
        );

    function submitResponse(uint256 challengeId, uint256 value) external;

    function processPredictions(uint256 challengeId) external;

    function getResponseCount(uint256 transactionId)
        external
        view
        returns (uint256 count);

    function getChallengeCount(bool pending, bool executed)
        external
        view
        returns (uint256 count);

    function getPredictions(uint256 challengeId)
        external
        view
        returns (address[] memory _predictions);

    function getChallengeIds(
        uint256 from,
        uint256 to,
        bool pending,
        bool executed
    ) external view returns (uint256[] memory _transactionIds);

    function getPredictionValue() external returns (uint256 value);

    function acquireToken() external payable returns (uint256);

    function releaseToken() external payable returns (uint256);
}
