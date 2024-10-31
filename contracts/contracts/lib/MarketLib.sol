// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {Market} from '../Types.sol';

/**
 * @notice Manage interactions with markets
 */
library MarketLib {

    /**
    * @notice Update the market lookup with the updated price
    * @dev The update will not occur in the following conditions:
    * 1. Market is not active
    * 2. Timestamp is before the last update timestamp (old price)
    *
    * data layout:
    * publishTime (uint64)
    * price (int24)
    * conf (uint64) -- ignored
    *
    * @param self the lookup to modify
    * @param id the market id the price update refers to
    * @param data the raw event data
    * @return updated whether the price feed was updated
    * @return market the current market state
    */
    function updatePrice(
        mapping(uint256 => Market) storage self,
        uint256 id, 
        bytes calldata data
    ) internal returns (bool updated, Market memory market) {
        market = self[id];
        (uint64 publishTime, int64 price) = abi.decode(data, (uint64, int64));

        // Nothing to update here so just return to save gas.
        // This may occur if we get a price feed push on a faster chain, then another from
        // a slower chain. Or multiple feed updates in the same block
        if(market.timestamp >= publishTime){
            return (false, market);
        }

        // This is a later price for the given market. Update the price and timestamp
        market.timestamp = publishTime;
        market.price = price;

        self[id] = market;

        return (true, market);
    }
}