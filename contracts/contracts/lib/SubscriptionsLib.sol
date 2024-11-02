// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {
    Subscription,
    Event
} from '../Types.sol';

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
        uint256 gasLimit,
        uint256 feedId,
        bool isPersistent
    ) internal returns (Subscription memory subscription) {
        subscription = Subscription({
            id: self.length,
            feedId: feedId,
            isPersistent: isPersistent,
            to: to,
            args: data,
            active: true,
            gasLimit: gasLimit
        });

        self.push(subscription);

        return subscription;
    }

    /**
     * @notice execute the action defined by the subscription
     * @param self the triggered subscription
     * @param data the data that triggered the subscription
     */
    function execute(
        Subscription memory self,
        bytes calldata data
    ) internal returns (Event memory action) {
        // call the receiver and store the event in the subscription history
        action = Event({
            subscription: self,
            timestamp: block.timestamp,
            data: data,
            success: false,
            output: new bytes(0)
        });
        
        (action.success, action.output) = self.to.call(self.args);
    }
}