// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {IReactive} from './interfaces/IReactive.sol';
import {AbstractReactive} from './AbstractReactive.sol';
import {IEventAdministrator} from './interfaces/IEventAdministrator.sol';
import {ISubscriptionService} from './interfaces/ISubscriptionService.sol';

import {
    Market,
    ChainInfo,
    PriceLevelTrigger,
    BlockNumberTrigger,
    ReactiveSubscription,
    FeedType,
    FeedStatus
} from './Types.sol';

import {MarketLib} from './lib/MarketLib.sol';
import {PythFeedLib} from './lib/PythFeedLib.sol';
import {ReactiveTriggers} from './lib/ReactiveTriggers.sol';
import {ReactiveFeedLib} from './lib/ReactiveFeedLib.sol';

import {DataFeedAdministrator} from './DataFeedAdministrator.sol';

/**
 * @notice Manage the execution of liquidity provision strategies across multiple chains
 * @dev This contract recieves price feed updates by monitoring the pyth data feed across multiple blockchains. 
 * Pyth is a pull oracle so different chains may have more up to date prices than others.
 *
 * Strategies can be triggered in 3 ways:
 * 1. A strategy published a price level at which it should be triggered
 * 2. A strategy published a target block number at which it should be triggered
 * 3. Strategies can be notified when an arbitrage exists between the pool and the pyth market price
 * 
 * Upon receipt of a price update, the contract will determine which strategies should be executed 
 */
contract EventProcessorReactive is AbstractReactive, DataFeedAdministrator {
    using MarketLib for mapping(uint256 => Market);
    using ReactiveFeedLib for mapping(bytes32 => FeedStatus);

    /// @notice the contract owner
    address public owner;

    /// @notice event topic used to identify requests for this contract
    uint256 public immutable ID; 

    /// @notice mapping of pyth ids to corresponding market
    mapping(uint256 => Market) public markets;

    /// @notice mapping of chainId to chain infos
    mapping(uint256 => ChainInfo) public chains;

    /// @notice mapping of pyth markets to active price level triggers
    mapping(uint256 => PriceLevelTrigger[]) private _priceLevelTriggers;

    /// @notice mapping of chains to block number triggers
    mapping(uint256 => BlockNumberTrigger[]) private _blockNumberTriggers;

    /// @notice mapping of feed ids to a boolean indicating whether they are active
    mapping(bytes32 => FeedStatus) private _feeds;

    /// @notice the chain id of the admin contract
    uint256 public immutable adminChainId;

    /// @notice the address of the admin contract
    address public immutable adminAddress;

    /// @notice received an unexpected event
    error UnknownEvent();

    /// @notice unauthorized operation
    error Unauthorized();

    
    /**
     * @notice The price has changed for a market
     * @param id The market id
     * @param price The new price
     */
    event MarketPriceUpdated(uint256 indexed id, int64 price);

    /**
     * @notice Created new subscription to pyth price feed
     * @param marketId The market pair
     */
    event SubscribePythFeed(uint256 indexed marketId);

    /**
     * @notice Unsubscribe from a pyth price feed
     * @param marketId The market pair
     */
    event UnsubscribePythFeed(uint256 indexed marketId);

    modifier onlyOwner(){
        if(msg.sender != owner){
            revert Unauthorized();
        }

        _;
    }

    /**
     * @notice create a new instance of the contract
     * @dev the configured administrator is responsible for adding new feeds / pools to watch
     * @param _adminChainId the chain where the admin contract is deployed
     * @param _adminAddress the address of the administrator
     */
    constructor(
        uint256 _adminChainId,
        address _adminAddress
    ) 
    AbstractReactive() 
    DataFeedAdministrator() 
    {
        // unique identifier for this instance of the feed coordinator. 
        // admin contracts administer this contract by emitting events when new feeds / pools to monitor are added
        // this identifier is needed to ensure that only the indended instance of this contract processes
        // the event.
        ID = uint256(uint160(address(this)));

        // Store the chain and address of the admin contract. This is later used to authenticate
        // admin calls before they are executed
        adminAddress = _adminAddress;
        adminChainId = _adminChainId;

        owner = msg.sender;
    }

    function subscribeToAdminContractEvents() public onlyOwner {
        // subscribe to admin events
        service.subscribe(
            adminChainId, 
            adminAddress, 
            ReactiveFeedLib.REACTIVE_IGNORE, 
            ID, 
            ReactiveFeedLib.REACTIVE_IGNORE, 
            ReactiveFeedLib.REACTIVE_IGNORE);
    }
    
    // @inheritdoc IReactive
    function react(
        uint256 chainId,
        address emitter,
        uint256 topic0,
        uint256 topic1,
        uint256,
        uint256,
        bytes calldata data,
        uint256 blockNumber,
        uint256
    ) override external vmOnly() {
        // We expect 2 types of events to be received. Price updates and administrative operations
        // If the topic does not correspond to either then revert
        if(topic0 == ReactiveFeedLib.PYTH_PRICE_FEED_UPDATE_TOPIC_0){
            _updatePrice(topic1, data);

            return;
        } else if(topic0 == ReactiveFeedLib.TOKEN_TRANSFER_TOPIC_0) {
            _updateChainActivity(chainId, blockNumber);

            return;
        }
        
        // If the admin operation is not meant for the processor or is not sent by the registered admin then revert
        if(topic1 != ID) {
            revert UnknownEvent();
        } else if(chainId != adminChainId || emitter != adminAddress) {
            revert Unauthorized();
        }

        // Perform the admin function based on the function signature passed
        if(topic0 == uint256(PythFeedLib.SubscribeDataFeed.selector)){
            _subscribeDataFeed(data);
        } else if(topic0 == uint256(PythFeedLib.UnSubscribeDataFeed.selector)){
            _unsubscribeDataFeed(data);
        } else if(topic0 == uint256(ReactiveTriggers.NewBlockNumberTrigger.selector)) {
            _registerNewBlockNumberTrigger(data);
        }
    }

    event test(bytes payload);

    // Subscribe methods
    function subscribe(
        bytes32 feedId,
        uint256 chainId,
        address contractAddress,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external rnOnly {
        bytes memory payload = abi.encodeWithSelector(
            ISubscriptionService.subscribe.selector,
            chainId,
            contractAddress,
            topic0,
            topic1,
            topic2,
            topic3
        );

        emit test(payload);

        //(bool success,) = address(service).call(payload);

        //_feeds[feedId] = success ? FeedStatus.Active : FeedStatus.Stopped;
    }

    function unsubscribe(
        bytes32 feedId,
        uint256 chainId,
        address contractAddress,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external rnOnly {
        bytes memory payload = abi.encodeWithSelector(
            ISubscriptionService.unsubscribe.selector,
            chainId,
            contractAddress,
            topic0,
            topic1,
            topic2,
            topic3
        );

        (bool success,) = address(service).call(payload);

        _feeds[feedId] = success ? FeedStatus.Stopped : FeedStatus.Active;
    }

    // FEED SUBSCRIPTIONS

    /**
     * @notice subscribe to the pyth feed for the given marketId
     * @dev this function will subscribe to feed on all the configured chains
     * @param data raw event data
     */
    function _subscribeDataFeed(bytes memory data) private {
        uint256 marketId = abi.decode(data, (uint256));

        // short circuit if we are already subscribed to the requested feed
        Market memory market = markets[marketId];

        if(market.status == FeedStatus.Active){
            return;
        }

        // since pyth is a pull oracle, we need to subscribe to events on all available
        // chains to make sure we have the updated price as soon as possible
        _feeds.ensureFeedStatus(0, FeedType.PythMarket, marketId, FeedStatus.Active); 

        emit SubscribePythFeed(marketId);

        // Set the market to active and store the newly created market with default values
        // for timestamp and price (will be 0 respectively, allowing the next price update to initalize the market) 
        market.status = FeedStatus.Active;

        markets[marketId] = market;
    }

    /**
     * @notice unsubscribe to the pyth feed for the given marketId
     * @dev this function will unsubscribe to feed on all the configured chains
     * @param data raw event data
     */
    function _unsubscribeDataFeed(bytes memory data) private {
        uint256 marketId = abi.decode(data, (uint256));

        // short circuit if we are already unsubscribed to the requested feed
        Market memory market = markets[marketId];

        if(market.status == FeedStatus.Stopped){
            return;
        }

        _feeds.ensureFeedStatus(0, FeedType.PythMarket, marketId, FeedStatus.Stopped);

        emit UnsubscribePythFeed(marketId);

        // Set the market to inactive
        markets[marketId].status = FeedStatus.Stopped;
    }

    // ACTIONS

    /**
     * @notice update the market price of the given market if there are changes
     * @param id the id of the market to update
     * @param data the raw event data
     */
    function _updatePrice(
        uint256 id,
        bytes calldata data
    ) private {
        (bool marketHasChanges,) = markets.updatePrice(id, data); 

        if(!marketHasChanges){
            return;
        }

        // check for strategies that should be triggerd based on price movements

    }

    /**
     * @notice record activity for the given chain and execute registered subscriptions
     * @param chainId the chain to update
     * @param blockNumber the observed block number
     */
    function _updateChainActivity(
        uint256 chainId,
        uint256 blockNumber
    ) private {
        // short circuit if the last update as of the same or later block number
        if(chains[chainId].blockNumber >= blockNumber) {
            return;
        }

        // find and execute triggered subscriptions
        uint256 currentTriggerCount = _blockNumberTriggers[chainId].length;

        for(uint256 i = 0; i < currentTriggerCount; i++){
            BlockNumberTrigger memory trigger = _blockNumberTriggers[chainId][i];

            // execute the trigger if it is at or past the desire block number
            // otherwise add it to the still pending collection
            if(trigger.blockNumber <= blockNumber){
                _execute(trigger.subscription.id, trigger.subscription.gasLimit, abi.encode(blockNumber));

                // shift the elements in the array to remove the processed item
                _blockNumberTriggers[chainId][i] = _blockNumberTriggers[chainId][currentTriggerCount-1];

                delete _blockNumberTriggers[chainId][currentTriggerCount-1];

                // decrement i and trigger count and reprocess the index to account for the shifted item
                if(i != currentTriggerCount-1){
                    i--;
                    currentTriggerCount--;
                }
            } 
        }

        // update the block and store the updated chain info
        chains[chainId].blockNumber = blockNumber;
    }

    // TRIGGERS

    /**
     * @notice create a new trigger based on block number
     * @dev when the blockNumber on an event from a given chain is higher than the requested blockNumber
     * then trigger the event
     * @param data the requesting event data 
     */
    function _registerNewBlockNumberTrigger(
        bytes calldata data
    ) private {
        // decode the event data
        (
            uint256 subscriptionId, 
            uint256 chainId, 
            uint256 blockNumber, 
            uint256 gasLimit
        ) = abi.decode(data, (uint256, uint256, uint256, uint256));

        // store the new block trigger subscription
        BlockNumberTrigger memory trigger = BlockNumberTrigger({
            chainId: chainId,
            blockNumber: blockNumber,
            subscription: ReactiveSubscription({
                id: subscriptionId,
                gasLimit: gasLimit
            })
        }); 

        _blockNumberTriggers[chainId].push(trigger);

        // ensure the token transfer feed is running for the specified chain
        _feeds.ensureFeedStatus(chainId, FeedType.TokenTransfer, 0, FeedStatus.Active);
    }

    // PRIVATE FUNCTIONS

    function _execute(
        uint256 subscriptionId,
        uint256 gasLimit,
        bytes memory data
    ) private {
        bytes memory payload = abi.encodeWithSelector(IEventAdministrator.process.selector, subscriptionId, abi.encodePacked(data));

        ReactiveFeedLib.callback(adminChainId, adminAddress, payload, uint64(gasLimit));

    }

    receive() override external payable {}
    
}

