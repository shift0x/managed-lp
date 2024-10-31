// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.27;

contract DataFeedAdministrator {

    uint256 internal SUBSCRIBE_DATA_FEED = uint256(keccak256(abi.encodePacked("SUBSCRIBE_DATA_FEED")));

    uint256 internal UNSUBSCRIBE_DATA_FEED = uint256(keccak256(abi.encodePacked("UNSUBSCRIBE_DATA_FEED")));
}