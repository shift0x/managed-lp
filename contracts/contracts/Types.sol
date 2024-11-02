// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

struct Market {
    bool active;
    uint64 timestamp;
    int64 price;
}

struct PriceLevelTrigger {
    uint256 chainId; 
    address receiver; 
    uint256 priceLower; 
    uint256 priceUpper; 
}

struct Subscription {
    uint256 id;
    uint256 feedId;
    bool isPersistent;
    bool active;
    address to;
    bytes args;
    uint256 gasLimit;
}

struct Event {
    Subscription subscription;
    uint256 timestamp;
    bytes data;
    bytes output;
    bool success;
}