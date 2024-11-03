// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

interface IEventAdministrator {
    function process(uint256 id, bytes memory data) external;
}