I have this recurring payment smart contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract RecurringPayments {
    uint public nextPlanId;
    struct Plan {
        address receiver;
        address token;
        uint amount;
        uint period;
    }
    struct Subscription {
        address payer;
        uint start;
        uint period;
    }
    mapping(uint => Plan) public plans;
    mapping(address => mapping(uint => Subscription)) public subscriptions;

    event PlanCreated(address receiver, uint planId, uint date);
    event SubscriptionCreated(address payer, uint planId, uint date);
    event SubscriptionCancelled(address payer, uint planId, uint date);
    event PaymentSent(
        address from,
        address to,
        uint amount,
        uint planId,
        uint date
    );

    function getPlanId() public view returns (uint256) {
        return nextPlanId;
    }

    function isSubscribed(address payer, uint planId) public view returns (bool) {
    Subscription storage subscription = subscriptions[payer][planId];
    return subscription.payer != address(0);
}


    function createPlan(
        address receiver,
        address token,
        uint amount,
        uint period
    ) external returns (uint) {
        require(token != address(0), "address cannot be null address");
        require(amount > 0, "amount needs to be > 0");
        require(period > 0, "period needs to be > 0");
        plans[nextPlanId] = Plan(receiver, token, amount, period);
        nextPlanId++;
        return nextPlanId - 1;
    }


    function subscribe(address payer, uint planId) external {
        Plan storage plan = plans[planId];
        ERC20 token = ERC20(plan.token);
        require(plan.receiver != address(0), "this plan does not exist");
        token.transferFrom(payer, plan.receiver, plan.amount);
        subscriptions[payer][planId] = Subscription(
            payer,
            block.timestamp,
            plan.period
        );
    }

    function cancel(address payer, uint planId) external {
        Subscription storage subscription = subscriptions[msg.sender][planId];
        require(
            subscription.payer != address(0),
            "this subscription does not exist"
        );
        delete subscriptions[payer][planId];
        emit SubscriptionCancelled(payer, planId, block.timestamp);
    }

    function pay(address payer, uint planId) external {
        Subscription storage subscription = subscriptions[payer][planId];
        Plan storage plan = plans[planId];
        ERC20 token = ERC20(plan.token);
        require(
            subscription.payer != address(0),
            "this subscription does not exist"
        );

        token.transferFrom(payer, plan.receiver, plan.amount);
    }
}

```

And I have this test file RecurringPaymentsTest.t.sol

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import {RecurringPayments} from "../src/RecurringPayments.sol";
import {RecurringPaymentsDeploy} from "../script/RecurringPaymentsDeploy.s.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract RecurringPaymentsTest is Test {
    RecurringPayments public recurringPayments;
    RecurringPaymentsDeploy public deployer;
    ERC20Mock public anyToken;

    /** Assinando endereços para simular fluxo */
    address private assinanteUserA;
    address private assinanteUserB;
    address private admin;
    address private corretor;

    uint256 private assinanteUserAPrivateKey;
    uint256 private assinanteUserBPrivateKey;
    uint256 private adminPrivateKey;
    uint256 private corretorPrivateKey;

    function setUp() public {
        /** @dev Cria enderecos na evm local para teste do fluxo */
        (assinanteUserA, assinanteUserAPrivateKey) = makeAddrAndKey("assinanteUserA");
        (assinanteUserB, assinanteUserBPrivateKey) = makeAddrAndKey("assinanteUserB");
        (admin, adminPrivateKey) = makeAddrAndKey("admin");
        (corretor, corretorPrivateKey) = makeAddrAndKey("corretor");

        /** @dev deploya um mock de token */
        anyToken = new ERC20Mock("Mock Token", "MTK");

        deployer = new RecurringPaymentsDeploy();
        deployer.run();

        /**
         * @dev deploya esse contrato em uma evm local
         */
        recurringPayments = RecurringPayments(
            deployer.recurringPaymentsAddress()
        );
        
        /** @dev esse processo minta 1000 tokens para usuarios que irao assinar */
        anyToken.mint(assinanteUserA, 1000 ether);
        anyToken.mint(assinanteUserB, 1000 ether);
    }

    function testSubscribe() public {
        // Create a plan first
        vm.prank(admin);
        uint planId = recurringPayments.createPlan(address(corretor), address(anyToken), 100, 3600);
        vm.stopPrank();

        // Simulate a user subscribing to the plan
        vm.prank(assinanteUserA);
        recurringPayments.subscribe(assinanteUserA, planId);
        vm.stopPrank();

        // Check if the subscription is created correctly
        (address payer,, uint period) = recurringPayments.subscriptions(assinanteUserA, planId);
        assertEq(payer, assinanteUserA, "Incorrect payer");
        assertEq(period, 3600, "Incorrect period");
    }

    function testCancel() public {
        // Create a plan and subscribe a user to it
        vm.prank(admin);
        uint planId = recurringPayments.createPlan(address(corretor), address(anyToken), 100, 3600);
        vm.stopPrank();

        vm.prank(assinanteUserA);
        recurringPayments.subscribe(assinanteUserA, planId);
        vm.stopPrank();

        // Cancel the subscription
        vm.prank(assinanteUserA);
        recurringPayments.cancel(assinanteUserA, planId);
        vm.stopPrank();

        // Check if the subscription is cancelled correctly
        (address payer,,) = recurringPayments.subscriptions(assinanteUserA, planId);
        assertEq(payer, address(0), "Subscription not cancelled");
    }

    function testPay() public {
        uint initialBalance = anyToken.balanceOf(address(corretor));
        console.log("Saldo inicial corretor: ", initialBalance);
        // Create a plan and subscribe a user to it
        vm.prank(admin);
        uint planId = recurringPayments.createPlan(address(corretor), address(anyToken), 100 ether, 3600);
        vm.stopPrank();


        console.log("Saldo antes de subscribe ==> ", anyToken.balanceOf(address(corretor)));
        vm.prank(assinanteUserA);
        recurringPayments.subscribe(assinanteUserA, planId);
        vm.stopPrank();
        console.log("Saldo depois do subscribe ==> ", anyToken.balanceOf(address(corretor)));
        // Pay for the subscription
        vm.prank(assinanteUserA);
        recurringPayments.pay(assinanteUserA, planId);
        vm.stopPrank();

        // Check if the payment is made correctly
        // uint balanceBefore = anyToken.balanceOf(address(corretor));
        // uint expectedPaymentAmount = 100 ether;
        // uint balanceAfter = anyToken.balanceOf(address(corretor));
        // console.log("Balance Before", balanceBefore);
        // console.log("Balance After", balanceAfter);
        // assertEq(balanceBefore + expectedPaymentAmount, balanceAfter, "Payment not made correctly");

        // // Check if the subscriber's balance is updated correctly
        // uint subscriberBalance = anyToken.balanceOf(assinanteUserA);
        // console.log("Subscriber Balance", subscriberBalance);
        // assertEq(subscriberBalance, 0, "Subscriber balance not updated correctly");

        // // Check if the subscription is still active
        // bool isSubscribed = recurringPayments.isSubscribed(assinanteUserA, planId);
        // assertEq(isSubscribed, true, "Subscription not active");
    }

}

```

I need to update the testPay() function, we must separate this test for another new function because
when we run this line:

```solidity
   recurringPayments.subscribe(assinanteUserA, planId);
```

The first initial payment already occurs.

We need to create one more new test for when the balance of address(broker)) has an initial balance
of the first payment, and we must test if the pay function is working.