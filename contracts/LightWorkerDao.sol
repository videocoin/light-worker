// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "./ILightWorkerDao.sol";
import "./RewardMgr.sol";

/// @title LightWorkerDao  - Allows multiple parties to agree on challenges before execution.
contract LightWorkerDao is ILightWorkerDao {
    /*
     *  Events
     */
    event Response(uint indexed tokenID, address indexed sender, uint indexed challengeId);
    event Challenge(uint indexed challengeID);
    event Execution(uint indexed tokenID, uint indexed challengeId);
    event ExecutionFailure(uint indexed tokenID, uint indexed challengeId);
    event Deposit(address indexed sender, uint value);
    event WorkerAdded(uint indexed tokenID, address indexed worker);
    event WorkerRemoved(uint indexed tokenID, address indexed worker);
    event DistribRewards(uint indexed tokenID);

    // Constants
    
    // Parent contract
    address public parent;
    
    // Reward distribution contract 
    address public rewardMgr;

    // Operator posting predectionChallenge
    address public operator;

    // Token ID, this contract instance is supporting in Gating Contract
    uint tokenID;
    uint tokenPrice;

    /*
     *  Storage
     */
    mapping (uint => PredictionChallenge) public challenges;
    mapping (uint => mapping (address => uint)) public responses;
    uint public required;
    uint public challengeCount;

    address[] public workers;
    mapping (address => bool) public isWorker;

    uint public currentPrediction;

    struct PredictionChallenge {
        uint value;             // Filled by contract after processing proposals. Predicted median value
        uint minValue;          // Reject proposals below this value. Operator supplied.
        uint maxValue;          // Reject proposals above this value. Operator supplied.
        uint rewardThreshold;   // Proposal is eligible for reward if proposal is between median +- rewardThreshold
        uint rewardAmount;      // Reward amount distributed among winning proposals       
        bytes data;             // metadata. Operator supplied, opaque to contract code
        uint creationTime;      // Filled by contract. Seconds since Jan 1st 1970
        uint validWindow;       // Validity of challenge in seconds, starting from creation time              
        bool executed;          // Falg indicates if prediction is completed. Filled by contract.
    }

    /*
     *  Modifiers
     */

    modifier onlyOperator() {
        require(msg.sender == address(operator));
        _;
    }

    modifier onlyParent() {
        require(msg.sender == address(parent));
        _;
    }

    modifier ownerDoesNotExist(address worker) {
        require(!isWorker[worker]);
        _;
    }

    modifier ownerExists(address worker) {
        require(isWorker[worker]);
        _;
    }

    modifier transactionExists(uint challengeId) {
        require(challenges[challengeId].value != 0);
        _;
    }

    modifier confirmed(uint challengeId, address worker) {
        require(responses[challengeId][worker] > 0);
        _;
    }

    modifier notConfirmed(uint challengeId, address worker) {
        require(responses[challengeId][worker]==0);
        _;
    }

    modifier notExecuted(uint challengeId) {
        require(!challenges[challengeId].executed);
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0));
        _;
    }

    /// @dev Fallback function allows to deposit ether.
    /*
    fallback() external payable {
        if (msg.value > 0)
            emit  Deposit(msg.sender, msg.value);
    }
    */

    constructor(address _parent, address _operator, address _rewardMgr, uint _tokenID)
    {
        parent = _parent;
        tokenID = _tokenID;
        operator = _operator;
        rewardMgr = _rewardMgr;
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    function addWorker(address worker)
        public
        onlyParent
        notNull(worker)
    {
        if(!isWorker[worker]) {
            workers.push(worker);
            isWorker[worker] = true;
        }
        emit  WorkerAdded(tokenID, worker);
    }


    function removeWorker(address worker)
        public
        onlyParent
    {
        if(isWorker[worker]) {
            isWorker[worker] = false;
            for (uint i=0; i < workers.length - 1; i++)
                if (workers[i] == worker) {
                    workers[i] = workers[workers.length - 1];
                    break;
                }
            workers.pop();
            emit WorkerRemoved(tokenID, worker);
        }
    }

    function addPredictionChallenge(uint rewardAmount, uint rewardThreshold, uint minValue, uint maxValue, uint validWindow, uint _required, bytes memory data)
        public
        returns (uint challengeId)
    {
        challengeId = _addPredictionChallenge(rewardAmount, rewardThreshold, minValue,  maxValue, validWindow, data);
        required = _required;
        //confirmTransaction(challengeId);
    }

    function getPredictionChallenge() external returns (uint challengeId, uint minValue, uint maxValue, uint creationTIme, uint validWindow, bytes memory data) {
      if(challengeCount > 1) {
          uint _challengeId = challengeCount - 1;
          PredictionChallenge memory challenge = challenges[_challengeId];
          return (_challengeId, challenge.minValue, challenge.maxValue, challenge.creationTime, challenge.validWindow, challenge.data);  
      }
      return (0,0,0,0,0,"");  
    }

    function submitResponse(uint challengeId, uint value)
        public
        ownerExists(msg.sender)
        transactionExists(challengeId)
        notConfirmed(challengeId, msg.sender)
    {
        uint count = IERC1155(parent).balanceOf(msg.sender, tokenID);
        responses[challengeId][msg.sender] = value;
        emit  Response(tokenID, msg.sender, challengeId);
        if(isReady(challengeId)) {
            processPredictions(challengeId);
        }
    }

    function isReady(uint challengeId)
        public view
        returns (bool)
    {
        uint count = 0;
        for (uint i=0; i<workers.length; i++) {
            if (responses[challengeId][workers[i]] > 0)
                count += 1;
            if (count == required)
                return true;
        }
        return false;
    }

    // Triggered by an external agent
    function processPredictions(uint challengeId)
        public
        ownerExists(msg.sender)
        confirmed(challengeId, msg.sender)
        notExecuted(challengeId)
    {
        uint value = predictedValue(challengeId);
        if (value > 0) {
            PredictionChallenge storage txn = challenges[challengeId];
            txn.executed = true;
            txn.value = value;
            currentPrediction = value; 
            address []memory winners = getWinners(challengeId, value, challenges[challengeId].rewardThreshold);
            distribRewardsFromEscrow(winners, challenges[challengeId].rewardAmount);
        }
    }

    function predictedValue(uint challengeId)
        public
        view
        returns (uint)
    {
        uint[] memory values = new uint[](workers.length);
        uint _median = 0;
        uint count = 0;
        uint minValue = challenges[challengeId].minValue;
        uint maxValue = challenges[challengeId].maxValue;
        for (uint i=0; i<workers.length; i++) {
            if (responses[challengeId][workers[i]] > 0) {
                values[i] = responses[challengeId][workers[i]];
                count++;
            }
        }
        if (count > 0)
            _median = median(values, count);
        return _median;
    }


    function _addPredictionChallenge(uint rewardAmount, uint rewardThreshold, uint minValue, uint maxValue, uint validWindow, bytes memory data)
        internal
        returns (uint challengeId)
    {
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
        emit  Challenge(challengeId);
    }

    function getResponseCount(uint challengeId)
        public
        view
        returns (uint count)
    {
        for (uint i=0; i < workers.length; i++)
            if (responses[challengeId][workers[i]] > 0)
                count += responses[challengeId][workers[i]];
    }

    function getChallengeCount(bool pending, bool executed)
        public
        view        
        returns (uint count)
    {
        for (uint i=0; i<challengeCount; i++)
            if (   pending && !challenges[i].executed
                || executed && challenges[i].executed)
                count += 1;
    }


    function getWinners(uint challengeId, uint value, uint threshold)
        public
        view
        returns (address[] memory)
    {
        uint count = 0;
        for (uint i=0; i < workers.length; i++) {
            uint predValue = responses[challengeId][workers[i]];
            if (predValue > value - threshold && predValue < value - threshold)
                count++;     
        }   
        address[] memory winners = new address[] (count);
        uint j = 0;
        for (uint i=0; i < workers.length && j < count; i++) {
            uint predValue = responses[challengeId][workers[i]];
            if (predValue > value - threshold && predValue < value - threshold)
                winners[j++] = workers[i];     
        }   
        return winners;
    }


    function getPredictions(uint challengeId)
        public
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](workers.length);
        uint count = 0;
        uint i;
        for (i=0; i < workers.length; i++)
            if (responses[challengeId][workers[i]] > 0) {
                confirmationsTemp[count] = workers[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i=0; i<count; i++)
            _confirmations[i] = confirmationsTemp[i];
    }

    function getChallengeIds(uint from, uint to, bool pending, bool executed)
        public
        view
        returns (uint[] memory  _transactionIds)
    {
        uint[] memory transactionIdsTemp = new uint[](challengeCount);
        uint count = 0;
        uint i;
        for (i=0; i<challengeCount; i++)
            if (   pending && !challenges[i].executed
                || executed && challenges[i].executed)
            {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        _transactionIds = new uint[](to - from);
        for (i=from; i<to; i++)
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
        uint tokenBalance = IERC1155(parent).balanceOf(msg.sender, tokenID);
        require (tokenBalance > 0, "You do not own token"); 
        require(address(this).balance >= tokenPrice, "Not enough escrow balance!");
        
        IERC1155(parent).safeTransferFrom(msg.sender, operator, tokenID, 1, "");

        // Make a payment to the owner of the token
        (bool sent,) = payable(msg.sender).call{value:tokenPrice}("");
        require(sent, "Payment failed");
        return tokenID;
    }
  

    /*
    receive() external payable  { 
        //fundme();
    }
    */
    function setTokenPrice(uint price) 
    public 
    onlyOperator
    {
        require( tokenPrice == 0, "Token price can be set only once");
        tokenPrice = price;
    }

    function getTokenPrice()  public view  returns (uint){
        return tokenPrice;
    }

    function distribRewardsFromEscrow(address[] memory winners, uint256 _totalPayment) 
    public 
    onlyOperator
    {
        // TODO: Modify based on ERC20 vs native VID
        IERC20 _token = IERC20(address(0));
        IRewardMgr(rewardMgr).distribute(_token, winners, _totalPayment);
        emit DistribRewards(tokenID);
    }

    function getPredictionValue() external returns (uint value) {
        return currentPrediction;
    }
    // Utiltiy
    function swap(uint256[] memory array, uint256 i, uint256 j) internal pure {
        (array[i], array[j]) = (array[j], array[i]);
    }
    function sort(uint256[] memory array, uint256 begin, uint256 end) internal pure {
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
    function median(uint256[] memory array, uint256 length) internal pure returns(uint256) {
        sort(array, 0, length);
        return length % 2 == 0 ? Math.average(array[length/2-1], array[length/2]) : array[length/2];
    }    
}
