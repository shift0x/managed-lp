// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {Market} from '../Types.sol';

library PythFeedLib {
    event SubscribeDataFeed(uint256 indexed processor, bytes32 feedId);

    event UnSubscribeDataFeed(uint256 indexed processor, bytes32 feedId);

    /**
     * @notice initalize a new subscription to a pyth feed
     * @param self the mapping from pyth feedId to number of active subscribers
     * @param processorId the identifier of the attached reactive processor
     * @param feedId the feed to subscribe to
     */
    function subscribe(
        mapping(bytes32 => uint256) storage self,
        uint256 processorId,
        bytes32 feedId
    ) internal {
        // start a new feed subscription we are not currently subscribed
        uint256 feedSubscriberCount = self[feedId];

        if(feedSubscriberCount == 0){
            emit SubscribeDataFeed(processorId, feedId);
        }

        self[feedId]++;
    }

    /**
     * @notice decrement the feed subscriber count and unsubdcribe the feed if there are no listeners
     * @param self the mapping from pyth feedId to number of active subscribers
     * @param processorId the identifier of the attached reactive processor
     * @param feedId the feed to subscribe to
     */
    function unsubscribe(
        mapping(bytes32 => uint256) storage self,
        uint256 processorId,
        bytes32 feedId
    ) internal {
        uint256 feedSubscriberCount = self[feedId];

        // this is the last subscriber, so remove the subscription
        if(feedSubscriberCount == 1){
            emit UnSubscribeDataFeed(processorId, feedId);
        } else if(feedSubscriberCount == 0) {
            // should not enter this case since we should have already unsubscribed
            return;
        }

        self[feedId]--;
    }
}