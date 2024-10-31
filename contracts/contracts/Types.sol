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