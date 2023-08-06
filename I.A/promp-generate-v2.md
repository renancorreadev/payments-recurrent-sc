Ola eu tenho esse contrato inteligente abaixo de pagamento recorrente: 

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

    function getPlan(uint planId) public view returns (
        address receiver,
        address token,
        uint amount,
        uint period
    ) {
        Plan storage plan = plans[planId];
        return (plan.receiver, plan.token, plan.amount, plan.period);
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

        // Emit the PlanCreated event
        emit PlanCreated(receiver, nextPlanId, block.timestamp);

        nextPlanId++;
        return nextPlanId - 1;
    }

    function subscribe(address payer, uint planId) external {
        Plan storage plan = plans[planId];
        ERC20 token = ERC20(plan.token);
        require(plan.receiver != address(0), "This plan does not exist");

        bool alreadySubscribed = isSubscribed(payer, planId);
        require(!alreadySubscribed, "Already subscribed to the plan");

        token.transferFrom(payer, plan.receiver, plan.amount);
        subscriptions[payer][planId] = Subscription(
            payer,
            block.timestamp,
            plan.period
        );

        emit SubscriptionCreated(payer, planId, block.timestamp);
    }

    function cancel(address payer, uint planId) external {
        Subscription storage subscription = subscriptions[payer][planId];
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

Eu preciso alterar a lógica do contrato inteligente RecurringPayments.sol para assim que um usuario (assinanteUserA) 
realizar um pagamento (transferFrom) createPlan() e pay(), seja dividido o pagamento dessa forma: 

- vendedor que criou o plano recebe 85% 
- corretor ganha 10% 
- admin do contrato ganha 5%
  
