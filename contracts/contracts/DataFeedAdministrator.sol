// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

contract DataFeedAdministrator {
    event SubscribeDataFeed(uint256 processor, bytes32 feedId);
    event UnSubscribeDataFeed(uint256 processor, bytes32 feedId);
}