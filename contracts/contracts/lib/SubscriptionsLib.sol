// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {Subscription} from '../Types.sol';

library SubscriptionsLib {

    /**
     * @notice create a new subscription
     * @param self the list of existing subscriptions
     * @param to the subscriber
     * @param data the calldata for calls to the subscriber
     * @param gasLimit the gasLimit of the callback
     * @return subscription the subscription result
     */
    function create(
        Subscription[] storage self,
        address to,
        bytes memory data,
        uint256 gasLimit
    ) internal returns (Subscription memory subscription) {
        subscription = Subscription({
            id: self.length,
            to: to,
            args: data,
            active: true,
            gasLimit: gasLimit
        });

        self.push(subscription);

        return subscription;
    }
}