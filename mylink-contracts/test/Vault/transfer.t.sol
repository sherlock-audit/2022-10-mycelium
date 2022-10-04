pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_transferTest is VaultTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function testTransferOverBalance(uint256 balance, uint256 transferAmount) public {
        vm.assume(balance > 0);
        vm.assume(balance < vault.MAX_CAPACITY());
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount < vault.MAX_CAPACITY());
        vm.assume(transferAmount > balance);

        vm.startPrank(alice);
        link.mint(alice, balance);
        link.approve(address(vault), balance);
        vault.deposit(balance);

        vm.expectRevert("Amount exceeds balance");
        vault.transfer(bob, transferAmount);
    }

    function testFullTransfer(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);

        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, amount);
        bool res = vault.transfer(bob, amount);
        assertTrue(res);

        vm.stopPrank();

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), amount);
    }

    function testPartialTransfer(uint256 amount, uint256 subAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());
        vm.assume(subAmount > 0);
        vm.assume(subAmount < amount);

        vm.startPrank(alice);

        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, subAmount);
        vault.transfer(bob, subAmount);

        vm.stopPrank();

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(alice), amount - subAmount);
        assertEq(vault.balanceOf(bob), subAmount);
    }

    function testTransferZeroAddress(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);

        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectRevert("Cannot transfer to zero address");
        vault.transfer(address(0), amount);

        vm.stopPrank();
    }

    function testTransferZeroAmount(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);

        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 0);
        vault.transfer(bob, 0);

        vm.stopPrank();

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(alice), amount);
        assertEq(vault.balanceOf(bob), 0);
    }

    function testManyTransfers(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 carolAmount
    ) public {
        vm.assume(aliceAmount > 0 && bobAmount > 0 && carolAmount > 0);
        vm.assume(aliceAmount < vault.availableForDeposit());
        vm.assume(bobAmount < vault.availableForDeposit());
        vm.assume(carolAmount < vault.availableForDeposit());

        uint256 totalAmount = aliceAmount + bobAmount + carolAmount;

        link.mint(address(this), totalAmount);
        link.approve(address(vault), totalAmount);
        vault.deposit(totalAmount);

        assertEq(vault.balanceOf(address(this)), totalAmount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.balanceOf(carol), 0);

        vault.transfer(alice, aliceAmount);

        assertEq(vault.balanceOf(address(this)), totalAmount - aliceAmount);
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.balanceOf(carol), 0);

        vault.transfer(bob, bobAmount);

        assertEq(vault.balanceOf(address(this)), totalAmount - aliceAmount - bobAmount);
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(vault.balanceOf(bob), bobAmount);
        assertEq(vault.balanceOf(carol), 0);

        vault.transfer(carol, carolAmount);

        assertEq(vault.balanceOf(address(this)), totalAmount - aliceAmount - bobAmount - carolAmount);
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(vault.balanceOf(bob), bobAmount);
        assertEq(vault.balanceOf(carol), carolAmount);
    }

    function testFullTransferAfterRebase(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        // Increase LINK in the vault by 10%
        uint256 yield = amount / 10;
        link.mint(address(vault), yield);

        vault.transfer(alice, vault.balanceOf(address(this)));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(alice), amount + yield);
    }

    function testPartialTransferAfterRebase(uint256 amount, uint256 subAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());
        vm.assume(subAmount > 0);
        vm.assume(subAmount < amount);

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        // Increase LINK in the vault by 10%
        uint256 yield = amount / 10;
        link.mint(address(vault), yield);

        vault.transfer(alice, subAmount);

        assertEqWithError(vault.balanceOf(address(this)), amount + yield - subAmount, 100);
        assertEqWithError(vault.balanceOf(alice), subAmount, 100);
    }
}
