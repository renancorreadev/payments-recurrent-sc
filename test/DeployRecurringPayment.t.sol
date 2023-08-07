// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import {RecurringPaymentsDeploy} from "../script/RecurringPaymentsDeploy.s.sol";
import {RecurringPayments} from "../src/RecurringPayments.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract DeployRecurringPayments is Test {
    RecurringPaymentsDeploy public recurringPaymentsDeploy;
    ERC20Mock public tokenMock;
    address public adminAddress;

    function setUp() public {
        adminAddress = address(0x123); // Replace with your desired admin address
        tokenMock = new ERC20Mock("Mock Token", "MTK");
        recurringPaymentsDeploy = new RecurringPaymentsDeploy(adminAddress);
    }

    function testDeployContract() public {
        // Deploy the RecurringPayments contract
        recurringPaymentsDeploy.run();

        // Get the deployed RecurringPayments contract address
        address recurringPaymentsAddress = recurringPaymentsDeploy.recurringPaymentsAddress();

        // Assert that the deployed contract address is not zero
        assertFalse(recurringPaymentsAddress == address(0), "RecurringPayments contract should be deployed");

        // Assert that the admin address is set correctly
        RecurringPayments recurringPaymentsContract = RecurringPayments(recurringPaymentsAddress);
        assertEq(address(recurringPaymentsContract.admin()), adminAddress, "Admin address should match");
    }
    
}
