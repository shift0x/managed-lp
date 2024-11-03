// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {DataFeedAdministrator} from './DataFeedAdministrator.sol';
import {AbstractPayer} from './AbstractPayer.sol';
import {IPayable} from './interfaces/IPayable.sol';
import {SubscriptionsLib} from './lib/SubscriptionsLib.sol';
import {PythFeedLib} from './lib/PythFeedLib.sol';
import {ReactiveTriggers} from './lib/ReactiveTriggers.sol';

import {
    Subscription,
    Event
} from './Types.sol';


/**
 * @notice administrative contract responsible for managing subscriptions for a given system of contracts registered
 * by an administrator. 
 *
 * @dev The goal of this contract is to enable executions of existing contracts in a Reactive fashion without
 * needing to modify the callback contracts
 *
 * To do this, an administrator registeres callbacks specifying the target and calldata passed to the address.call method.
 * This contract handles payment of tx fees by inheriting from AbstractPayer
 *
 * The administrator can be an EOA or a contract, allowing for more dynamic setups.
 
 */
contract EventAdministratorL1 is DataFeedAdministrator, AbstractPayer {
    using SubscriptionsLib for Subscription[];
    using SubscriptionsLib for Subscription;
    using PythFeedLib for mapping(uint256 => mapping(bytes32 => uint256));
    using ReactiveTriggers for Subscription;

    /// @notice the admin of the contract
    address immutable private _admin;

    /// @notice the id of the reactive processor sending events to registered callbacks
    uint256 public processorId;

    /// @notice list of subscriptions managed by this admin
    Subscription[] public subscriptions;

    /// @notice mapping of processors to subscribed pyth datafeeds to subscribers
    mapping(uint256 => mapping(bytes32 => uint256)) _pythFeedSubscriptions;

    /// @notice mapping of subscriptions to processed events
    mapping(uint256 => Event[]) public events;

    /// @notice mapping of registered callbacks
    mapping(address => bool) public callbacks;

    /// @notice event used to test subscriptions
    event Echo(uint256 blockNumber);

    /// @notice unregistered callback
    error UnregisteredCallback();

    /// @notice caller is not an admin
    error Unauthorized();

    /// @notice processor has already been set and cannot be changed
    error ProcessorAlreadySet();


    /// @notice only allow registered callbacks to execute
    /// @dev reverts if the msg.sender is not a registered callback
    modifier onlyRegisteredCallbacks(){
        if(callbacks[msg.sender] == false){
            revert UnregisteredCallback();
        }

        _;
    }

    /// @notice only allow administrators to execute
    /// @dev reverts if the msg.sender is not the admin
    modifier onlyAdmin(){
        if(msg.sender != _admin){
            revert Unauthorized();
        }

        _;
    }

    /**
     * @notice create a new administrator
     * @param admin the administrator for the contract
     * @param _vendor the vendor to pay for contract interactions
     */ 
    constructor(
        address admin, 
        IPayable _vendor
    ) AbstractPayer() {
        vendor = _vendor;
        _admin = admin;
    }

    /**
     * @notice set the id of the reactive contract responsible for processing requests
     * @param id the id of the linked processor
     */ 
    function setReactiveFeedProcessor(
        uint256 id
    ) external onlyAdmin {
        processorId = id;
    }

    // TESTING METHODS
    function echo() public {
        emit Echo(block.number);
    }

    // GETTERS

    /**
     * @notice gets the processed events for a given subscription
     * @dev optionally pass a maximum number of events to return
     * @param subscriptionId if of the subscription
     * @param count maximum number of events to return. If set, the contract will return
     * the latest events.
     * @return output the list of events
     */
    function getEvents(
        uint256 subscriptionId,
        uint256 count
    ) public view returns(Event[] memory output) {
        output = events[subscriptionId];

        // return all events if the count is unspecified of less than the total event count
        if(count == 0 || count >= output.length){
            return output;
        } 

        // return the events in reverse order up to the max count
        Event[] memory filteredOutput = new Event[](count);

        uint256 startIndex = output.length - 1;

        for(uint256 i = 0; i < count; i++){
            uint256 index = startIndex - i;

            filteredOutput[i] = output[index];
        }

        return filteredOutput;
    }


    // Mangement actions

    /**
     * @notice cancel the given subscription
     * @param subscriptionId the subscription to cancel
     */
    function cancel(
        uint256 subscriptionId
    ) external onlyAdmin {
        subscriptions.cancel(subscriptionId, true);
    }

    
    // EVENT PROCESSING METHODS

    /**
     * @notice process incoming reactive events matching subscriptions
     * @param id the id of the matching subscription
     * @param data the event data that triggered the subscription
     */
    function process(
        uint256 id,
        bytes calldata data
    ) external {
        Subscription memory subscription = subscriptions[id];

        // the subscription is inactive, but we are still receiving events.
        // cancel the subscription and return
        if(!subscription.active){
            emit CancelSubscription(subscription.processor, id);

            return;
        } 

        // execute and store the action defined by the subscription
        Event memory action = subscription.execute(data);

        events[id].push(action);

        // cleanup non-peristent subscriptions since we are not expecting anymore events
        // for the subscription. No need to send the cancel to reactive since it will not fire again 
        if(subscription.isPersistent == false){
            subscriptions.cancel(id, false);
        }
    }



    // ACTION TRIGGER METHODS

    /**
     * @notice create a new price level trigger for a given callback
     * @param feedId the pyth feed for the callback
     * @param priceMin trigger callback below the price
     * @param priceMax trigger callback above the price
     * @param to the receiver of the event
     * @param data the calldata for the call to the receiver
     * @param gasLimit the gas limit for the contract call
     */
    function newPriceLevelTrigger(
        bytes32 feedId,
        uint256 priceMin,
        uint256 priceMax,
        address to,
        bytes memory data,
        uint256 gasLimit
    ) external onlyAdmin {
        // ensure we are subscribed to the requested datafeed
        _pythFeedSubscriptions.subscribe(processorId, feedId);

        // create the new local subscription
        Subscription memory newSubscription = subscriptions.create(to, data, gasLimit, uint256(feedId), false, processorId);

        // create the reactive subscription
        newSubscription.newPriceLevelTrigger(feedId, priceMin, priceMax, gasLimit);
    }

    /**
     * @notice create a new block number callback trigger
     * @param chainId the chain to monitor
     * @param blockNumber the block to trigger at
     * @param to the receiver of the event
     * @param data the calldata for the call to the receiver
     * @param gasLimit the gas limit for the contract call
     */
    function newBlockNumberTrigger(
        uint256 chainId,
        uint256 blockNumber,
        address to,
        bytes memory data,
        uint256 gasLimit
    ) external onlyAdmin {
        // create the new local subscription
        Subscription memory newSubscription = subscriptions.create(to, data, gasLimit, 0, false, processorId);

        // create the reactive subscription
        newSubscription.newBlockNumberTrigger(chainId, blockNumber, gasLimit);
    }

    /**
     * @notice create a new trigger to execute an action on a given duration
     * @param interval the execution interval
     * @param to the receiver of the event
     * @param data the calldata for the call to the receiver
     * @param gasLimit the gas limit for the contract call
     */
    function newTimedEventTrigger(
        uint256 interval,
        address to,
        bytes memory data,
        uint256 gasLimit
    ) external onlyAdmin {
        // create the new local subscription
        Subscription memory newSubscription = subscriptions.create(to, data, gasLimit, 0, true, processorId);

        // create the reactive subscription
        newSubscription.newTimedEventTrigger(interval, gasLimit);
    }


    // EVENT SUBSCRIPTIONS

    /**
     * @notice create a persistent event subscription
     * @dev at least 1 topic must be present
     * @param chainId the chain to monitor. 0 for any chain
     * @param emitter the address of the event emitter. 0 for any address
     * @param topic0 the topic0. 0 for any topic
     * @param topic1 the topic1. 0 for any topic
     * @param topic2 the topic2. 0 for any topic
     * @param topic3 the topic3. 0 for any topic
     * @param to the receiver of the event
     * @param data the calldata for the call to the receiver
     * @param gasLimit the gas limit for the contract call
     */
    function newEventSubscription(
        uint256 chainId,
        address emitter,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3,
        address to,
        bytes memory data,
        uint64 gasLimit
    ) external onlyAdmin {
        // create the new local subscription
        Subscription memory newSubscription = subscriptions.create(to, data, gasLimit, 0, true, processorId);

        // create the reactive subscription
        newSubscription.newEventSubscription(chainId, emitter, topic0, topic1, topic2, topic3, gasLimit);
    }


     receive() external payable {}
}