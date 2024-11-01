// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {IReactive} from './interfaces/IReactive.sol';
import {AbstractReactive} from './AbstractReactive.sol';

import {
    Market,
    PriceLevelTrigger
} from './Types.sol';

import {MarketLib} from './lib/MarketLib.sol';
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

    /// @notice event topic used to identify requests for this contract
    uint256 public immutable ID; 

    /// @notice topic for pyth price feed updates
    uint256 private constant PYTH_PRICE_FEED_UPDATE_TOPIC_0 = 0xd06a6b7f4918494b3719217d1802786c1f5112a6c1d88fe2cfec00b4584f6aec;

    /// @notice mapping of pyth ids to corresponding market
    mapping(uint256 => Market) public markets;

    /// @notice mapping of pyth markets to active price level triggers
    mapping(uint256 => PriceLevelTrigger[]) private _priceLevelTriggers;

    /// @notice the chain id of the admin contract
    uint256 public immutable adminChainId;

    /// @notice the address of the admin contract
    address public immutable adminAddress;

    /// @notice the chains supported by the pyth oracles and reactive
    uint256[] public chains;

    /// @notice received an unexpected event
    error UnknownEvent();

    /// @notice unauthorized operation
    error Unauthorized();

    /// @notice subscription failed
    error SubscriptionFailed(uint256 chainId, uint256 marketId);

    
    /**
     * @notice The price has changed for a market
     * @param id The market id
     * @param price The new price
     */
    event MarketPriceUpdated(uint256 id, int64 price);

    /**
     * @notice Created new subscription to pyth price feed
     * @param chainId The chain hosting the feed
     * @param marketId The market pair
     */
    event SubscribePythFeed(uint256 chainId, uint256 marketId);


    /**
     * @notice create a new instance of the contract
     * @dev the configured administrator is responsible for adding new feeds / pools to watch
     * @param _adminChainId the chain where the admin contract is deployed
     * @param _adminAddress the address of the administrator
     */
    constructor(
        uint256 _adminChainId,
        address _adminAddress
    ) AbstractReactive() DataFeedAdministrator() {
        // unique identifier for this instance of the feed coordinator. 
        // admin contracts administer this contract by emitting events when new feeds / pools to monitor are added
        // this identifier is needed to ensure that only the indended instance of this contract processes
        // the event.
        ID = uint256(keccak256(abi.encodePacked(address(this), "LPStrategyCoordinatorReactive.id")));

        // Store the chain and address of the admin contract. This is later used to authenticate
        // admin calls before they are executed
        adminAddress = _adminAddress;
        adminChainId = _adminChainId;

        // manually add supported chains to listen for pyth events
        // in the future this can be configurable by the admin address publishing an event. 
        chains = new uint256[](6);
        chains[0] = 11155111;    // ETH
        chains[1] = 43114;       // AVAX
        chains[2] = 42161;       // Arbitrum
        chains[3] = 169;         // Manta Pacific
        chains[4] = 56;          // BSC
        chains[5] = 137;         // Polygon Pos

        // at a minimum subscribe to the ETH / USD feed
        bytes memory ethFeedId = abi.encodePacked(bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace)); // ETH_USD
        
        _subscribeDataFeed(ethFeedId); 
    }

    // @inheritdoc IReactive
    function react(
        uint256 chainId,
        address emitter,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256,
        bytes calldata data,
        uint256 block,
        uint256
    ) override external vmOnly() {
        // We expect 2 types of events to be received. Price updates and administrative operations
        // If the topic does not correspond to either then revert
        if(topic0 == PYTH_PRICE_FEED_UPDATE_TOPIC_0){
            _updatePrice(topic1, data);
            return;
        } else if(topic1 != ID) {
            revert UnknownEvent();
        } 
        
        // If the admin operation is not sent by the registered admin then revert
        if(chainId != adminChainId || emitter != adminAddress) {
            revert Unauthorized();
        }

        // Perform the admin function based on the function signature passed in topic2
        if(topic0 == uint256(SubscribeDataFeed.selector)){
            _subscribeDataFeed(data);
        } else if(topic2 == uint256(UnSubscribeDataFeed.selector)){
            _unsubscribeDataFeed(data);
        }
    }

    /**
     * @notice subscribe to the pyth feed for the given marketId
     * @dev this function will subscribe to feed on all the configured chains
     * @param data raw event data
     */
    function _subscribeDataFeed(bytes memory data) private {
        uint256 marketId = abi.decode(data, (uint256));
        uint256[] memory supportedChains = chains;

        // short circuit if we are already subscribed to the requested feed
        Market memory market = markets[marketId];

        if(market.active){
            return;
        }

        // since pyth is a pull oracle, we need to subscribe to events on all available
        // chains to make sure we have the updated price as soon as possible
        for(uint256 i = 0; i < supportedChains.length; i++){
            bytes memory payload = abi.encodeWithSignature(
                "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
                supportedChains[i],
                0,
                PYTH_PRICE_FEED_UPDATE_TOPIC_0,
                marketId,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            (bool subscription_result,) = address(service).call(payload);

            // revert if we are unable to create the subscription
            if(subscription_result){
                emit SubscribePythFeed(supportedChains[i], marketId);
            } else {
                revert SubscriptionFailed(supportedChains[i], marketId);
            }
        }

        // Set the market to active and store the newly created market with default values
        // for timestamp and price (will be 0 respectively, allowing the next price update to initalize the market) 
        market.active = true;

        markets[marketId] = market;
    }

    /**
     * @notice unsubscribe to the pyth feed for the given marketId
     * @dev this function will unsubscribe to feed on all the configured chains
     * @param data raw event data
     */
    function _unsubscribeDataFeed(bytes memory data) private {
        uint256 marketId = abi.decode(data, (uint256));
    }

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

    receive() override external payable {}
}

