// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "./IRewardMgr.sol";

/// @title LightWorkerDao  - Allows multiple parties to agree on challenges before execution.
contract LightWorkerDao {
    event Response(
        uint256 indexed tokenID,
        address indexed sender,
        uint256 indexed challengeId
    );
    event Challenge(uint256 indexed challengeID);
    event Execution(uint256 indexed tokenID, uint256 indexed challengeId);
    event ExecutionFailure(
        uint256 indexed tokenID,
        uint256 indexed challengeId
    );
    event Deposit(address indexed sender, uint256 value);
    event WorkerAdded(uint256 indexed tokenID, address indexed worker);
    event WorkerRemoved(uint256 indexed tokenID, address indexed worker);
    event DistribRewards(uint256 indexed tokenID);

    // Parent contract
    address public parent;

    // Reward distribution contract
    address public rewardMgr;

    // Operator posting predectionChallenge
    address public operator;

    uint256 public required;

    address[] public workers;

    // Token ID, this contract instance is supporting in Gating Contract
    uint256 public tokenID;
    uint256 public tokenPrice;

    uint256 public challengeCount;
    uint256 public currentPrediction;

    mapping(uint256 => PredictionChallenge) public challenges;
    mapping(uint256 => mapping(address => uint256)) public responses;
    mapping(address => bool) public isWorker;

    struct PredictionChallenge {
        uint256 value; // Filled by contract after processing proposals. Predicted median value
        uint256 minValue; // Reject proposals below this value. Operator supplied.
        uint256 maxValue; // Reject proposals above this value. Operator supplied.
        uint256 rewardThreshold; // Proposal is eligible for reward if proposal is between median +- rewardThreshold
        uint256 rewardAmount; // Reward amount distributed among winning proposals
        bytes data; // metadata. Operator supplied, opaque to contract code
        uint256 creationTime; // Filled by contract. Seconds since Jan 1st 1970
        uint256 validWindow; // Validity of challenge in seconds, starting from creation time
        bool executed; // Falg indicates if prediction is completed. Filled by contract.
    }

    modifier onlyOperator() {
        require(msg.sender == address(operator), "Worker: Invalid Operator");
        _;
    }

    modifier onlyParent() {
        require(msg.sender == address(parent), "Worker: Invalid Parent");
        _;
    }

    modifier ownerDoesNotExist(address worker) {
        require(!isWorker[worker], "Worker: Existing Worker");
        _;
    }

    modifier ownerExists(address worker) {
        require(isWorker[worker], "Worker: Non-existing Worker");
        _;
    }

    modifier transactionExists(uint256 challengeId) {
        require(challenges[challengeId].value != 0, "Worker: Non-exisiting Tx");
        _;
    }

    modifier confirmed(uint256 challengeId, address worker) {
        require(responses[challengeId][worker] > 0, "Worker: Not Confirmed");
        _;
    }

    modifier notConfirmed(uint256 challengeId, address worker) {
        require(responses[challengeId][worker] == 0, "Worker: Confirmed");
        _;
    }

    modifier notExecuted(uint256 challengeId) {
        require(!challenges[challengeId].executed, "Worker: Executed");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Worker: Zero Address");
        _;
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    constructor(
        address _parent,
        address _operator,
        address _rewardMgr,
        uint256 _tokenID
    ) {
        parent = _parent;
        tokenID = _tokenID;
        operator = _operator;
        rewardMgr = _rewardMgr;
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    function addWorker(address worker) public onlyParent notNull(worker) {
        if (!isWorker[worker]) {
            workers.push(worker);
            isWorker[worker] = true;
        }
        emit WorkerAdded(tokenID, worker);
    }

    function removeWorker(address worker) public onlyParent {
        if (isWorker[worker]) {
            isWorker[worker] = false;
            for (uint256 i = 0; i < workers.length - 1; i++)
                if (workers[i] == worker) {
                    workers[i] = workers[workers.length - 1];
                    break;
                }
            workers.pop();
            emit WorkerRemoved(tokenID, worker);
        }
    }

    function addPredictionChallenge(
        uint256 rewardAmount,
        uint256 rewardThreshold,
        uint256 minValue,
        uint256 maxValue,
        uint256 validWindow,
        bytes memory data
    ) public returns (uint256 challengeId) {
        challengeId = _addPredictionChallenge(
            rewardAmount,
            rewardThreshold,
            minValue,
            maxValue,
            validWindow,
            data
        );
        //confirmTransaction(challengeId);
    }

    function getPredictionChallenge(uint256 _challengeId)
        external
        view
        returns (
            uint256 minValue,
            uint256 maxValue,
            uint256 creationTIme,
            uint256 validWindow,
            bytes memory data
        )
    {
        require(
            _challengeId < challengeCount,
            "Worker: Challenge ID out of range"
        );
        PredictionChallenge memory challenge = challenges[_challengeId];
        return (
            challenge.minValue,
            challenge.maxValue,
            challenge.creationTime,
            challenge.validWindow,
            challenge.data
        );
    }

    function submitResponse(uint256 challengeId, uint256 value)
        public
        ownerExists(msg.sender)
        transactionExists(challengeId)
        notConfirmed(challengeId, msg.sender)
    {
        require(
            IERC1155(parent).balanceOf(msg.sender, tokenID) > 0,
            "Worker: No token"
        );
        require(
            challenges[challengeId].validWindow +
                challenges[challengeId].creationTime >
                block.timestamp,
            "Worker: Out of Deadline"
        ); // transactionExists check block.timestamp > creationTime

        responses[challengeId][msg.sender] = value;
        emit Response(tokenID, msg.sender, challengeId);
        if (isReady(challengeId)) {
            processPredictions(challengeId);
        }
    }

    function isReady(uint256 challengeId) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < workers.length; i++) {
            if (responses[challengeId][workers[i]] > 0) {
                count += 1;
                if (count == required) return true;
            }
        }
        return false;
    }

    // Triggered by an external agent
    function processPredictions(uint256 challengeId)
        public
        ownerExists(msg.sender)
        confirmed(challengeId, msg.sender)
        notExecuted(challengeId)
    {
        uint256 value = predictedValue(challengeId);
        if (value > 0) {
            PredictionChallenge storage txn = challenges[challengeId];
            txn.executed = true;
            txn.value = value;
            currentPrediction = value;
            address[] memory winners = getWinners(
                challengeId,
                value,
                challenges[challengeId].rewardThreshold
            );
            distribRewardsFromEscrow(
                winners,
                tokenID,
                challenges[challengeId].rewardAmount
            );
        }
    }

    function predictedValue(uint256 challengeId) public view returns (uint256) {
        uint256[] memory values = new uint256[](workers.length);
        uint256 _median = 0;
        uint256 count = 0;
        uint256 minValue = challenges[challengeId].minValue;
        uint256 maxValue = challenges[challengeId].maxValue;
        for (uint256 i = 0; i < workers.length; i++) {
            uint256 resValue = responses[challengeId][workers[i]];
            if (resValue > minValue && resValue < maxValue) {
                values[i] = resValue;
                count++;
            }
        }
        if (count > 0) _median = median(values, count);
        return _median;
    }

    function _addPredictionChallenge(
        uint256 rewardAmount,
        uint256 rewardThreshold,
        uint256 minValue,
        uint256 maxValue,
        uint256 validWindow,
        bytes memory data
    ) internal returns (uint256 challengeId) {
        challengeId = challengeCount;
        challenges[challengeId] = PredictionChallenge({
            value: minValue,
            minValue: minValue,
            maxValue: maxValue,
            rewardAmount: rewardAmount,
            rewardThreshold: rewardThreshold,
            data: data,
            creationTime: block.timestamp,
            validWindow: validWindow,
            executed: false
        });
        challengeCount += 1;
        emit Challenge(challengeId);
    }

    function getResponseCount(uint256 challengeId)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < workers.length; i++)
            if (responses[challengeId][workers[i]] > 0) count += 1;
    }

    function getChallengeCount(bool pending, bool executed)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < challengeCount; i++)
            if (
                (pending && !challenges[i].executed) ||
                (executed && challenges[i].executed)
            ) count += 1;
    }

    function getWinners(
        uint256 challengeId,
        uint256 value,
        uint256 threshold
    ) public view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < workers.length; i++) {
            uint256 predValue = responses[challengeId][workers[i]];
            if (predValue > value - threshold && predValue < value - threshold)
                count++;
        }
        address[] memory winners = new address[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < workers.length && j < count; i++) {
            uint256 predValue = responses[challengeId][workers[i]];
            if (predValue > value - threshold && predValue < value - threshold)
                winners[j++] = workers[i];
        }
        return winners;
    }

    function getPredictions(uint256 challengeId)
        public
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](workers.length);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < workers.length; i++)
            if (responses[challengeId][workers[i]] > 0) {
                confirmationsTemp[count] = workers[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i = 0; i < count; i++) _confirmations[i] = confirmationsTemp[i];
    }

    function getChallengeIds(
        uint256 from,
        uint256 to,
        bool pending,
        bool executed
    ) public view returns (uint256[] memory _transactionIds) {
        uint256[] memory transactionIdsTemp = new uint256[](challengeCount);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < challengeCount; i++)
            if (
                (pending && !challenges[i].executed) ||
                (executed && challenges[i].executed)
            ) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        _transactionIds = new uint256[](to - from);
        for (i = from; i < to; i++)
            _transactionIds[i - from] = transactionIdsTemp[i];
    }

    function acquireToken() public payable returns (uint256) {
        require(tokenPrice != 0, "Token price not set yet");
        require(msg.value == tokenPrice, "You must pay the full price");

        // Transfer the token
        IERC1155(parent).safeTransferFrom(operator, msg.sender, tokenID, 1, "");

        // Payment goes to escrow
        //(bool sent,) = payable(owner).call{value:msg.value}("");
        //require(sent, "Payment failed");
        return tokenID;
    }

    // Allow this DAO contract to act as operator before calling releaseToken
    // IERC1155(parent).setApprovalForAll(address(this), true);

    function releaseToken() public payable returns (uint256) {
        // Check the msg.sender have tokens
        uint256 tokenBalance = IERC1155(parent).balanceOf(msg.sender, tokenID);
        require(tokenBalance > 0, "You do not own token");
        require(
            address(this).balance >= tokenPrice,
            "Not enough escrow balance!"
        );

        IERC1155(parent).safeTransferFrom(msg.sender, operator, tokenID, 1, "");

        // Make a payment to the owner of the token
        (bool sent, ) = payable(msg.sender).call{value: tokenPrice}("");
        require(sent, "Payment failed");
        return tokenID;
    }

    /*
    receive() external payable  { 
        //fundme();
    }
    */
    function setTokenPrice(uint256 price) public onlyOperator {
        require(tokenPrice == 0, "Token price can be set only once");
        tokenPrice = price;
    }

    function setRequired(uint256 _required) public onlyOperator {
        required = _required;
    }

    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }

    function distribRewardsFromEscrow(
        address[] memory winners,
        uint256 _totalPayment
    ) public onlyOperator {
        IRewardMgr(rewardMgr).distribute(winners, _totalPayment);
        emit DistribRewards(tokenID);
    }

    function getPredictionValue() external view returns (uint256 value) {
        return currentPrediction;
    }

    // Utiltiy
    function swap(
        uint256[] memory array,
        uint256 i,
        uint256 j
    ) internal pure {
        (array[i], array[j]) = (array[j], array[i]);
    }

    function sort(
        uint256[] memory array,
        uint256 begin,
        uint256 end
    ) internal pure {
        if (begin < end) {
            uint256 j = begin;
            uint256 pivot = array[j];
            for (uint256 i = begin + 1; i < end; ++i) {
                if (array[i] < pivot) {
                    swap(array, i, ++j);
                }
            }
            swap(array, begin, j);
            sort(array, begin, j);
            sort(array, j + 1, end);
        }
    }

    function median(uint256[] memory array, uint256 length)
        internal
        pure
        returns (uint256)
    {
        sort(array, 0, length);
        return
            length % 2 == 0
                ? Math.average(array[length / 2 - 1], array[length / 2])
                : array[length / 2];
    }
}
