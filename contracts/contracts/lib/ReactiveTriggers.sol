// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;


library ReactiveTriggers {

    error UnsuportedEventConfiguration();
    
    event NewPriceLevelTrigger(uint256 indexed processorId, uint256 subscriptionId, bytes32 feedId, uint256 priceMin, uint256 priceMax, uint256 gasLimit);

    event NewBlockNumberTrigger(uint256 indexed processorId, uint256 subscriptionId, uint256 chainId, uint256 blockNumber, uint256 gasLimit);

    event NewTimedTrigger(uint256 indexed processorId, uint256 subscriptionId, uint256 interval, uint256 gasLimit);

    event NewEventSubscription(
        uint256 indexed processorId, 
        uint256 subscriptionId, 
        uint256 chainId,
        address emitter,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3, 
        uint256 gasLimit);

    /**
     * @notice new price level trigger
     * @dev sends a request to trigger the subscription when the price either below the priceMin
     * or above the priceMax
     * @param processorId the id of the reactive processor
     * @param subscriptionId the id of the subscription to trigger
     * @param feedId the if of the dependent price feed
     * @param priceMin the price to trigger below
     * @param priceMax the price to trigger above
     * @param gasLimit the gasLimit of the callback
     */
    function newPriceLevelTrigger(
        uint256 processorId, 
        uint256 subscriptionId, 
        bytes32 feedId, 
        uint256 priceMin, 
        uint256 priceMax,
        uint256 gasLimit
    ) internal {
        emit NewPriceLevelTrigger(processorId, subscriptionId, feedId, priceMin, priceMax, gasLimit);
    }

    /**
     * @notice trigger the subscription at the given block number
     * @param processorId the id of the reactive processor
     * @param subscriptionId the id of the subscription to trigger
     * @param chainId the chain to monitor
     * @param blockNumber the block to trigger at
     * @param gasLimit the gasLimit of the callback
     */
    function newBlockNumberTrigger(
        uint256 processorId, 
        uint256 subscriptionId,
        uint256 chainId, 
        uint256 blockNumber,
        uint256 gasLimit
    ) internal {
        emit NewBlockNumberTrigger(processorId, subscriptionId, chainId, blockNumber, gasLimit);
    }

    /**
     * @notice create a new trigger to execute an action on a given duration
     * @param processorId the id of the event processor execution interval
     * @param subscriptionId the id of the subscription
     * @param interval the execution interval
     * @param gasLimit the gasLimit of the callback
     */
    function newTimedEventTrigger(
        uint256 processorId, 
        uint256 subscriptionId,
        uint256 interval,
        uint256 gasLimit
    ) internal {
        emit NewTimedTrigger(processorId, subscriptionId, interval, gasLimit);
    }

    /**
     * @notice create a persistent event subscription
     * @dev at least 1 topic must be present
     * @param processorId the id of the event processor execution interval
     * @param subscriptionId the id of the subscription
     * @param chainId the chain to monitor. 0 for any chain
     * @param emitter the address of the event emitter. 0 for any address
     * @param topic0 the topic0. 0 for any topic
     * @param topic1 the topic1. 0 for any topic
     * @param topic2 the topic2. 0 for any topic
     * @param topic3 the topic3. 0 for any topic
     * @param gasLimit the gasLimit of the callback
     */
    function newEventSubscription(
        uint256 processorId,
        uint256 subscriptionId,
        uint256 chainId,
        address emitter,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3,
        uint256 gasLimit
    ) internal {
        if(topic0 == 0 && topic1 == 0 && topic2 == 0 && topic3 == 0) {
            revert UnsuportedEventConfiguration();
        }

        emit NewEventSubscription(processorId, subscriptionId, chainId, emitter, topic0, topic1, topic2, topic3, gasLimit);
    }
}