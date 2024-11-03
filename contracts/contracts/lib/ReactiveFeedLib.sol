// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {IReactive} from '../interfaces/IReactive.sol';
import {
    FeedType,
    FeedStatus
} from '../Types.sol';


library ReactiveFeedLib {

    /// @notice the subscribe reactive callback signature
    string private constant REACTIVE_SUBSCRIBE_SIGNATURE = "subscribe(bytes32, uint256,address,uint256,uint256,uint256,uint256)";

    /// @notice the unsubscribe reactive callback signature
    string private constant REACTIVE_UNSUBSCRIBE_SIGNATURE = "unsubscribe(bytes32, uint256,address,uint256,uint256,uint256,uint256)";

    /// @notice topic for pyth price feed updates
    uint256 internal constant PYTH_PRICE_FEED_UPDATE_TOPIC_0 = 0xd06a6b7f4918494b3719217d1802786c1f5112a6c1d88fe2cfec00b4584f6aec;

    /// @notice token transfer topic
    uint256 internal constant TOKEN_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @notice ignore topic constant
    uint256 internal constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    /// @notice reactive chain id
    uint256 private constant REACTIVE_CHAIN_ID = 5318008;

    /// @notice the default gas limit
    uint64 private constant GAS_LIMIT = 1000000;

    /// @notice the given feed is unknown and cannot be processed
    error UnknownFeedType();

    /**
     * @notice make a unique identifier for the given feed params
     * @param chainId the chain to subscribe to 
     * @param feedType the type of feed
     * @param identifier the uuid for the feed
     */
    function _makeFeedId(
        uint256 chainId,
        FeedType feedType,
        uint256 identifier
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(chainId, feedType, identifier));
    }

    /**
     * @notice ensure that the given feed is started
     * @param self the mapping of feed status
     * @param chainId the chain to subscribe to 
     * @param feedType the type of feed
     * @param identifier the uuid for the feed
     * @param desiredStatus expected status of the feed
     */
    function ensureFeedStatus(
        mapping(bytes32 => FeedStatus) storage self,
        uint256 chainId,
        FeedType feedType,
        uint256 identifier,
        FeedStatus desiredStatus
    ) internal {
        bytes32 id = _makeFeedId(chainId, feedType, identifier);
        FeedStatus currentStatus = self[id];

        if(currentStatus == desiredStatus){
            return;
        }

        if(feedType == FeedType.TokenTransfer){
            _ensureTokenTransferFeed(id, chainId, desiredStatus);
        } else if(feedType == FeedType.PythMarket){
            _ensurePythFeed(id, chainId, desiredStatus);
        } else {
            revert UnknownFeedType();
        }
    }

    /**
     * @notice listen to token transfers on the given chain
     * @dev used to process block subscription events
     * @param chainId the chain to subscribe to
     * @param status desired status of the feed
     */
    function _ensureTokenTransferFeed(
        bytes32 feedId,
        uint256 chainId,
        FeedStatus status
    ) private {
        if(status == FeedStatus.Active){
             subscribe(
                feedId,
                chainId, 
                address(0), 
                TOKEN_TRANSFER_TOPIC_0, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE);
        } else {
            unsubscribe(
                feedId,
                chainId, 
                address(0), 
                TOKEN_TRANSFER_TOPIC_0, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE
            );
        }
    }

    /**
     * @notice start the pyth data feed
     * @param marketId the market to subscribe to
     * @param status desired status of the feed
     */
    function _ensurePythFeed(
        bytes32 feedId,
        uint256 marketId,
        FeedStatus status
    ) private {
        if(status == FeedStatus.Active){
             subscribe(
                feedId,
                0, 
                address(0), 
                PYTH_PRICE_FEED_UPDATE_TOPIC_0, 
                marketId, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE
            );
        } else {
            unsubscribe(
                feedId,
                0, 
                address(0), 
                PYTH_PRICE_FEED_UPDATE_TOPIC_0, 
                marketId, 
                REACTIVE_IGNORE, 
                REACTIVE_IGNORE
            );
        }
    }

    function _makeCallbackPayload(
        string memory signature,
        bytes32 feedId,
        uint256 chainId,
        address emitter,
        uint256 topic0, 
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) private pure returns (bytes memory) {
        return abi.encodePacked(abi.encodeWithSignature(
            signature,
            feedId,
            chainId,
            emitter,
            topic0,
            topic1,
            topic2,
            topic3
        ));
    }

    function subscribe(
        bytes32 feedId,
        uint256 chainId,
        address emitter,
        uint256 topic0, 
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) internal {
        bytes memory payload = _makeCallbackPayload(
            REACTIVE_SUBSCRIBE_SIGNATURE, 
            feedId,
            chainId, 
            emitter, 
            topic0, 
            topic1, 
            topic2, 
            topic3);

        callback(REACTIVE_CHAIN_ID, address(this), payload, GAS_LIMIT);
    }

    function unsubscribe(
        bytes32 feedId,
        uint256 chainId,
        address emitter,
        uint256 topic0, 
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) internal {
        bytes memory payload = _makeCallbackPayload(
            REACTIVE_UNSUBSCRIBE_SIGNATURE, 
            feedId,
            chainId, 
            emitter, 
            topic0, 
            topic1, 
            topic2, 
            topic3);

        callback(REACTIVE_CHAIN_ID, address(this), payload, GAS_LIMIT);
    }

    function callback(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint64 gasLimit
    ) internal {
        emit IReactive.Callback(chainId, to, gasLimit, payload);
    }


}