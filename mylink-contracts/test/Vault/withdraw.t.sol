pragma solidity ^0.8.9;

import "../utils/StubPlugin.sol";
import "../utils/VaultTest.sol";

contract Vault_withdrawTest is VaultTest {
    event Withdraw(address indexed from, uint256 value);

    function testSingleWithdraw(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.MAX_CAPACITY());

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(address(this), amount);
        vault.withdraw(amount);

        assertEq(vault.totalShares(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
    }

    function testWithdrawZero() public {
        vm.expectRevert("Amount must be greater than 0");
        vault.withdraw(0);
    }

    function testWithdrawOverBalance(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.availableForDeposit());

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        vm.expectRevert("Amount exceeds balance");
        vault.withdraw(amount + 1);
    }

    function testThreeWithdrawals(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256,
        uint256 carolAmount
    ) public {
        vm.assume(aliceAmount > 0 && bobAmount > 0 && carolAmount > 0);

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

        // Alice withdraws
        vm.startPrank(alice);
        vault.withdraw(aliceAmount);
        vm.stopPrank();

        assertEq(vault.totalSupply(), bobAmount + carolAmount);
        assertEq(vault.balanceOf(alice), 0);

        // Bob withdraws
        vm.startPrank(bob);
        vault.withdraw(bobAmount);
        vm.stopPrank();

        assertEq(vault.totalSupply(), carolAmount);
        assertEq(vault.balanceOf(bob), 0);

        // Carol withdraws
        vm.startPrank(carol);
        vault.withdraw(carolAmount);
        vm.stopPrank();

        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(carol), 0);
    }

    function testWithdrawalFromOnePlugin(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.availableForDeposit());

        StubPlugin plugin = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin), 0);

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        assertEq(link.balanceOf(address(plugin)), amount);

        vault.withdraw(amount);

        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
    }

    function testWithdrawFromManyPlugins(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < vault.availableForDeposit());

        // Setup plugins
        StubPlugin plugin0 = new StubPlugin(address(vault), address(link));
        plugin0.setCapacity(100);
        vault.addPlugin(address(plugin0), 0);
        StubPlugin plugin1 = new StubPlugin(address(vault), address(link));
        plugin1.setCapacity(100);
        vault.addPlugin(address(plugin1), 1);
        StubPlugin plugin2 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin2), 2);

        link.mint(address(this), amount);
        link.approve(address(vault), amount);
        vault.deposit(amount);

        vault.withdraw(amount);

        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(link.balanceOf(address(plugin0)), 0);
        assertEq(link.balanceOf(address(plugin1)), 0);
        assertEq(link.balanceOf(address(plugin2)), 0);
    }

    function testComplexWithdraw(
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

        // Alice withdraws
        vm.startPrank(alice);
        vault.withdraw(aliceAmount);
        vm.stopPrank();

        assertEq(vault.totalSupply(), bobAmount + carolAmount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(plugin0.balance() + plugin1.balance() + plugin2.balance(), bobAmount + carolAmount);
        if (plugin2.balance() > 0) {
            assertEq(plugin1.balance(), plugin1.capacity());
        }
        if (plugin1.balance() > 0) {
            assertEq(plugin0.balance(), plugin0.capacity());
        }
    }

    function testSingleWithdrawalAfterRebase(uint256 amount) public {
        // Setup plugin
        StubPlugin plugin0 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin0), 0);

        // Alice deposits
        vm.assume(amount > 0);
        vm.assume(amount <= vault.availableForDeposit());
        link.mint(alice, amount);
        vm.startPrank(alice);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        // Plugin yields 10% of the balance
        uint256 pluginBalance = plugin0.balance();
        uint256 yield1 = pluginBalance / 10;
        plugin0.setBalance(pluginBalance + yield1);
        link.mint(address(plugin0), yield1);

        // Alice withdraws
        vm.startPrank(alice);
        vault.withdraw(vault.balanceOf(alice));
        vm.stopPrank();

        assertEq(link.balanceOf(alice), amount + yield1);
    }

    function testTwoWithdrawalsWithRebase(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 yield1,
        uint256 yield2
    ) public {
        uint256 aliceBalance = 0;
        uint256 bobBalance = 0;
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
        vm.assume(yield1 <= vault.totalSupply()); // High yields will increase rounding errors
        link.mint(address(vault), yield1);
        aliceBalance += yield1;
        totalBalance += yield1;

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

        // Vault earns yield
        vm.assume(yield2 <= vault.availableForDeposit());
        vm.assume(yield2 <= vault.totalSupply()); // High yields will increase rounding errors
        link.mint(address(vault), yield2);
        aliceBalance += (yield2 * aliceBalance) / (totalBalance);
        bobBalance += (yield2 * bobBalance) / (totalBalance);
        totalBalance += yield2;

        // Alice withdraws
        vm.startPrank(alice);
        vm.assume(vault.balanceOf(alice) > 0);
        vault.withdraw(vault.balanceOf(alice));
        vm.stopPrank();

        // Bob withdraws
        vm.startPrank(bob);
        vm.assume(vault.balanceOf(bob) > 0);
        vault.withdraw(vault.balanceOf(bob));
        vm.stopPrank();

        assertEqWithError(aliceBalance, link.balanceOf(alice), 100, "Alice balance incorrect");
        assertEqWithError(bobBalance, link.balanceOf(bob), 100, "Bob balance incorrect");
    }
}
