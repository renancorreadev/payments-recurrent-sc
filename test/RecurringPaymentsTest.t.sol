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

    function testInitialPayment() public {
        console.log("------------------- Testando pagamento inicial do Plano ------------------- \n");
        // Create a plan first
        vm.prank(admin);
        uint planId = recurringPayments.createPlan(address(corretor), address(anyToken), 100 ether, 3600);
        vm.stopPrank();

        // Simulate a user subscribing and making the initial payment
        vm.prank(assinanteUserA);
        // Subscribe after making the initial payment
        recurringPayments.subscribe(assinanteUserA, planId);
        vm.stopPrank();

        // Check if the subscription and initial payment are processed correctly
        (address payer,, uint period) = recurringPayments.subscriptions(assinanteUserA, planId);

        console.log("payer", payer);
        console.log("assinanteUserA", assinanteUserA);
        console.log("period", period);
        console.log("\n");

        console.log("--> verificando se Payer e assinanteUserA");
        assertEq(payer, assinanteUserA, "Incorrect payer");
        console.log("Payer e assinanteUserA ->  OK");
        console.log("\n");
        
        console.log("--> verificando se period e 3600");
        assertEq(period, 3600, "Incorrect period");
        console.log("period ->  OK");
        console.log("\n");

        // Verify the token balance of the plan receiver after the initial payment

        console.log("--> verificando se corretor recebeu 100 tokens");
        assertEq(
            anyToken.balanceOf(address(corretor)),
            100 ether,
            "Incorrect balance after initial payment"
        );
        console.log("corretor recebeu 100 tokens -> OK");
    }

function testDoublePaymentPrevention() public {
    // Criar um plano e inscrever um usuário nele
    console.log("------------------- Testando Prevencao de pagamento duplo ------------------- \n");

    console.log("--> Criando um plano e inscrevendo um corretor nele com um token ERC20");
    uint planId = recurringPayments.createPlan(address(corretor), address(anyToken), 100 ether, 3600);

    console.log("Plano criado com sucesso");
    console.log("\n");
    console.log("-------------------------------------");
    console.log("detalhes do plano: \n ");
    console.log("id do plano: ", planId);
    console.log("corretor: ", address(corretor));
    console.log("token: ", address(anyToken));
    console.log("valor: ", 100 ether);
    console.log("periodo: ", 3600);
    console.log("-------------------------------------");
    console.log("\n");

    

    // Subscribe the user to the plan
    recurringPayments.subscribe(assinanteUserA, planId);

    // Attempt to subscribe the user to the same plan again
    bool success = false;
    try recurringPayments.subscribe{gas: 1000000}(assinanteUserA, planId) {
        success = true; // double payment succeeded, which is incorrect
    } catch {}

    // Check if a double payment was prevented
    assertEq(success, false, "Double payment not prevented");

    // Check the token balance of the plan receiver after the double payment attempt
    assertEq(
        anyToken.balanceOf(address(corretor)),
        100 ether,
        "Unexpected double payment to plan receiver"
    );
}



}
