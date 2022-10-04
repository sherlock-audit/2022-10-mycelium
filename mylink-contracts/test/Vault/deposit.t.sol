pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";
import "../utils/StubPlugin.sol";

contract Vault_depositTest is VaultTest {
    event Deposit(address indexed from, uint256 value);

    function testSingleDeposit(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), amount);
        vault.deposit(amount);

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.shares(address(this)), amount * vault.STARTING_SHARES_PER_LINK());
    }

    function testDepositZero() public {
        vm.expectRevert("Amount must be greater than 0");
        vault.deposit(0);
    }

    function testDepositOverCapacity(uint256 amount) public {
        vm.assume(amount > vault.availableForDeposit());
        vm.expectRevert("Amount exceeds available capacity");
        vault.deposit(amount);
    }

    function testThreeDeposits(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 carolAmount
    ) public {
        vm.assume(aliceAmount > 0 && bobAmount > 0 && carolAmount > 0);

        StubPlugin plugin = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin), 0);

        // Alice deposits
        vm.assume(aliceAmount <= vault.availableForDeposit());
        link.mint(alice, aliceAmount);
        vm.startPrank(alice);
        link.approve(address(vault), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();

        // Bob deposits
        vm.assume(bobAmount <= vault.availableForDeposit());
        link.mint(bob, bobAmount);
        vm.startPrank(bob);
        link.approve(address(vault), bobAmount);
        vault.deposit(bobAmount);
        vm.stopPrank();

        // Carol deposits
        vm.assume(carolAmount <= vault.availableForDeposit());
        link.mint(carol, carolAmount);
        vm.startPrank(carol);
        link.approve(address(vault), carolAmount);
        vault.deposit(carolAmount);
        vm.stopPrank();

        // Check balances
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(vault.balanceOf(bob), bobAmount);
        assertEq(vault.balanceOf(carol), carolAmount);

        assertEq(vault.shares(alice), aliceAmount * vault.STARTING_SHARES_PER_LINK());
        assertEq(vault.shares(bob), bobAmount * vault.STARTING_SHARES_PER_LINK());
        assertEq(vault.shares(carol), carolAmount * vault.STARTING_SHARES_PER_LINK());

        assertEq(link.balanceOf(alice), 0);
        assertEq(link.balanceOf(bob), 0);
        assertEq(link.balanceOf(carol), 0);

        assertEq(vault.totalSupply(), aliceAmount + bobAmount + carolAmount);
        assertEq(vault.totalShares(), (aliceAmount + bobAmount + carolAmount) * vault.STARTING_SHARES_PER_LINK());
        assertEq(link.balanceOf(address(plugin)), aliceAmount + bobAmount + carolAmount);
    }

    function testDepositWithTwoPlugins(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.availableForDeposit());

        // Setup plugins, first one has limited capacity
        StubPlugin plugin0 = new StubPlugin(address(vault), address(link));
        plugin0.setCapacity(100);
        vault.addPlugin(address(plugin0), 0);
        StubPlugin plugin1 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin1), 1);

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        assertEq(vault.totalSupply(), amount);
        assertEq(vault.balanceOf(address(this)), amount);

        uint256 newPluginBalance = plugin0.balance();
        if (newPluginBalance < plugin0.capacity()) {
            assertEq(link.balanceOf(address(plugin0)), amount);
            assertEq(link.balanceOf(address(plugin1)), 0);
        } else {
            assertEq(newPluginBalance, plugin0.capacity());
            assertEq(link.balanceOf(address(plugin1)), amount - plugin0.capacity());
        }
    }

    function testMultiUserMultiPluginDeposit(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 carolAmount,
        uint256 plugin0Capacity,
        uint256 plugin1Capacity
    ) public {
        vm.assume(aliceAmount > 0 && bobAmount > 0 && carolAmount > 0);

        // Setup plugins
        StubPlugin plugin0 = new StubPlugin(address(vault), address(link));
        plugin0.setCapacity(plugin0Capacity);
        vault.addPlugin(address(plugin0), 0);
        StubPlugin plugin1 = new StubPlugin(address(vault), address(link));
        plugin1.setCapacity(plugin1Capacity);
        vault.addPlugin(address(plugin1), 1);
        StubPlugin plugin2 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin2), 2);

        // Alice deposits
        vm.assume(aliceAmount <= vault.availableForDeposit());
        link.mint(alice, aliceAmount);
        vm.startPrank(alice);
        link.approve(address(vault), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();

        // Check balances
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(link.balanceOf(alice), 0);
        assertEq(vault.totalSupply(), aliceAmount);
        assertEq(plugin0.balance() + plugin1.balance() + plugin2.balance(), aliceAmount);
        if (plugin2.balance() > 0) {
            assertEq(plugin1.balance(), plugin1.capacity());
        }
        if (plugin1.balance() > 0) {
            assertEq(plugin0.balance(), plugin0.capacity());
        }

        // Bob deposits
        vm.assume(bobAmount <= vault.availableForDeposit());
        link.mint(bob, bobAmount);
        vm.startPrank(bob);
        link.approve(address(vault), bobAmount);
        vault.deposit(bobAmount);
        vm.stopPrank();

        // Check balances
        assertEq(vault.balanceOf(bob), bobAmount);
        assertEq(link.balanceOf(bob), 0);
        assertEq(vault.totalSupply(), aliceAmount + bobAmount);
        assertEq(plugin0.balance() + plugin1.balance() + plugin2.balance(), aliceAmount + bobAmount);
        if (plugin2.balance() > 0) {
            assertEq(plugin1.balance(), plugin1.capacity());
        }
        if (plugin1.balance() > 0) {
            assertEq(plugin0.balance(), plugin0.capacity());
        }

        // Carol deposits
        vm.assume(carolAmount <= vault.availableForDeposit());
        link.mint(carol, carolAmount);
        vm.startPrank(carol);
        link.approve(address(vault), carolAmount);
        vault.deposit(carolAmount);
        vm.stopPrank();

        // Check balances
        assertEq(vault.balanceOf(carol), carolAmount);
        assertEq(link.balanceOf(carol), 0);
        assertEq(vault.totalSupply(), aliceAmount + bobAmount + carolAmount);
        assertEq(plugin0.balance() + plugin1.balance() + plugin2.balance(), aliceAmount + bobAmount + carolAmount);
        if (plugin2.balance() > 0) {
            assertEq(plugin1.balance(), plugin1.capacity());
        }
        if (plugin1.balance() > 0) {
            assertEq(plugin0.balance(), plugin0.capacity());
        }
    }

    function testDepositAfterRebase(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 carolAmount,
        uint256 yield1,
        uint256 yield2,
        uint256 yield3
    ) public {
        uint256 aliceBalance = 0;
        uint256 bobBalance = 0;
        uint256 carolBalance = 0;
        uint256 totalBalance = 0;

        // Alice deposits
        vm.assume(aliceAmount > 0);
        vm.assume(aliceAmount <= vault.availableForDeposit());
        link.mint(alice, aliceAmount);
        vm.startPrank(alice);
        link.approve(address(vault), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();
        aliceBalance += aliceAmount;
        totalBalance += aliceAmount;

        // Vault earns yield
        vm.assume(yield1 <= vault.availableForDeposit());
        vm.assume(yield1 <= vault.totalSupply()); // Absurdly high yields will increase the rounding error
        link.mint(address(vault), yield1);
        aliceBalance += yield1;
        totalBalance += yield1;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(totalBalance, vault.totalSupply(), 100, "Total supply incorrect");

        // Bob deposits
        vm.assume(bobAmount > 0);
        vm.assume(bobAmount <= vault.availableForDeposit());
        link.mint(bob, bobAmount);
        vm.startPrank(bob);
        link.approve(address(vault), bobAmount);
        vault.deposit(bobAmount);
        vm.stopPrank();
        bobBalance += bobAmount;
        totalBalance += bobAmount;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");
        assertEqWithError(totalBalance, vault.totalSupply(), 100, "Total supply incorrect");

        // Vault earns yield
        vm.assume(yield2 <= vault.availableForDeposit());
        vm.assume(yield2 <= vault.totalSupply());
        link.mint(address(vault), yield2);
        aliceBalance += (yield2 * aliceBalance) / totalBalance;
        bobBalance += (yield2 * bobBalance) / totalBalance;
        totalBalance += yield2;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");
        assertEqWithError(totalBalance, vault.totalSupply(), 100, "Total supply incorrect");

        // Carol deposits
        vm.assume(carolAmount > 0);
        vm.assume(carolAmount <= vault.availableForDeposit());
        link.mint(carol, carolAmount);
        vm.startPrank(carol);
        link.approve(address(vault), carolAmount);
        vault.deposit(carolAmount);
        vm.stopPrank();
        carolBalance += carolAmount;
        totalBalance += carolAmount;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");
        assertEqWithError(carolAmount, vault.balanceOf(carol), 100, "Carol balance incorrect");
        assertEqWithError(totalBalance, vault.totalSupply(), 100, "Total supply incorrect");

        // Vault earns yield
        vm.assume(yield3 <= vault.availableForDeposit());
        vm.assume(yield3 <= vault.totalSupply());
        link.mint(address(vault), yield3);
        aliceBalance += (yield3 * aliceBalance) / totalBalance;
        bobBalance += (yield3 * bobBalance) / totalBalance;
        carolBalance += (yield3 * carolBalance) / totalBalance;
        totalBalance += yield3;

        // Check balances
        assertEqWithError(aliceBalance, vault.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, vault.balanceOf(bob), 100, "Bob balance incorrect");
        assertEqWithError(carolBalance, vault.balanceOf(carol), 100, "Carol balance incorrect");
        assertEqWithError(totalBalance, vault.totalSupply(), 100, "Total supply incorrect");
    }
}
