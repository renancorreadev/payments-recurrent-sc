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
    address private seller;
    address private corretor;

    uint256 private assinanteUserAPrivateKey;
    uint256 private assinanteUserBPrivateKey;
    uint256 private adminPrivateKey;
    uint256 private sellerPrivateKey;
    uint256 private corretorPrivateKey;

    uint planId;
    uint256 valueToPay = 100 ether;

    function setUp() public {
        /** @dev Cria enderecos na evm local para teste do fluxo */
        (assinanteUserA, assinanteUserAPrivateKey) = makeAddrAndKey("assinanteUserA");
        (assinanteUserB, assinanteUserBPrivateKey) = makeAddrAndKey("assinanteUserB");
        (admin, adminPrivateKey) = makeAddrAndKey("admin");
        (corretor, corretorPrivateKey) = makeAddrAndKey("corretor");
        (seller, sellerPrivateKey) = makeAddrAndKey("seller");

        /** @dev deploya um mock de token */
        anyToken = new ERC20Mock("Mock Token", "MTK");


        deployer = new RecurringPaymentsDeploy(admin);
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

        /** @dev Inicializa um plano de pagamento recorrente */
        planId = recurringPayments.createPlan(address(seller), address(corretor), address(anyToken), valueToPay, 3600);


        console.log("--> Criando um plano e inscrevendo um corretor nele com um token ERC20");
        console.log("Plano criado com sucesso");
        console.log("\n");
        console.log("-------------------------------------");
        console.log("detalhes do plano: \n ");
        console.log("id do plano: ", planId);
        console.log("vendedor: ", address(seller));
        console.log("corretor: ", address(corretor));
        console.log("token: ", address(anyToken));
        console.log("valor: ", valueToPay);
        console.log("periodo: ", 3600);
        console.log("-------------------------------------");
        console.log("\n");

    }

    function testSubscribe() external {
        // Simulate a user subscribing to the plan
        vm.prank(assinanteUserA);
        recurringPayments.subscribe(assinanteUserA, planId);
        vm.stopPrank();

        // Check if the subscription is created correctly
        (address payer,, uint period) = recurringPayments.subscriptions(assinanteUserA, planId);
        assertEq(payer, assinanteUserA, "Incorrect payer");
        assertEq(period, 3600, "Incorrect period");
    }

    function testInitialPayment() external {
        console.log("------------------- Testando pagamento inicial do Plano ------------------- \n");
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

        console.log("--> verificando se vendedor recebeu 85% tokens");
        uint256 newSellerBalance = anyToken.balanceOf(address(seller));
        uint256 newBrokerBalance = anyToken.balanceOf(address(corretor));
        uint256 newAdminBalance = anyToken.balanceOf(address(admin));

        assertEq(
            newSellerBalance,
            valueToPay*85/100,
            "Incorrect balance after initial payment"
        );
        console.log("corretor recebeu 85% (85 tokens) -> OK");
        console.log("\n");

        console.log("--> Verificando se corretor recebeu 10% tokens");
        assertEq(
            newBrokerBalance,
            valueToPay*10/100,
            "Incorrect balance after initial payment"
        );
        console.log("corretor recebeu 10% (10 tokens) -> OK");
        console.log("\n");

        console.log("--> Verificando se admin recebeu 5% tokens");
        assertEq(  
            newAdminBalance,
            valueToPay*5/100,
            "Incorrect balance after initial payment"
        );
        console.log("admin recebeu 5% (5 tokens) -> OK");

        console.log("\n");

        console.log("---------------------------------------------------------");
        console.log("------------------- SALDOS APOS PAGAMENTO ------------ \n");
        console.log("newSellerBalance", newSellerBalance / (10**18));
        console.log("newBrokerBalance", newBrokerBalance / (10**18));
        console.log("newAdminBalance", newAdminBalance  / (10**18));
        console.log("---------------------------------------------------------");
    }

    function testDoublePaymentPrevention() external {
        // Criar um plano e inscrever um usuário nele
        console.log("------------------- Testando Prevencao de pagamento duplo ------------------- \n");
        // Subscribe the user to the plan
        recurringPayments.subscribe(assinanteUserA, planId);

        // Attempt to subscribe the user to the same plan again
        bool success = false;
        try recurringPayments.subscribe{gas: 1000000}(assinanteUserA, planId) {
            success = true; // double payment succeeded, which is incorrect
        } catch {}

        // Check if a double payment was prevented
        assertEq(success, false, "Double payment not prevented");

        uint256 newSellerBalance = anyToken.balanceOf(address(seller));
        uint256 newBrokerBalance = anyToken.balanceOf(address(corretor));
        uint256 newAdminBalance = anyToken.balanceOf(address(admin));
        

        console.log("--> verificando se vendedor recebeu 85% tokens");
        assertEq(
            newSellerBalance,
            valueToPay*85/100,
            "Incorrect balance after initial payment"
        );
        console.log("corretor recebeu 85% (85 tokens) -> OK");
        console.log("\n");

        console.log("--> Verificando se corretor recebeu 10% tokens");
        assertEq(
            newBrokerBalance,
            valueToPay*10/100,
            "Incorrect balance after initial payment"
        );
        console.log("corretor recebeu 10% (10 tokens) -> OK");
        console.log("\n");

        console.log("--> Verificando se admin recebeu 5% tokens");
        assertEq(  
            newAdminBalance,
            valueToPay*5/100,
            "Incorrect balance after initial payment"
        );
        console.log("admin recebeu 5% (5 tokens) -> OK");

        console.log("\n");

        console.log("---------------------------------------------------------");
        console.log("------------------- SALDOS APOS PAGAMENTO ------------ \n");
        console.log("newSellerBalance", newSellerBalance / (10**18));
        console.log("newBrokerBalance", newBrokerBalance / (10**18));
        console.log("newAdminBalance", newAdminBalance  / (10**18));
        console.log("---------------------------------------------------------");
    }

    function testIsSubscribed() external {
        bool isSubscribedBefore = recurringPayments.isSubscribed(assinanteUserB, planId);
        assertEq(isSubscribedBefore, false, "Payer should not be subscribed before");

        vm.prank(assinanteUserB);
        recurringPayments.subscribe(assinanteUserB, planId);
        vm.stopPrank();

        bool isSubscribedAfter = recurringPayments.isSubscribed(assinanteUserB, planId);
        assertEq(isSubscribedAfter, true, "Payer should be subscribed after");
    }

    function testGetPlan() external {
        (
            address returnedSeller,
            address returnedBroker,
            address returnedToken,
            uint returnedAmount,
            uint returnedPeriod
        ) = recurringPayments.getPlan(planId);

        assertEq(returnedSeller, seller, "Returned seller should match");
        assertEq(returnedBroker, corretor, "Returned broker should match");
        assertEq(returnedToken, address(anyToken), "Returned token should match");
        assertEq(returnedAmount, valueToPay, "Returned amount should match");
        assertEq(returnedPeriod, 3600, "Returned period should match");
    }

    function testCancel() external {
        vm.prank(assinanteUserB);
        recurringPayments.subscribe(assinanteUserB, planId);
        vm.stopPrank();

        bool isSubscribedBefore = recurringPayments.isSubscribed(assinanteUserB, planId);
        assertEq(isSubscribedBefore, true, "Payer should be subscribed before cancel");

        recurringPayments.cancel(assinanteUserB, planId);

        bool isSubscribedAfter = recurringPayments.isSubscribed(assinanteUserB, planId);
        assertEq(isSubscribedAfter, false, "Payer should not be subscribed after cancel");
    }
}
