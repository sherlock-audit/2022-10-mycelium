pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_transferFromTest is VaultTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function testTransferOverAllowance(uint256 allowance, uint256 transferAmount) public {
        vm.assume(allowance > 0);
        vm.assume(allowance < vault.MAX_CAPACITY());
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount < vault.MAX_CAPACITY());
        vm.assume(transferAmount > allowance);

        vm.startPrank(alice);
        link.mint(alice, transferAmount);
        link.approve(address(vault), transferAmount);
        vault.deposit(transferAmount);
        vault.approve(bob, allowance);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Amount exceeds allowance");
        vault.transferFrom(alice, carol, transferAmount);
    }

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
        vault.approve(bob, transferAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Amount exceeds balance");
        vault.transferFrom(alice, carol, transferAmount);
    }

    function testTransferToZeroAddress(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);
        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vault.approve(bob, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Cannot transfer to zero address");
        vault.transferFrom(alice, address(0), amount);
    }

    function testFullTransferFrom(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        vm.startPrank(alice);
        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vault.approve(bob, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, carol, amount);
        bool res = vault.transferFrom(alice, carol, amount);
        assertTrue(res);
        vm.stopPrank();

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(carol), amount);
        assertEq(vault.allowance(alice, bob), 0);
    }

    function testPartialTransferFrom(uint256 amount, uint256 subAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());
        vm.assume(subAmount > 0);
        vm.assume(subAmount < amount);

        vm.startPrank(alice);
        link.mint(alice, amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vault.approve(bob, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, carol, subAmount);
        vault.transferFrom(alice, carol, subAmount);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), amount - subAmount);
        assertEq(vault.balanceOf(carol), subAmount);
        assertEq(vault.allowance(alice, bob), amount - subAmount);
    }
}
