// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

import {DataFeedAdministrator} from './DataFeedAdministrator.sol';

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract EventAdministratorL1 is DataFeedAdministrator, Ownable {

    uint256 public processorId;

    mapping(address => bool) public callbacks;

    constructor()
        Ownable(msg.sender)
    {

    }

    function setReactiveFeedProcessor(
        uint256 id
    ) public {
        processorId = id;
    }

    function registerCallback(
        address callback
    ) public {
        callbacks[callback] = true;
    }

    function newPriceLevelTrigger(
        bytes32 feedId,
        uint256 priceMin,
        uint256 priceMax
    ) public onlyRegisteredCallbacks {

    }

    function newBlockNumberTrigger(
        bytes32 feedId,
        uint256 chainId
    ) public onlyRegisteredCallbacks {

    }

    function newEventTrigger(
        uint256 chainId,
        address emitter,
        bytes32 topic0,
        bytes32 topic1,
        bytes32 topic2,
        bytes32 topic3
    ) public onlyRegisteredCallbacks {

    }
}