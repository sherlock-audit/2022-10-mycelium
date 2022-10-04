pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_setMaxCapacityTest is VaultTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function testNonOwner() public {
        vm.startPrank(alice);
        vm.expectRevert("Only callable by owner");
        vault.setMaxCapacity(1);
    }

    function testSetCapacity(uint256 capacity) public {
        vault.setMaxCapacity(capacity);
        assertEq(vault.MAX_CAPACITY(), capacity);
    }
}
