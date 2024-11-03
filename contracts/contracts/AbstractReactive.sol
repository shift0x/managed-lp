// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import {IReactive} from './interfaces/IReactive.sol';
import {IPayable} from './interfaces/IPayable.sol';
import {ISystemContract} from './interfaces/ISystemContract.sol';
 
import {AbstractPayer} from './AbstractPayer.sol';

abstract contract AbstractReactive is IReactive, AbstractPayer {
    ISystemContract internal constant SERVICE_ADDR = ISystemContract(payable(0x0000000000000000000000000000000000fffFfF));

    /**
     * Indicates whether this is a ReactVM instance of the contract.
     */
    bool internal vm;

    ISystemContract internal service;

    constructor() {
        vendor = service = SERVICE_ADDR;
    }

    modifier rnOnly() {
        // require(!vm, 'Reactive Network only');
        _;
    }

    modifier vmOnly() {
        // require(vm, 'VM only');
        _;
    }

    modifier sysConOnly() {
        require(msg.sender == address(service), 'System contract only');
        _;
    }

    function detectVm() internal {
        bytes memory payload = abi.encodeWithSignature("ping()");
        (bool result,) = address(service).call(payload);
        vm = !result;
    }
}