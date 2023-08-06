// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Script.sol";
import {RecurringPayments} from "../src/RecurringPayments.sol";

contract RecurringPaymentsDeploy is Script {
    address public recurringPaymentsAddress;

    function run() external {
        vm.startBroadcast();
        recurringPaymentsAddress = address(new RecurringPayments());
        vm.stopBroadcast();
    }
}
