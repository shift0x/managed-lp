// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

enum FeedType {
    TokenTransfer,
    PythMarket
}

enum FeedStatus {
    Stopped,
    Active
}

struct Market {
    FeedStatus status;
    uint64 timestamp;
    int64 price;
}

struct ChainInfo {
    uint256 id;
    uint256 blockNumber;
}

struct PriceLevelTrigger {
    uint256 priceLower; 
    uint256 priceUpper; 
    ReactiveSubscription subscription;
}

struct BlockNumberTrigger {
    uint256 chainId;
    uint256 blockNumber;
    ReactiveSubscription subscription;
}

struct ReactiveSubscription {
    uint256 id;
    uint256 gasLimit;
}

struct Subscription {
    uint256 id;
    uint256 feedId;
    bool isPersistent;
    bool active;
    address to;
    bytes args;
    uint256 gasLimit;
    uint256 processor;
}

struct Event {
    Subscription subscription;
    uint256 timestamp;
    bytes data;
    bytes output;
    bool success;
}