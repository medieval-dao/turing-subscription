//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./TuringHelper.sol";
import "./BobaTuringCredit.sol";

contract TuringSubscriptionManager is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    BobaTuringCredit immutable public turingCredit;

    uint256 public numSubscriptionCreated;

    mapping(uint256=>TuringHelper) _subscription;

    EnumerableSet.UintSet _activeSubscription;
    mapping(address=>EnumerableSet.UintSet) _ownedSubscription;
    mapping(uint256=>EnumerableSet.AddressSet) _subscriptionOwner;
    mapping(uint256=>EnumerableSet.AddressSet) _subscriptionPermittedCaller;

    uint256 public feeRate;
    uint256 constant BPS_UNIT = 10000;
    uint256 constant MAX_FEE_RATE = BPS_UNIT / 100; // Max 1 %

    event SubscriptionCreated(uint256 subscriptionId, address user);
    event SubscriptionCanceled(uint256 subscriptionId, address user);
    event OwnerAdded(uint256 subscriptionId, address owner);
    event OwnerRemoved(uint256 subscriptionId, address owner);
    event PermitedCallerAdded(uint256 subscriptionId, address callder);
    event PermitedCallerRemoved(uint256 subscriptionId, address callder);
    event CreditAdded(uint256 subscriptionId, uint256 amount, address from);

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
    
    function createSubscription() external returns (uint256 subscriptionId) {
        TuringHelper _helper = new TuringHelper();
        subscriptionId = numSubscriptionCreated;
        _subscription[subscriptionId] = _helper;
        _activeSubscription.add(subscriptionId);

        _addSubscriptionOnwer(subscriptionId, msg.sender);

        numSubscriptionCreated++;

        emit SubscriptionCreated(subscriptionId, msg.sender);
    }

    function cancelSubscriptionId(uint256 subscriptionId) 
        onlySubscriptionOwner(subscriptionId) external {
        
        // Canceling subscription doesn't destruct the turing helper.
        // It transfers its ownership to msg.sender. 
        _subscription[subscriptionId].transferOwnership(msg.sender);

        delete _subscription[subscriptionId];
        _activeSubscription.remove(subscriptionId);

        for(uint256 i=0; i< _subscriptionOwner[subscriptionId].length(); i++) {
            _removeSubscriptionOnwer(subscriptionId, 
                _subscriptionOwner[subscriptionId].at(i));
        }
        
        emit SubscriptionCanceled(subscriptionId, msg.sender);
    }

    function addBalanceToSubscription(uint256 subscriptionId, uint256 _addBalanceAmount) 
        external onlyActiveSubscription(subscriptionId) {

        IERC20 turingToken = IERC20(turingCredit.turingToken());
        turingToken.safeTransferFrom(msg.sender, address(this), _addBalanceAmount);
        
        uint256 _addBalanceAmountActual = 
            _addBalanceAmount - _addBalanceAmount * feeRate / BPS_UNIT;

        turingToken.approve(address(turingCredit), _addBalanceAmountActual);
        turingCredit.addBalanceTo(
            _addBalanceAmountActual, 
            address(_subscription[subscriptionId])
        );

        emit CreditAdded(subscriptionId, _addBalanceAmountActual, msg.sender);
    }

    function addPermittedCaller(uint256 subscriptionId, address _callerAddress)
        onlySubscriptionOwner(subscriptionId) external {

        _subscription[subscriptionId].addPermittedCaller(
            _callerAddress
        );
        _subscriptionPermittedCaller[subscriptionId].add(_callerAddress);
        emit PermitedCallerAdded(subscriptionId, _callerAddress);
    }

    function _addSubscriptionOnwer(uint256 subscriptionId, address _owner)
        internal {

        _ownedSubscription[_owner].add(subscriptionId);
        _subscriptionOwner[subscriptionId].add(_owner);
        emit OwnerAdded(subscriptionId, _owner);
    }

    function _removeSubscriptionOnwer(uint256 subscriptionId, address _owner)
        internal {

        _ownedSubscription[_owner].remove(subscriptionId);
        _subscriptionOwner[subscriptionId].remove(_owner);
        emit OwnerRemoved(subscriptionId, _owner);
    }

    function addSubscriptionOnwer(uint256 subscriptionId, address _owner)
        onlySubscriptionOwner(subscriptionId) external {

        _addSubscriptionOnwer(subscriptionId, _owner);
    }

    function removeSubscriptionOnwer(uint256 subscriptionId, address _owner)
        onlySubscriptionOwner(subscriptionId) external {

        _removeSubscriptionOnwer(subscriptionId, _owner);
    }

    function removePermittedCaller(uint256 subscriptionId, address _callerAddress) 
        onlySubscriptionOwner(subscriptionId) external {

        _subscription[subscriptionId].removePermittedCaller(
            _callerAddress
        );
        _subscriptionPermittedCaller[subscriptionId].remove(_callerAddress);
        emit PermitedCallerRemoved(subscriptionId, _callerAddress);
    }


    /* Only Owner */

    function setFeeRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= MAX_FEE_RATE, "Invalid Rate");
        feeRate = _newRate;
    }

    function claimFee() external onlyOwner {
        IERC20 turingToken = IERC20(turingCredit.turingToken());
        uint256 amount = turingToken.balanceOf(address(this));
        turingToken.transfer(msg.sender, amount);
    }

    function rescueERC20(
        IERC20 tokenContract,
        address to,
        uint256 amount
    ) external onlyOwner {
        tokenContract.safeTransfer(to, amount);
    }

    function rescueETH(address to, uint256 amount) external onlyOwner {
        payable(to).transfer(amount);
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

    function subscriptionOwnerByIndex(uint256 subscriptionId, uint256 index) 
        public view onlyActiveSubscription(subscriptionId) returns (address) {
        
        return _subscriptionOwner[subscriptionId].at(index);
    }

    function subscriptionOwnerCount(uint256 subscriptionId) 
        public view onlyActiveSubscription(subscriptionId) returns (uint256){
        
        return _subscriptionOwner[subscriptionId].length();
    }
}