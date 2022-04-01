//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./TuringHelper.sol";
import "./BobaTuringCredit.sol";

contract TuringSubscriptionManager {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    BobaTuringCredit immutable public turingCredit;

    uint256 public numSubscriptionCreated;

    mapping(uint256=>TuringHelper) _subscription;

    EnumerableSet.UintSet _activeSubscription;
    mapping(address=>EnumerableSet.UintSet) _ownedSubscription;
    mapping(uint256=>EnumerableSet.AddressSet) _subscriptionPermittedCaller;

    constructor(
        BobaTuringCredit _turingCredit
    ) {
        turingCredit = _turingCredit;
    }

    modifier onlySubscriptionOwner(uint256 subscriptionId) {
        require(_ownedSubscription[msg.sender].contains(subscriptionId), 
            "TuringSubscription: msg.sender is not the owner of the subscription.");
        _;
    }

    modifier onlyActiveSubscription(uint256 subscriptionId) {
        require(_activeSubscription.contains(subscriptionId), 
            "TuringSubscription: inactive subcription");
        _;
    }
    
    function createSubscription() external {
        TuringHelper _helper = new TuringHelper();
        uint256 subscriptionId = numSubscriptionCreated;
        _subscription[subscriptionId] = _helper;
        _activeSubscription.add(subscriptionId);
        _ownedSubscription[msg.sender].add(subscriptionId);
        numSubscriptionCreated++;
    }

    function cancelSubscriptionId(uint256 subscriptionId) 
        onlySubscriptionOwner(subscriptionId) external {
        
        // Canceling subscription doesn't destruct the turing owner.
        // It transfers the ownership to msg.sender. 
        _subscription[subscriptionId].transferOwnership(msg.sender);

        delete _subscription[subscriptionId];
        _activeSubscription.remove(subscriptionId);
        _ownedSubscription[msg.sender].remove(subscriptionId);
    }

    function addBalanceToSubscription(uint256 subscriptionId, uint256 _addBalanceAmount) 
        external onlyActiveSubscription(subscriptionId) {

        IERC20 turingToken = IERC20(turingCredit.turingToken());
        turingToken.safeTransferFrom(msg.sender, address(this), _addBalanceAmount);
        turingToken.approve(address(turingCredit), _addBalanceAmount);

        turingCredit.addBalanceTo(
            _addBalanceAmount, 
            address(_subscription[subscriptionId])
        );
    }

    function addPermittedCaller(uint256 subscriptionId, address _callerAddress)
        onlySubscriptionOwner(subscriptionId) external {

        _subscription[subscriptionId].addPermittedCaller(
            _callerAddress
        );
        _subscriptionPermittedCaller[subscriptionId].add(_callerAddress);
    }

    function removePermittedCaller(uint256 subscriptionId, address _callerAddress) 
        onlySubscriptionOwner(subscriptionId) external {

        _subscription[subscriptionId].removePermittedCaller(
            _callerAddress
        );
        _subscriptionPermittedCaller[subscriptionId].remove(_callerAddress);
    }
    
    /* View Functions */

    function getSubscriptionTuringHelper(uint256 subscriptionId) 
        public view onlyActiveSubscription(subscriptionId) returns (address) {
        
        return address(_subscription[subscriptionId]);
    }


    function getSubscriptionCreditAmount(uint256 subscriptionId) public view onlyActiveSubscription(subscriptionId) returns (uint256) {
        return turingCredit.getCreditAmount(address(_subscription[subscriptionId]));
    }

    function checkPermittedCaller(uint256 subscriptionId, address _callerAddress) 
        public view onlyActiveSubscription(subscriptionId) returns (bool) {

        return _subscriptionPermittedCaller[subscriptionId].contains(_callerAddress);
    }

    function activeSubscriptionCount() public view returns (uint256){
        return _activeSubscription.length();
    }

    function activeSubscriptionByIndex(uint256 index) public view returns (uint256) {
        return _activeSubscription.at(index);
    }

    function ownedSubscriptionCount(address owner) public view returns (uint256){
        return _ownedSubscription[owner].length();
    }

    function ownedSubscriptionByIndex(address owner, uint256 index) public view returns (uint256) {
        return _ownedSubscription[owner].at(index);
    }

    function subscriptionPermittedCallerByIndex(uint256 subscriptionId, uint256 index) 
        public view onlyActiveSubscription(subscriptionId) returns (address) {
        
        return _subscriptionPermittedCaller[subscriptionId].at(index);
    }

    function subscriptionPermittedCallerCount(uint256 subscriptionId) 
        public view onlyActiveSubscription(subscriptionId) returns (uint256){
        
        return _subscriptionPermittedCaller[subscriptionId].length();
    }
}