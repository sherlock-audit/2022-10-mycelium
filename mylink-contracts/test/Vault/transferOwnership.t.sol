pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_transferOwnershipTest is VaultTest {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function testTransferOwnership(address newOwner) public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), newOwner);
        vault.transferOwnership(newOwner);
        assertEq(vault.owner(), newOwner);
    }

    function testNonOwner(address newOwner) public {
        vm.startPrank(alice);
        vm.expectRevert("Only callable by owner");
        vault.transferOwnership(newOwner);
    }
}
