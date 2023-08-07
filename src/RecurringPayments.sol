// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract RecurringPayments {
    uint public nextPlanId;

    /** 
     * @dev Criar um plano de pagamento recorrente 
     * @param seller - Endereço do vendedor do plano
     * @param broker - Endereço do corretor do plano
     * @param token - Endereço do token do plano
     * @param amount - Valor do plano
     * @param period - Periodo do pagamento do plano
     */
    struct Plan {
        address seller;
        address broker;
        address token;
        uint amount;
        uint period;
    }
    struct Subscription {
        address payer;
        uint start;
        uint period;
    }

    address public admin ;
    mapping(uint => Plan) public plans;
    mapping(address => mapping(uint => Subscription)) public subscriptions;

    event PlanCreated(address seller, address broker, uint planId, uint date);
    event SubscriptionCreated(address payer, uint planId, uint date);
    event SubscriptionCancelled(address payer, uint planId, uint date);

    event PaymentSent(
        address payer,
        uint amount,
        uint planId,
        uint date
    );

    constructor(address _admin)  {
        admin = _admin;
    }


    function getPlanId() public view returns (uint256) {
        return nextPlanId;
    }


    function getPlan(uint planId) public view returns (
        address seller,
        address broker,
        address token,
        uint amount,
        uint period
    ) {
        Plan storage plan = plans[planId];

        return (plan.seller, plan.broker, plan.token, plan.amount, plan.period);
    }

    function isSubscribed(address payer, uint planId) public view returns (bool) {
        Subscription storage subscription = subscriptions[payer][planId];
        return subscription.payer != address(0);
    }

    
    function createPlan(
        address seller,
        address broker,
        address token,
        uint amount,
        uint period
    ) external returns (uint) {
        require(token != address(0), "address cannot be null address");
        require(amount > 0, "amount needs to be > 0");
        require(period > 0, "period needs to be > 0");
        plans[nextPlanId] = Plan(seller, broker, token, amount, period);

        // Emit the PlanCreated event
        emit PlanCreated(seller, broker, nextPlanId, block.timestamp);

        nextPlanId++;
        return nextPlanId - 1;
    }

    /** 
     * @dev Subscribe a user to a plan
     * @param payer - Endereço do usuario
     * @param planId - Id do plano mapeado
     */
    function subscribe(address payer, uint planId) external {
        Plan storage plan = plans[planId];
        ERC20 token = ERC20(plan.token);
        require(plan.seller != address(0), "This plan does not exist");

        bool alreadySubscribed = isSubscribed(payer, planId);
        require(!alreadySubscribed, "Already subscribed to the plan");

        // Calculate payment amounts using division
        uint256 sellerAmount = plan.amount * 85 / 100;
        uint256 brokerAmount = plan.amount * 10 / 100;
        uint256 adminAmount = plan.amount * 5 / 100;

        // Transfer the amounts to the respective addresses
        token.transferFrom(payer, plan.seller, sellerAmount);
        token.transferFrom(payer, plan.broker, brokerAmount);
        token.transferFrom(payer, admin, adminAmount);

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
        require(subscription.payer != address(0), "This subscription does not exist");

        // Calculate payment amounts using division
        uint256 sellerAmount = plan.amount * 85 / 100;
        uint256 brokerAmount = plan.amount * 10 / 100;
        uint256 adminAmount = plan.amount * 5 / 100;

        // Transfer the amounts to the respective addresses
        token.transferFrom(payer, plan.seller, sellerAmount);
        token.transferFrom(payer, plan.broker, brokerAmount);
        token.transferFrom(payer, admin, adminAmount);
    }
}