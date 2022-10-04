pragma solidity ^0.8.9;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carol = address(0x3);
    address public dan = address(0x4);
    address public eve = address(0x5);
    address public frank = address(0x6);

    function labelUsers() internal {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(dan, "Dan");
        vm.label(eve, "Eve");
        vm.label(frank, "Frank");
    }

    function assertEqWithError(
        uint256 a,
        uint256 b,
        uint256 acceptableError
    ) internal {
        uint256 err = a > b ? a - b : b - a;
        if (err > acceptableError) {
            emit log("Error: a == b not satisfied within acceptable error");
            emit log_named_uint("Expected", b);
            emit log_named_uint("Actual", a);
            emit log_named_uint("Error", err);
            fail();
        }
    }

    function assertEqWithError(
        uint256 a,
        uint256 b,
        uint256 acceptableError,
        string memory message
    ) internal {
        uint256 err = a > b ? a - b : b - a;
        if (err > acceptableError) {
            emit log(message);
            assertEqWithError(a, b, acceptableError);
        }
    }
}
