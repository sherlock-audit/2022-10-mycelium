pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_balanceOfTest is VaultTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function testDeposit(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);
        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), amount);
    }

    function testZeroBalance() public {
        assertEq(vault.balanceOf(alice), 0);
    }

    function testOneAfterRebalance(uint256 amount, uint256 yield) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.availableForDeposit());

        // Alice deposits
        vm.startPrank(alice);
        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        // Vault earns yield
        vm.assume(yield < vault.availableForDeposit());
        link.mint(address(vault), yield);

        assertEq(vault.balanceOf(alice), amount + yield);
    }

    function testManyAfterYield(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 yield1,
        uint256 yield2,
        uint256 yield3
    ) public {
        vm.assume(aliceAmount > 0 && bobAmount > 0);

        uint256 aliceBalance = 0;
        uint256 bobBalance = 0;
        uint256 totalBalance = 0;

        // Alice deposits
        vm.startPrank(alice);
        vm.assume(aliceAmount < vault.availableForDeposit());
        link.mint(alice, aliceAmount);
        link.approve(address(vault), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();
        aliceBalance += aliceAmount;
        totalBalance += aliceAmount;

        // Vault earns yield
        vm.assume(yield1 < vault.availableForDeposit());
        vm.assume(yield1 < vault.totalSupply()); // Absurdly high yield will increase rounding errors
        link.mint(address(vault), yield1);
        aliceBalance += yield1;
        totalBalance += yield1;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");

        // Bob deposits
        vm.startPrank(bob);
        vm.assume(bobAmount < vault.availableForDeposit());
        link.mint(bob, bobAmount);
        link.approve(address(vault), bobAmount);
        vault.deposit(bobAmount);
        vm.stopPrank();
        bobBalance += bobAmount;
        totalBalance += bobAmount;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");

        // Vault earns yield
        vm.assume(yield2 < vault.availableForDeposit());
        vm.assume(yield2 < vault.totalSupply());
        link.mint(address(vault), yield2);
        aliceBalance += (yield2 * aliceBalance) / totalBalance;
        bobBalance += (yield2 * bobBalance) / totalBalance;
        totalBalance += yield2;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");

        // Alice withdraws
        vm.startPrank(alice);
        vault.withdraw(vault.balanceOf(alice));
        vm.stopPrank();
        aliceBalance = 0;

        // Check balances
        assertEqWithError(vault.balanceOf(alice), aliceBalance, 100);
        assertEqWithError(vault.balanceOf(bob), bobBalance, 100);

        // Vault earns yield
        vm.assume(yield3 < vault.availableForDeposit());
        vm.assume(yield3 < vault.totalSupply());
        link.mint(address(vault), yield3);
        bobBalance += yield3;
        totalBalance += yield3;

        // Check balances
        assertEqWithError(vault.balanceOf(alice), aliceBalance, 100);
        assertEqWithError(vault.balanceOf(bob), bobBalance, 100);
    }

    function testYield100Times(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 yieldBps
    ) public {
        return;
        vm.assume(aliceAmount > 0 && bobAmount > 0);
        vm.assume(yieldBps < 1000); // 10%

        // Alice deposits
        vm.startPrank(alice);
        vm.assume(aliceAmount < vault.availableForDeposit());
        link.mint(alice, aliceAmount);
        link.approve(address(vault), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob);
        vm.assume(bobAmount < vault.availableForDeposit());
        link.mint(bob, bobAmount);
        link.approve(address(vault), bobAmount);
        vault.deposit(bobAmount);
        vm.stopPrank();

        uint256 aliceBalance = aliceAmount;
        uint256 bobBalance = bobAmount;
        uint256 totalBalance = aliceAmount + bobAmount;

        for (uint256 i = 0; i < 100; i++) {
            // Vault earns yield
            uint256 yield = (vault.totalSupply() * yieldBps) / 10000;
            link.mint(address(vault), yield);

            // Check balances
            aliceBalance += (yield * aliceBalance) / totalBalance;
            bobBalance += (yield * bobBalance) / totalBalance;
            totalBalance += yield;

            assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
            assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");
        }
    }
}
